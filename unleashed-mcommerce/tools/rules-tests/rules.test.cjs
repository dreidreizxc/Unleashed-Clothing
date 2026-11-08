/**
 * Offline Firestore security-rules tests for the canonical rules.
 *
 * Run only against the local emulator (see README.md). These tests never
 * contact the production Firebase project.
 */
const { test, before, after, beforeEach } = require('node:test')
const assert = require('node:assert/strict')
const fs = require('node:fs')
const path = require('node:path')

const {
  initializeTestEnvironment,
  assertFails,
  assertSucceeds,
} = require('@firebase/rules-unit-testing')

const {
  doc,
  getDoc,
  setDoc,
  updateDoc,
  deleteDoc,
  runTransaction,
  writeBatch,
  getDocs,
  collection,
  query,
  where,
  Timestamp,
  serverTimestamp,
} = require('firebase/firestore')

const PROJECT_ID = 'demo-unleashed-rules'
const RULES = fs.readFileSync(path.resolve(__dirname, '../../firestore.rules'), 'utf8')

let env

const A = 'customer-a'
const B = 'customer-b'
const ADMIN = 'admin-uid'

before(async () => {
  env = await initializeTestEnvironment({
    projectId: PROJECT_ID,
    firestore: {
      host: '127.0.0.1',
      port: 8085,
      rules: RULES,
    },
  })
})

after(async () => {
  await env.cleanup()
})

beforeEach(async () => {
  await env.clearFirestore()
})

function appDb() {
  return env.unauthenticatedContext().firestore()
}

async function seed(fn) {
  await env.withSecurityRulesDisabled(async (context) => {
    await fn(context.firestore())
  })
}

function customer(uid = A, claims = {}) {
  return env.authenticatedContext(uid, {
    ...claims,
  }).firestore()
}

function passwordAuthenticatedCustomer(uid = A, claims = {}) {
  return env.authenticatedContext(uid, {
    ...claims,
  }).firestore()
}

function admin() {
  return env.authenticatedContext(ADMIN, { admin: true }).firestore()
}

function validItems() {
  return [
    {
      productId: 'tee',
      name: 'Unleashed Tee',
      size: 'M',
      price: 59900,
      quantity: 2,
      subtotal: 119800,
      category: 'T-Shirt',
      imageId: null,
    },
  ]
}

function orderPayload(uid, overrides = {}) {
  const items = overrides.requestedItems ?? validItems()
  const subtotal = overrides.requestedSubtotal ?? 119800
  const shippingFee = overrides.requestedShippingFee ?? 5000
  const total = overrides.requestedTotal ?? subtotal + shippingFee
  return {
    status: 'pending_confirmation',
    customerId: uid,
    customerName: 'Test Customer',
    customerEmail: 'customer@test.local',
    clientOrderId: 'order-a-0001',
    requestReference: 'REQ-TEST',
    requestedItems: items,
    items: items,
    itemCount: 2,
    requestedSubtotal: subtotal,
    requestedShippingFee: shippingFee,
    requestedTotal: total,
    subtotal,
    shippingFee,
    total,
    totalsVerified: false,
    paymentMethod: 'COD',
    paymentStatus: 'unpaid',
    paymentSimulated: false,
    simulatedPaymentStatus: 'not_applicable',
    fulfillmentStatus: 'unfulfilled',
    customerTotalsApplied: false,
    shippingAddress: '1 Test St, Test, Test City, Test Province, 1000',
    shippingAddressMap: {
      street: '1 Test St',
      barangay: 'Test',
      city: 'Test City',
      province: 'Test Province',
      postalCode: '1000',
    },
    source: 'mobile',
    timeline: [
      {
        status: 'pending_confirmation',
        title: 'Request submitted',
        at: Timestamp.now(),
      },
    ],
    createdAt: serverTimestamp(),
    updatedAt: serverTimestamp(),
    ...overrides,
  }
}

function notificationPayload(uid, orderId, type = 'order_requested', overrides = {}) {
  return {
    recipientId: uid,
    type,
    title: 'Request received',
    body: 'Your request was received.',
    orderId,
    isRead: false,
    createdAt: serverTimestamp(),
    ...overrides,
  }
}

async function seedBase() {
  await seed(async (db) => {
    await setDoc(doc(db, 'users', A), {
      uid: A,
      role: 'customer',
      isActive: true,
      email: 'customer@test.local',
      fullName: 'Test Customer',
      totalOrders: 0,
      totalSpent: 0,
    })
    await setDoc(doc(db, 'users', B), {
      uid: B,
      role: 'customer',
      isActive: true,
      email: 'other@test.local',
      fullName: 'Other Customer',
      totalOrders: 0,
      totalSpent: 0,
    })
    await setDoc(doc(db, 'products', 'tee'), {
      name: 'Unleashed Tee',
      status: 'active',
      price: 59900,
      sizes: ['S', 'M', 'L', 'XL'],
      stock: { S: 0, M: 5, L: 12, XL: 0 },
      totalStock: 17,
    })
    await setDoc(doc(db, 'settings', 'store'), {
      storeName: 'Unleashed Clothing',
      shippingFee: 5000,
      freeShippingThreshold: null,
    })
    await setDoc(doc(db, 'products', 'other-tee'), {
      name: 'Other Tee',
      status: 'active',
      price: 49900,
      sizes: ['M'],
      stock: { M: 3 },
      totalStock: 3,
    })
  })
}

// ---------------------------------------------------------------------------
// Public catalogue and announcements
// ---------------------------------------------------------------------------

test('guest can read products', async () => {
  await seedBase()
  await assertSucceeds(getDoc(doc(appDb(), 'products', 'tee')))
})

test('guest can read active announcements with the public query', async () => {
  await seed(async (db) => {
    await setDoc(doc(db, 'announcements', 'active-1'), {
      title: 'Live',
      message: 'Public',
      active: true,
      createdAt: Timestamp.now(),
    })
    await setDoc(doc(db, 'announcements', 'inactive-1'), {
      title: 'Hidden',
      message: 'Draft',
      active: false,
      createdAt: Timestamp.now(),
    })
  })
  await assertSucceeds(
    getDocs(query(collection(appDb(), 'announcements'), where('active', '==', true))),
  )
})

test('guest cannot read an inactive announcement directly', async () => {
  await seed(async (db) => {
    await setDoc(doc(db, 'announcements', 'inactive-1'), {
      title: 'Hidden',
      message: 'Draft',
      active: false,
    })
  })
  await assertFails(getDoc(doc(appDb(), 'announcements', 'inactive-1')))
})

test('guest cannot create or update announcements', async () => {
  const db = appDb()
  await assertFails(
    setDoc(doc(db, 'announcements', 'evil'), { title: 'x', message: 'y', active: true }),
  )
})

test('admin can create and deactivate announcements', async () => {
  const db = admin()
  await assertSucceeds(
    setDoc(doc(db, 'announcements', 'a1'), { title: 'New', message: 'Body', active: true }),
  )
  await assertSucceeds(
    updateDoc(doc(db, 'announcements', 'a1'), { active: false }),
  )
})

// ---------------------------------------------------------------------------
// Customer profiles
// ---------------------------------------------------------------------------

test('customer can read their own profile but not another customer profile', async () => {
  await seedBase()
  await assertSucceeds(getDoc(doc(customer(), 'users', A)))
  await assertFails(getDoc(doc(customer(), 'users', B)))
  await assertSucceeds(getDoc(doc(admin(), 'users', B)))
})

test('customer can create their own customer profile only', async () => {
  const db = customer(A)
  await assertSucceeds(
    setDoc(doc(db, 'users', A), {
      uid: A,
      role: 'customer',
      isActive: true,
      email: 'customer@test.local',
      totalOrders: 0,
      totalSpent: 0,
    }),
  )
})

test('customer cannot self-promote or change protected profile fields', async () => {
  await seedBase()
  const db = customer(A)
  await assertFails(updateDoc(doc(db, 'users', A), { role: 'admin' }))
  await assertFails(updateDoc(doc(db, 'users', A), { totalSpent: 1 }))
  await assertFails(updateDoc(doc(db, 'users', A), { isActive: false }))
  await assertSucceeds(updateDoc(doc(db, 'users', A), { fullName: 'Renamed Customer' }))
})

test('unauthenticated user cannot read customer profiles', async () => {
  await seedBase()
  await assertFails(getDoc(doc(appDb(), 'users', A)))
})

test('customer cannot modify another customer cart', async () => {
  await seed(async (db) => {
    await setDoc(doc(db, 'carts', B, 'items', 'line-1'), { productId: 'tee', quantity: 1 })
  })
  await assertFails(getDoc(doc(customer(), 'carts', B, 'items', 'line-1')))
})

// ---------------------------------------------------------------------------
// Order request creation
// ---------------------------------------------------------------------------

test('verified customer can create a valid pending request', async () => {
  await seedBase()
  await assertSucceeds(
    setDoc(doc(customer(), 'orders', 'order-a-0001'), orderPayload(A)),
  )
})

test('checkout transaction creates order, notifications, and clears cart atomically', async () => {
  await seedBase()
  await seed(async (db) => {
    await setDoc(doc(db, 'carts', A, 'items', 'line-1'), {
      productId: 'tee',
      name: 'Unleashed Tee',
      size: 'M',
      price: 59900,
      quantity: 2,
    })
  })

  const db = customer(A)
  await assertSucceeds(
    runTransaction(db, async (transaction) => {
      const orderRef = doc(db, 'orders', 'order-a-0001')
      const existing = await transaction.get(orderRef)
      assert.equal(existing.exists(), false)

      const order = orderPayload(A)
      transaction.set(orderRef, order)
      transaction.set(
        doc(db, 'notifications', 'order-requested_order-a-0001'),
        notificationPayload(A, 'order-a-0001', 'order_requested'),
      )
      transaction.set(
        doc(db, 'notifications', 'order-new_admin_order-a-0001'),
        notificationPayload('admin', 'order-a-0001', 'new_order_request'),
      )
      transaction.delete(doc(db, 'carts', A, 'items', 'line-1'))
    }),
  )
})

test('customer cannot create a request for another customer', async () => {
  await seedBase()
  await assertFails(
    setDoc(doc(customer(), 'orders', 'order-a-0001'), orderPayload(B)),
  )
})

test('customer cannot assign an order number, verified totals, or paid status', async () => {
  await seedBase()
  for (const override of [
    { orderNumber: 'UND-000001' },
    { totalsVerified: true },
    { customerTotalsApplied: true },
    { paymentStatus: 'paid' },
    { status: 'confirmed' },
  ]) {
    await assertFails(
      setDoc(doc(customer(), 'orders', 'order-a-0001'), orderPayload(A, override)),
    )
  }
})

test('customer request must have matching mirrored totals and items', async () => {
  await seedBase()
  await assertFails(
    setDoc(
      doc(customer(), 'orders', 'order-a-0001'),
      orderPayload(A, { requestedTotal: 1, total: 1 }),
    ),
  )
  await assertFails(
    setDoc(
      doc(customer(), 'orders', 'order-a-0001'),
      orderPayload(A, { items: [] }),
    ),
  )
})

test('customer request requires a complete shipping address', async () => {
  await seedBase()
  await assertFails(
    setDoc(
      doc(customer(), 'orders', 'order-a-0001'),
      orderPayload(A, {
        shippingAddressMap: { street: '', barangay: 'Test', city: 'Test', province: 'Test', postalCode: '1' },
      }),
    ),
  )
})

test('customer without a profile document cannot create a request', async () => {
  await seed(async (db) => {
    await setDoc(doc(db, 'products', 'tee'), {
      name: 'Unleashed Tee',
      status: 'active',
      price: 59900,
      sizes: ['M'],
      stock: { M: 5 },
    })
  })
  await assertFails(
    setDoc(doc(customer(A), 'orders', 'order-a-0001'), orderPayload(A)),
  )
})

test('authenticated customer can order without OTP or email-verification claims', async () => {
  await seedBase()
  await assertSucceeds(
    setDoc(doc(customer(A), 'orders', 'order-a-0001'), orderPayload(A)),
  )
})

test('order document id must match clientOrderId', async () => {
  await seedBase()
  await assertFails(
    setDoc(doc(customer(), 'orders', 'different-id'), orderPayload(A)),
  )
})

// ---------------------------------------------------------------------------
// Order reads, cancellation, and protected state
// ---------------------------------------------------------------------------

test('customers can read only their own orders; admin can read all', async () => {
  await seedBase()
  await seed(async (db) => {
    await setDoc(doc(db, 'orders', 'order-a-0001'), orderPayload(A, { clientOrderId: 'order-a-0001' }))
    await setDoc(doc(db, 'orders', 'order-b-0001'), orderPayload(B, { clientOrderId: 'order-b-0001' }))
  })
  await assertSucceeds(getDoc(doc(customer(A), 'orders', 'order-a-0001')))
  await assertFails(getDoc(doc(customer(A), 'orders', 'order-b-0001')))
  await assertSucceeds(getDoc(doc(admin(), 'orders', 'order-b-0001')))
})

test('missing-document allowance does not let a customer list all orders', async () => {
  await seedBase()
  await seed(async (db) => {
    await setDoc(doc(db, 'orders', 'order-a-0001'), orderPayload(A, { clientOrderId: 'order-a-0001' }))
    await setDoc(doc(db, 'orders', 'order-b-0001'), orderPayload(B, { clientOrderId: 'order-b-0001' }))
  })
  const db = customer(A)
  await assertFails(getDocs(collection(db, 'orders')))
  const own = await assertSucceeds(
    getDocs(query(collection(db, 'orders'), where('customerId', '==', A))),
  )
  assert.equal(own.size, 1)
  assert.equal(own.docs[0].id, 'order-a-0001')
  await assertFails(getDocs(collection(appDb(), 'orders')))
})

test('customer can withdraw a pending request but cannot rewrite its money fields', async () => {
  await seedBase()
  await seed(async (db) => {
    await setDoc(doc(db, 'orders', 'order-a-0001'), orderPayload(A, { clientOrderId: 'order-a-0001' }))
  })
  const db = customer(A)
  await assertSucceeds(
    updateDoc(doc(db, 'orders', 'order-a-0001'), {
      status: 'cancelled',
      fulfillmentStatus: 'cancelled',
      cancelReason: 'Changed my mind',
      cancelledAt: serverTimestamp(),
      cancelledBy: A,
      customerTotalsApplied: false,
      restockPending: false,
      timeline: [
        { status: 'pending_confirmation', title: 'Request submitted', at: Timestamp.now() },
        { status: 'cancelled', title: 'Request cancelled', at: Timestamp.now() },
      ],
      updatedAt: serverTimestamp(),
    }),
  )
  await assertFails(updateDoc(doc(db, 'orders', 'order-a-0001'), { total: 1 }))
})

test('customer cannot cancel or confirm a reviewed order', async () => {
  await seedBase()
  await seed(async (db) => {
    await setDoc(
      doc(db, 'orders', 'order-a-0001'),
      orderPayload(A, {
        clientOrderId: 'order-a-0001',
        status: 'confirmed',
        orderNumber: 'UND-000001',
        totalsVerified: true,
        customerTotalsApplied: true,
      }),
    )
  })
  const db = customer(A)
  await assertFails(
    updateDoc(doc(db, 'orders', 'order-a-0001'), {
      status: 'cancelled',
      cancelledBy: A,
      cancelledAt: serverTimestamp(),
      updatedAt: serverTimestamp(),
    }),
  )
  await assertFails(
    updateDoc(doc(db, 'orders', 'order-a-0001'), { status: 'delivered' }),
  )
})

test('customers cannot hard-delete orders', async () => {
  await seedBase()
  await seed(async (db) => {
    await setDoc(doc(db, 'orders', 'order-a-0001'), orderPayload(A, { clientOrderId: 'order-a-0001' }))
  })
  await assertFails(deleteDoc(doc(customer(), 'orders', 'order-a-0001')))
})

test('customer can alert the administrator after withdrawing a request', async () => {
  await seedBase()
  await seed(async (db) => {
    await setDoc(doc(db, 'orders', 'order-a-0001'), orderPayload(A, { clientOrderId: 'order-a-0001' }))
  })
  const db = customer(A)
  await assertSucceeds(
    setDoc(doc(db, 'notifications', 'admin-cancelled_order-a-0001'), {
      recipientId: 'admin',
      type: 'order_cancelled',
      title: 'Request cancelled',
      body: 'Customer cancelled a request.',
      orderId: 'order-a-0001',
      isRead: false,
      createdAt: serverTimestamp(),
    }),
  )
  await assertFails(
    setDoc(doc(db, 'notifications', 'admin-cancelled_spoof'), {
      recipientId: 'admin',
      type: 'order_cancelled',
      title: 'Request cancelled',
      body: 'Spoofed.',
      orderId: 'order-b-0001',
      isRead: false,
      createdAt: serverTimestamp(),
    }),
  )
})

test('admin can confirm an order and change protected fields', async () => {
  await seedBase()
  await seed(async (db) => {
    await setDoc(doc(db, 'orders', 'order-a-0001'), orderPayload(A, { clientOrderId: 'order-a-0001' }))
  })
  const db = admin()
  await assertSucceeds(
    updateDoc(doc(db, 'orders', 'order-a-0001'), {
      status: 'confirmed',
      orderNumber: 'UND-000001',
      totalsVerified: true,
      customerTotalsApplied: true,
      confirmedAt: serverTimestamp(),
      confirmedBy: ADMIN,
      total: 119800,
      updatedAt: serverTimestamp(),
    }),
  )
})

// ---------------------------------------------------------------------------
// Inventory and administrator-owned data
// ---------------------------------------------------------------------------

test('customers cannot modify product prices or stock', async () => {
  await seedBase()
  await assertFails(
    updateDoc(doc(customer(), 'products', 'tee'), { price: 1, stock: { M: 999 } }),
  )
})

test('admin can modify product stock', async () => {
  await seedBase()
  await assertSucceeds(
    updateDoc(doc(admin(), 'products', 'tee'), { stock: { S: 0, M: 4, L: 12, XL: 0 }, totalStock: 16 }),
  )
})

test('customers cannot read or write the order counter', async () => {
  await seed(async (db) => {
    await setDoc(doc(db, 'counters', 'orders'), { lastNumber: 10 })
  })
  await assertFails(getDoc(doc(customer(), 'counters', 'orders')))
  await assertFails(
    updateDoc(doc(customer(), 'counters', 'orders'), { lastNumber: 11 }),
  )
  await assertSucceeds(getDoc(doc(admin(), 'counters', 'orders')))
})

test('inventory logs are admin-only and append-only', async () => {
  await seedBase()
  const db = admin()
  await assertSucceeds(
    setDoc(doc(db, 'inventory_logs', 'log-1'), {
      productId: 'tee',
      size: 'M',
      change: -2,
      createdAt: serverTimestamp(),
    }),
  )
  await assertSucceeds(getDoc(doc(db, 'inventory_logs', 'log-1')))
  await assertFails(updateDoc(doc(db, 'inventory_logs', 'log-1'), { change: 999 }))
  await assertFails(deleteDoc(doc(db, 'inventory_logs', 'log-1')))
  await assertFails(getDoc(doc(customer(), 'inventory_logs', 'log-1')))
})

test('guest can read store/security settings but not other settings docs', async () => {
  await seed(async (db) => {
    await setDoc(doc(db, 'settings', 'store'), { storeName: 'Unleashed Clothing' })
    await setDoc(doc(db, 'settings', 'security'), {})
    await setDoc(doc(db, 'settings', 'private'), { secret: 'nope' })
  })
  await assertSucceeds(getDoc(doc(appDb(), 'settings', 'store')))
  await assertSucceeds(getDoc(doc(appDb(), 'settings', 'security')))
  await assertFails(getDoc(doc(appDb(), 'settings', 'private')))
})

test('customers cannot write store settings; admin can', async () => {
  await seedBase()
  await assertFails(
    updateDoc(doc(customer(), 'settings', 'store'), { shippingFee: 0 }),
  )
  await assertSucceeds(
    updateDoc(doc(admin(), 'settings', 'store'), { shippingFee: 7000 }),
  )
})

test('customers cannot read or write admin activity logs', async () => {
  await seed(async (db) => {
    await setDoc(doc(db, 'admin_activity_logs', 'log-1'), { action: 'confirmed' })
  })
  await assertFails(getDoc(doc(customer(), 'admin_activity_logs', 'log-1')))
  await assertFails(
    setDoc(doc(customer(), 'admin_activity_logs', 'log-2'), { action: 'fake' }),
  )
  await assertSucceeds(getDoc(doc(admin(), 'admin_activity_logs', 'log-1')))
})

// ---------------------------------------------------------------------------
// Notifications
// ---------------------------------------------------------------------------

test('customer can acknowledge their own request notification but not write arbitrary ones', async () => {
  await seedBase()
  await seed(async (db) => {
    await setDoc(doc(db, 'orders', 'order-a-0001'), orderPayload(A, { clientOrderId: 'order-a-0001' }))
  })
  const db = customer(A)
  await assertSucceeds(
    setDoc(
      doc(db, 'notifications', 'order-requested_order-a-0001'),
      notificationPayload(A, 'order-a-0001', 'order_requested'),
    ),
  )
  await assertSucceeds(
    setDoc(
      doc(db, 'notifications', 'order-new_order-a-0001'),
      notificationPayload('admin', 'order-a-0001', 'new_order_request'),
    ),
  )
  await assertFails(
    setDoc(
      doc(db, 'notifications', 'spoof-1'),
      notificationPayload(B, 'order-a-0001', 'order_requested'),
    ),
  )
  await assertFails(
    setDoc(
      doc(db, 'notifications', 'spoof-2'),
      notificationPayload(A, 'order-a-0001', 'promo'),
    ),
  )
})

test('customer cannot read another customer notification', async () => {
  await seed(async (db) => {
    await setDoc(doc(db, 'notifications', 'n1'), {
      recipientId: B,
      type: 'order_requested',
      title: 'Hi',
      body: 'Body',
      isRead: false,
    })
  })
  await assertFails(getDoc(doc(customer(A), 'notifications', 'n1')))
  await assertSucceeds(getDoc(doc(admin(), 'notifications', 'n1')))
})

test('recipient can mark a notification read but cannot rewrite its content', async () => {
  await seed(async (db) => {
    await setDoc(doc(db, 'notifications', 'n1'), {
      recipientId: A,
      type: 'order_requested',
      title: 'Hi',
      body: 'Body',
      isRead: false,
    })
  })
  const db = customer(A)
  await assertSucceeds(updateDoc(doc(db, 'notifications', 'n1'), { isRead: true, readAt: serverTimestamp() }))
  await assertFails(updateDoc(doc(db, 'notifications', 'n1'), { title: 'Changed' }))
})

// ---------------------------------------------------------------------------
// Chat
// ---------------------------------------------------------------------------

test('customer can use their own chat but not another customer chat', async () => {
  await seed(async (db) => {
    await setDoc(doc(db, 'chats', B), { customerId: B })
  })
  const db = customer(A)
  await assertSucceeds(setDoc(doc(db, 'chats', A), { customerId: A }))
  await assertFails(getDoc(doc(db, 'chats', B)))
  await assertFails(updateDoc(doc(db, 'chats', B), { lastMessage: 'hijack' }))
})

test('customer messages are restricted to the customer role and own thread', async () => {
  await seed(async (db) => {
    await setDoc(doc(db, 'chats', A), { customerId: A })
  })
  const db = customer(A)
  await assertSucceeds(
    setDoc(doc(db, 'chats', A, 'messages', 'm1'), {
      senderId: A,
      senderRole: 'customer',
      text: 'Hello',
      isRead: false,
      createdAt: serverTimestamp(),
    }),
  )
  await assertFails(
    setDoc(doc(db, 'chats', A, 'messages', 'm2'), {
      senderId: A,
      senderRole: 'admin',
      text: 'Fake admin',
      isRead: false,
      createdAt: serverTimestamp(),
    }),
  )
  await assertFails(
    setDoc(doc(db, 'chats', B, 'messages', 'm3'), {
      senderId: A,
      senderRole: 'customer',
      text: 'Wrong thread',
      isRead: false,
      createdAt: serverTimestamp(),
    }),
  )
})

test('admin can reply to a customer chat', async () => {
  await seed(async (db) => {
    await setDoc(doc(db, 'chats', A), { customerId: A })
  })
  await assertSucceeds(
    setDoc(doc(admin(), 'chats', A, 'messages', 'reply-1'), {
      senderId: ADMIN,
      senderRole: 'admin',
      text: 'We can help.',
      isRead: false,
      createdAt: serverTimestamp(),
    }),
  )
})

// ---------------------------------------------------------------------------
// Reviews
// ---------------------------------------------------------------------------

test('customer can create an admin notification with a new review', async () => {
  await seedBase()

  await seed(async (db) => {
    await setDoc(
      doc(db, 'orders', 'delivered-a'),
      orderPayload(A, {
        clientOrderId: 'delivered-a',
        status: 'delivered',
        totalsVerified: true,
        customerTotalsApplied: true,
        orderNumber: 'UND-000010',
      }),
    )
  })

  const db = customer(A)
  const batch = writeBatch(db)
  const reviewId = 'tee_' + A

  batch.set(doc(db, 'reviews', reviewId), {
    customerId: A,
    customerName: 'Test Customer',
    productId: 'tee',
    orderId: 'delivered-a',
    rating: 5,
    text: 'Great',
    createdAt: serverTimestamp(),
  })

  batch.set(doc(db, 'notifications', 'new-review-test'), {
    recipientId: 'admin',
    type: 'new_review',
    title: 'New Customer Review',
    body: 'Test Customer submitted a 5-star review.',
       customerId: A,
    orderId: 'delivered-a',
    reviewId: reviewId,
    productId: 'tee',
    rating: 5,
    isRead: false,
    createdAt: serverTimestamp(),
  })

  await assertSucceeds(batch.commit())
})
test('customer cannot review without a delivered order', async () => {
  await seedBase()
  await seed(async (db) => {
    await setDoc(doc(db, 'orders', 'pending-a'), orderPayload(A, { clientOrderId: 'pending-a' }))
  })
  await assertFails(
    setDoc(doc(customer(A), 'reviews', 'tee_' + A), {
      customerId: A,
      customerName: 'Test Customer',
      productId: 'tee',
      orderId: 'pending-a',
      rating: 5,
      text: 'Too early',
      createdAt: serverTimestamp(),
    }),
  )
})

test('customer cannot review using another customer delivered order', async () => {
  await seedBase()
  await seed(async (db) => {
    await setDoc(
      doc(db, 'orders', 'delivered-b'),
      orderPayload(B, {
        clientOrderId: 'delivered-b',
        status: 'delivered',
        totalsVerified: true,
        customerTotalsApplied: true,
      }),
    )
  })
  await assertFails(
    setDoc(doc(customer(A), 'reviews', 'tee_' + A), {
      customerId: A,
      customerName: 'Test Customer',
      productId: 'tee',
      orderId: 'delivered-b',
      rating: 5,
      text: 'Not mine',
      createdAt: serverTimestamp(),
    }),
  )
})

// ---------------------------------------------------------------------------
// Catch-all
// ---------------------------------------------------------------------------

test('product images are publicly readable but admin-writable only', async () => {
  await seed(async (db) => {
    await setDoc(doc(db, 'product_images', 'tee'), { bytes: 'abc' })
  })
  await assertSucceeds(getDoc(doc(appDb(), 'product_images', 'tee')))
  await assertFails(
    setDoc(doc(customer(), 'product_images', 'evil'), { bytes: 'x' }),
  )
  await assertSucceeds(
    setDoc(doc(admin(), 'product_images', 'tee'), { bytes: 'updated' }),
  )
})

test('payment transactions are read-only for the owning customer', async () => {
  await seed(async (db) => {
    await setDoc(doc(db, 'transactions', 't1'), {
      customerId: A,
      amount: 119800,
      status: 'recorded',
    })
  })
  await assertSucceeds(getDoc(doc(customer(), 'transactions', 't1')))
  await assertFails(
    setDoc(doc(customer(), 'transactions', 't2'), {
      customerId: A,
      amount: 1,
      status: 'paid',
    }),
  )
  await assertSucceeds(
    setDoc(doc(admin(), 'transactions', 't3'), {
      customerId: A,
      amount: 119800,
      status: 'recorded',
    }),
  )
})

test('saved addresses are owner-scoped', async () => {
  await seed(async (db) => {
    await setDoc(doc(db, 'users', B, 'addresses', 'home'), {
      street: '2 Other St',
      city: 'Other City',
    })
  })
  await assertFails(
    getDoc(doc(customer(A), 'users', B, 'addresses', 'home')),
  )
  await assertSucceeds(
    setDoc(doc(customer(A), 'users', A, 'addresses', 'home'), {
      street: '1 Test St',
      city: 'Test City',
    }),
  )
})

test('authenticated customer without OTP or email claims can read only their own profile', async () => {
  await seedBase()

  await assertSucceeds(
    getDoc(doc(customer(A), 'users', A)),
  )

  await assertFails(
    getDoc(doc(customer(A), 'users', B)),
  )
})
test('unmatched collections are denied for everyone', async () => {
  await assertFails(
    setDoc(doc(customer(), 'unknown_collection', 'x'), { value: 1 }),
  )
  await assertFails(getDoc(doc(admin(), 'unknown_collection', 'x')))
})


