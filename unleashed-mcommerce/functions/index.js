const functions = require('firebase-functions');
const admin = require('firebase-admin');

admin.initializeApp();

const db = admin.firestore();
const auth = admin.auth();

const REGION = 'us-central1';
const regionalFunctions = functions.region(REGION);

const MAX_CART_QUANTITY = 20;
const MAX_ORDER_LINES = 50;
const PAYMENT_METHODS = ['COD', 'GCash', 'Card'];
const ORDER_STATUSES = [
  'placed',
  'confirmed',
  'processing',
  'ready_for_shipment',
  'shipped',
  'out_for_delivery',
  'delivered',
  'cancelled',
  'refunded'
];

// ---------------------------------------------------------------------------
// Shared helpers
// ---------------------------------------------------------------------------

function requireSignedIn(context) {
  if (!context.auth) {
    throw new functions.https.HttpsError(
      'unauthenticated',
      'Please sign in first.'
    );
  }
  return context.auth;
}

function requireAdmin(context) {
  const authContext = requireSignedIn(context);
  if (authContext.token.admin !== true) {
    throw new functions.https.HttpsError(
      'permission-denied',
      'Only authorized administrators can perform this action.'
    );
  }
  return authContext;
}

function validateEmail(email) {
  if (
    typeof email !== 'string' ||
    email.length > 254 ||
    !/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email)
  ) {
    throw new functions.https.HttpsError(
      'invalid-argument',
      'A valid email address is required.'
    );
  }
  return email.trim().toLowerCase();
}

function money(centavos) {
  return `\u20B1${((Number(centavos) || 0) / 100).toFixed(2)}`;
}

function cartItemIdFor(productId, size) {
  return `${productId}_${String(size).replace(/[^A-Za-z0-9]/g, '')}`;
}

async function writeAdminLog(action, targetType, targetId, actorUid, details = {}) {
  await db.collection('admin_activity_logs').add({
    action,
    targetType,
    targetId,
    details: { ...details, performedBy: actorUid },
    adminUid: actorUid,
    createdAt: admin.firestore.FieldValue.serverTimestamp()
  });
}

// ---------------------------------------------------------------------------
// Administrator claim management (existing behaviour preserved)
// ---------------------------------------------------------------------------

exports.setAdminClaim = regionalFunctions.https.onCall(async (data, context) => {
  const actor = requireAdmin(context);
  const email = validateEmail(data && data.email);

  let targetUser;
  try {
    targetUser = await auth.getUserByEmail(email);
  } catch (error) {
    if (error.code === 'auth/user-not-found') {
      throw new functions.https.HttpsError(
        'not-found',
        'No user was found with that email address.'
      );
    }
    console.error('Failed to find target user:', error.code || 'unknown');
    throw new functions.https.HttpsError(
      'internal',
      'Unable to retrieve the target user.'
    );
  }

  try {
    await auth.setCustomUserClaims(targetUser.uid, {
      ...(targetUser.customClaims || {}),
      admin: true
    });
    await writeAdminLog('admin_claim_set', 'user', targetUser.uid, actor.uid, {
      email: targetUser.email || null
    });
    return { success: true, uid: targetUser.uid };
  } catch (error) {
    console.error('Failed to grant admin claim:', error.code || 'unknown');
    throw new functions.https.HttpsError(
      'internal',
      'Unable to grant administrator access.'
    );
  }
});

exports.removeAdminClaim = regionalFunctions.https.onCall(
  async (data, context) => {
    const actor = requireAdmin(context);
    const email = validateEmail(data && data.email);

    let targetUser;
    try {
      targetUser = await auth.getUserByEmail(email);
    } catch (error) {
      if (error.code === 'auth/user-not-found') {
        throw new functions.https.HttpsError(
          'not-found',
          'No user was found with that email address.'
        );
      }
      console.error('Failed to find target user:', error.code || 'unknown');
      throw new functions.https.HttpsError(
        'internal',
        'Unable to retrieve the target user.'
      );
    }

    if (targetUser.uid === actor.uid) {
      throw new functions.https.HttpsError(
        'failed-precondition',
        'You cannot remove your own administrator access.'
      );
    }

    try {
      const existingClaims = { ...(targetUser.customClaims || {}) };
      delete existingClaims.admin;
      await auth.setCustomUserClaims(targetUser.uid, existingClaims);
      await writeAdminLog(
        'admin_claim_removed',
        'user',
        targetUser.uid,
        actor.uid,
        { email: targetUser.email || null }
      );
      return { success: true, uid: targetUser.uid };
    } catch (error) {
      console.error('Failed to remove admin claim:', error.code || 'unknown');
      throw new functions.https.HttpsError(
        'internal',
        'Unable to remove administrator access.'
      );
    }
  }
);

// ---------------------------------------------------------------------------
// Order placement (trusted pricing and stock)
// ---------------------------------------------------------------------------

function normaliseOrderItems(rawItems) {
  if (!Array.isArray(rawItems) || rawItems.length === 0) {
    throw new functions.https.HttpsError(
      'invalid-argument',
      'Your cart is empty.'
    );
  }
  if (rawItems.length > MAX_ORDER_LINES) {
    throw new functions.https.HttpsError(
      'invalid-argument',
      'This order has too many lines.'
    );
  }

  const merged = new Map();
  for (const raw of rawItems) {
    if (!raw || typeof raw !== 'object') {
      throw new functions.https.HttpsError('invalid-argument', 'Invalid cart item.');
    }
    const productId = String(raw.productId || '').trim();
    const size = String(raw.size || '').trim();
    const quantity = Number(raw.quantity);
    if (!productId || productId.length > 200 || !size || size.length > 40) {
      throw new functions.https.HttpsError('invalid-argument', 'Invalid cart item.');
    }
    if (!Number.isInteger(quantity) || quantity < 1 || quantity > MAX_CART_QUANTITY) {
      throw new functions.https.HttpsError(
        'invalid-argument',
        'Choose a valid quantity for every item.'
      );
    }
    const key = `${productId}\u0000${size}`;
    const previous = merged.get(key);
    merged.set(key, {
      productId,
      size,
      quantity: (previous ? previous.quantity : 0) + quantity
    });
  }

  const items = Array.from(merged.values());
  for (const item of items) {
    if (item.quantity > MAX_CART_QUANTITY) {
      throw new functions.https.HttpsError(
        'invalid-argument',
        'You have reached the maximum quantity for an item.'
      );
    }
  }
  return items;
}

exports.placeOrder = regionalFunctions.https.onCall(async (data, context) => {
  const authContext = requireSignedIn(context);
  const uid = authContext.uid;

  const payload = data || {};
  const clientOrderId = String(payload.clientOrderId || '').trim();
  if (
    !/^[A-Za-z0-9_-]{8,160}$/.test(clientOrderId)
  ) {
    throw new functions.https.HttpsError(
      'invalid-argument',
      'A valid client order id is required.'
    );
  }

  const paymentMethod = String(payload.paymentMethod || '');
  if (!PAYMENT_METHODS.includes(paymentMethod)) {
    throw new functions.https.HttpsError(
      'invalid-argument',
      'Choose a valid payment method.'
    );
  }

  const customerNote = String(payload.customerNote || '').trim().slice(0, 300);
  const requestedItems = normaliseOrderItems(payload.items);

  const orderRef = db.collection('orders').doc(clientOrderId);
  const transactionRef = db.collection('transactions').doc(clientOrderId);
  const counterRef = db.collection('counters').doc('orders');
  const storeSettingsRef = db.collection('settings').doc('store');
  const userRef = db.collection('users').doc(uid);

  const result = await db.runTransaction(async (transaction) => {
    // ---- Reads first (Firestore transactions require reads before writes).
    const existingOrder = await transaction.get(orderRef);
    if (existingOrder.exists) {
      throw new functions.https.HttpsError(
        'already-exists',
        'This order has already been submitted. Open your orders to view it.'
      );
    }

    const userSnapshot = await transaction.get(userRef);
    if (!userSnapshot.exists) {
      throw new functions.https.HttpsError(
        'failed-precondition',
        'Your customer profile is missing. Please contact the store.'
      );
    }
    const user = userSnapshot.data() || {};
    if (user.isActive === false) {
      throw new functions.https.HttpsError(
        'failed-precondition',
        'This account cannot place orders. Please contact the store.'
      );
    }
    const contactNumber = String(
      user.contactNumber || user.phone || ''
    ).trim();
    if (!contactNumber) {
      throw new functions.https.HttpsError(
        'failed-precondition',
        'Add a contact number before placing an order.'
      );
    }
    const address = user.address || {};
    const addressComplete =
      address &&
      ['street', 'barangay', 'city', 'province', 'postalCode'].every(
        (key) => String(address[key] || '').trim().length > 0
      );
    if (!addressComplete) {
      throw new functions.https.HttpsError(
        'failed-precondition',
        'Complete your delivery address before placing an order.'
      );
    }

    const settingsSnapshot = await transaction.get(storeSettingsRef);
    const storeSettings = settingsSnapshot.data() || {};

    const counterSnapshot = await transaction.get(counterRef);
    const lastNumber = Number(counterSnapshot.data()
      ? counterSnapshot.data().lastNumber
      : 0) || 0;
    const nextNumber = lastNumber + 1;
    const orderNumber = `UND-${String(nextNumber).padStart(6, '0')}`;

    const productIds = Array.from(
      new Set(requestedItems.map((item) => item.productId))
    );

    const productSnapshots = new Map();
    for (const productId of productIds) {
      const snapshot = await transaction.get(
        db.collection('products').doc(productId)
      );
      productSnapshots.set(productId, snapshot);
    }

    const cartSnapshots = new Map();
    for (const item of requestedItems) {
      const ref = db
        .collection('carts')
        .doc(uid)
        .collection('items')
        .doc(cartItemIdFor(item.productId, item.size));
      const snapshot = await transaction.get(ref);
      cartSnapshots.set(ref.path, { ref, snapshot });
    }

    // ---- Validation and totals.
    const nextStockByProduct = new Map();
    const orderItems = [];
    let subtotal = 0;
    let totalQuantity = 0;

    for (const item of requestedItems) {
      const snapshot = productSnapshots.get(item.productId);
      if (!snapshot || !snapshot.exists) {
        throw new functions.https.HttpsError(
          'failed-precondition',
          'An item in your cart is no longer available.'
        );
      }
      const product = snapshot.data() || {};
      if (product.status !== 'active') {
        throw new functions.https.HttpsError(
          'failed-precondition',
          `${product.name || 'An item'} is not available right now.`
        );
      }

      const price = Number(product.price);
      if (!Number.isInteger(price) || price < 0) {
        throw new functions.https.HttpsError(
          'failed-precondition',
          'A product price is invalid. Please contact the store.'
        );
      }

      const stock = { ...(product.stock || {}) };
      const available = Number(stock[item.size]) || 0;
      if (available < item.quantity) {
        throw new functions.https.HttpsError(
          'failed-precondition',
          available <= 0
            ? `${product.name || 'An item'} (${item.size}) is out of stock.`
            : `Only ${available} of ${product.name || 'an item'} (${item.size}) remain.`
        );
      }

      const nextStock = Number(nextStockByProduct.get(item.productId) !== undefined
        ? nextStockByProduct.get(item.productId).stock[item.size]
        : available) - item.quantity;
      if (!nextStockByProduct.has(item.productId)) {
        nextStockByProduct.set(item.productId, {
          stock: { ...stock },
          totalStock: Number(product.totalStock) || 0
        });
      }
      const productUpdate = nextStockByProduct.get(item.productId);
      productUpdate.stock[item.size] = nextStock;
      productUpdate.totalStock = Math.max(0, productUpdate.totalStock - item.quantity);

      const lineTotal = price * item.quantity;
      subtotal += lineTotal;
      totalQuantity += item.quantity;

      orderItems.push({
        productId: item.productId,
        name: String(product.name || 'Product'),
        size: item.size,
        price,
        quantity: item.quantity,
        subtotal: lineTotal,
        imageId: product.imageId || null,
        category: product.category || null
      });
    }

    let shippingFee = Number(storeSettings.shippingFee || storeSettings.deliveryFee) || 0;
    const rawThreshold =
      storeSettings.freeShippingThreshold ?? storeSettings.freeShippingMinimum;
    const threshold = Number.isFinite(Number(rawThreshold))
      ? Number(rawThreshold)
      : null;
    if (threshold !== null && subtotal >= threshold) shippingFee = 0;

    const total = subtotal + shippingFee;
    const simulated = paymentMethod === 'GCash' || paymentMethod === 'Card';
    const reference = simulated
      ? `SIM-${Date.now().toString(36).toUpperCase()}`
      : `COD-${String(nextNumber).padStart(6, '0')}`;

    // ---- Writes.
    for (const [productId, update] of nextStockByProduct.entries()) {
      transaction.update(db.collection('products').doc(productId), {
        stock: update.stock,
        totalStock: update.totalStock,
        updatedAt: admin.firestore.FieldValue.serverTimestamp()
      });
    }

    transaction.set(orderRef, {
      orderNumber,
      customerId: uid,
      customerName: String(user.displayName || user.fullName || tokenName(authContext) || 'Customer'),
      customerEmail: String(user.email || authContext.token.email || ''),
      items: orderItems,
      itemCount: totalQuantity,
      subtotal,
      shippingFee,
      total,
      paymentMethod,
      paymentStatus: 'unpaid',
      paymentSimulated: simulated,
      simulatedPaymentStatus: simulated ? 'successful' : 'not_applicable',
      transactionReference: reference,
      status: 'placed',
      fulfillmentStatus: 'unfulfilled',
      customerTotalsApplied: true,
      shippingAddress: [
        address.street,
        address.barangay,
        address.city,
        address.province,
        address.postalCode
      ]
        .map((part) => String(part || '').trim())
        .filter(Boolean)
        .join(', '),
      shippingAddressMap: address,
      customerNote: customerNote || null,
      clientOrderId,
      source: 'mobile',
      timeline: [
        {
          status: 'placed',
          title: 'Order placed',
          note: simulated
            ? `Order received with a simulated ${paymentMethod} payment.`
            : 'Order received. Payment is due on delivery.',
          at: admin.firestore.Timestamp.now()
        }
      ],
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      updatedAt: admin.firestore.FieldValue.serverTimestamp()
    });

    transaction.set(transactionRef, {
      orderId: orderRef.id,
      orderNumber,
      customerId: uid,
      customerName: String(user.displayName || user.fullName || 'Customer'),
      amount: total,
      currency: 'PHP',
      paymentMethod,
      paymentStatus: 'unpaid',
      status: simulated ? 'simulated_success' : 'cod_pending',
      simulated,
      isSimulated: simulated,
      reference,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      updatedAt: admin.firestore.FieldValue.serverTimestamp()
    });

    transaction.set(db.collection('notifications').doc(`customer_order_${orderRef.id}_placed`), {
      recipientId: uid,
      type: 'order_placed',
      title: `Order ${orderNumber} placed`,
      body: simulated
        ? `Your order is in. The ${paymentMethod} payment was simulated and no money was charged.`
        : `Your order is in. Please prepare ${money(total)} for cash on delivery.`,
      orderId: orderRef.id,
      isRead: false,
      createdAt: admin.firestore.FieldValue.serverTimestamp()
    });

    // A deterministic id makes the administrator alert idempotent if the
    // callable is retried after a lost response.
    transaction.set(
      db.collection('notifications').doc(`admin_new_order_${orderRef.id}`),
      {
        recipientId: 'admin',
        type: 'new_order',
        title: `New order ${orderNumber}`,
        body: `${String(user.displayName || user.fullName || 'A customer')} placed a ${paymentMethod} order worth ${money(total)}.`,
        orderId: orderRef.id,
        isRead: false,
        createdAt: admin.firestore.FieldValue.serverTimestamp()
      }
    );

    transaction.set(
      counterRef,
      { lastNumber: nextNumber },
      { merge: true }
    );

    transaction.set(
      userRef,
      {
        totalOrders: admin.firestore.FieldValue.increment(1),
        totalSpent: admin.firestore.FieldValue.increment(total),
        updatedAt: admin.firestore.FieldValue.serverTimestamp()
      },
      { merge: true }
    );

    for (const entry of cartSnapshots.values()) {
      if (entry.snapshot.exists) {
        transaction.delete(entry.ref);
      }
    }

    return {
      orderId: orderRef.id,
      orderNumber,
      total,
      transactionReference: reference,
      usedTrustedBackend: true
    };
  });

  return result;
});

function tokenName(authContext) {
  const token = authContext.token || {};
  return token.name || token.displayName || '';
}

// ---------------------------------------------------------------------------
// Order cancellation with stock restoration
// ---------------------------------------------------------------------------

exports.cancelOrder = regionalFunctions.https.onCall(async (data, context) => {
  const authContext = requireSignedIn(context);
  const uid = authContext.uid;
  const orderId = String((data && data.orderId) || '').trim();
  const reason = String((data && data.reason) || '').trim().slice(0, 300);
  const isAdmin = authContext.token.admin === true;

  if (!orderId) {
    throw new functions.https.HttpsError(
      'invalid-argument',
      'An order id is required.'
    );
  }

  const orderRef = db.collection('orders').doc(orderId);
  const result = await db.runTransaction(async (transaction) => {
    const orderSnapshot = await transaction.get(orderRef);
    if (!orderSnapshot.exists) {
      throw new functions.https.HttpsError('not-found', 'This order was not found.');
    }
    const order = orderSnapshot.data() || {};
    if (!isAdmin && order.customerId !== uid) {
      throw new functions.https.HttpsError(
        'permission-denied',
        'You cannot cancel this order.'
      );
    }
    if (order.status !== 'placed') {
      throw new functions.https.HttpsError(
        'failed-precondition',
        'This order can no longer be cancelled.'
      );
    }

    const rawItems = Array.isArray(order.items) ? order.items : [];
    const productSnapshots = new Map();
    for (const item of rawItems) {
      const productId = String(item.productId || '');
      if (!productId || productSnapshots.has(productId)) continue;
      const snapshot = await transaction.get(
        db.collection('products').doc(productId)
      );
      productSnapshots.set(productId, snapshot);
    }

    for (const item of rawItems) {
      const productId = String(item.productId || '');
      const snapshot = productSnapshots.get(productId);
      if (!snapshot || !snapshot.exists) continue;
      const product = snapshot.data() || {};
      const stock = { ...(product.stock || {}) };
      const size = String(item.size || '');
      const quantity = Number(item.quantity) || 0;
      if (!size || quantity <= 0) continue;
      stock[size] = (Number(stock[size]) || 0) + quantity;
      transaction.update(snapshot.ref, {
        stock,
        totalStock: (Number(product.totalStock) || 0) + quantity,
        updatedAt: admin.firestore.FieldValue.serverTimestamp()
      });
    }

    const timeline = Array.isArray(order.timeline) ? [...order.timeline] : [];
    timeline.push({
      status: 'cancelled',
      title: 'Order cancelled',
      note: reason || (isAdmin ? 'Cancelled by the store.' : 'Cancelled by customer.'),
      at: admin.firestore.Timestamp.now()
    });

    transaction.update(orderRef, {
      status: 'cancelled',
      cancelReason: reason || (isAdmin ? 'Cancelled by the store.' : 'Cancelled by customer.'),
      restockPending: false,
      restockedAt: admin.firestore.FieldValue.serverTimestamp(),
      customerTotalsApplied: false,
      timeline,
      updatedAt: admin.firestore.FieldValue.serverTimestamp()
    });

    transaction.set(db.collection('notifications').doc(`customer_order_${orderId}_cancelled`), {
      recipientId: order.customerId,
      type: 'order_cancelled',
      title: `Order ${order.orderNumber || orderId} cancelled`,
      body: 'Your order was cancelled and the items were returned to stock.',
      orderId,
      isRead: false,
      createdAt: admin.firestore.FieldValue.serverTimestamp()
    });

    // Customers notify the store when they cancel; an administrator action does
    // not need to alert the same administrator. The deterministic id prevents
    // duplicate alerts if the transaction is retried.
    if (!isAdmin && order.customerId) {
      transaction.set(
        db.collection('notifications').doc(`admin_order_cancelled_${orderId}`),
        {
          recipientId: 'admin',
          type: 'order_cancelled',
          title: `Order ${order.orderNumber || orderId} cancelled`,
          body: `${String(order.customerName || 'A customer')} cancelled ${order.orderNumber || orderId}. The items were returned to stock.`,
          orderId,
          isRead: false,
          createdAt: admin.firestore.FieldValue.serverTimestamp()
        }
      );
    }

    if (order.customerId && order.customerTotalsApplied === true) {
      transaction.set(
        db.collection('users').doc(order.customerId),
        {
          totalOrders: admin.firestore.FieldValue.increment(-1),
          totalSpent: admin.firestore.FieldValue.increment(
            -(Number(order.total) || 0)
          ),
          updatedAt: admin.firestore.FieldValue.serverTimestamp()
        },
        { merge: true }
      );
    }

    return { success: true, orderId, orderNumber: order.orderNumber || null };
  });

  return result;
});

// ---------------------------------------------------------------------------
// Order status notifications (customer-facing timeline + in-app alert)
// ---------------------------------------------------------------------------

const STATUS_TITLES = {
  placed: 'Order placed',
  confirmed: 'Order confirmed',
  processing: 'Preparing your order',
  ready_for_shipment: 'Ready for shipment',
  shipped: 'Order shipped',
  out_for_delivery: 'Out for delivery',
  delivered: 'Order delivered',
  cancelled: 'Order cancelled',
  refunded: 'Order refunded'
};

exports.onOrderStatusChanged = regionalFunctions.firestore
  .document('orders/{orderId}')
  .onUpdate(async (change, context) => {
    const before = change.before.data() || {};
    const after = change.after.data() || {};
    if (before.status === after.status) return null;
    if (!ORDER_STATUSES.includes(after.status)) return null;

    const orderId = context.params.orderId;
    const customerId = String(after.customerId || '');
    if (!customerId) return null;

    const title = STATUS_TITLES[after.status] || 'Order updated';
    const label = after.orderNumber || orderId;
    const body = `Order ${label}: ${title}.`;

    // A deterministic id keeps the alert idempotent if the trigger is retried
    // and matches the administrator dashboard's client-side fallback.
    await db
      .collection('notifications')
      .doc(`customer_order_${orderId}_${after.status}`)
      .set(
        {
          recipientId: customerId,
          type: `order_${after.status}`,
          title,
          body,
          orderId,
          isRead: false,
          createdAt: admin.firestore.FieldValue.serverTimestamp()
        },
        { merge: true }
      );

    return null;
  });

// ---------------------------------------------------------------------------
// Chat notifications
// ---------------------------------------------------------------------------

exports.onChatMessageCreated = regionalFunctions.firestore
  .document('chats/{customerId}/messages/{messageId}')
  .onCreate(async (snapshot, context) => {
    const message = snapshot.data() || {};
    const customerId = context.params.customerId;
    const text = String(message.text || '').trim();
    if (!text) return null;

    if (message.senderRole === 'customer') {
      // Idempotent administrator alert: retries overwrite the same document
      // instead of creating a second notification.
      await db
        .collection('notifications')
        .doc(`admin_chat_${context.params.messageId}`)
        .set(
          {
            recipientId: 'admin',
            type: 'chat_message',
            title: 'New customer message',
            body: text.slice(0, 140),
            customerId,
            chatId: customerId,
            isRead: false,
            createdAt: admin.firestore.FieldValue.serverTimestamp()
          },
          { merge: true }
        );
    } else if (message.senderRole === 'admin') {
      await db
        .collection('notifications')
        .doc(`customer_chat_${context.params.messageId}`)
        .set(
          {
            recipientId: customerId,
            type: 'chat_reply',
            title: 'Unleashed Clothing replied',
            body: text.slice(0, 140),
            customerId,
            chatId: customerId,
            isRead: false,
            createdAt: admin.firestore.FieldValue.serverTimestamp()
          },
          { merge: true }
        );
    }

    return null;
  });
