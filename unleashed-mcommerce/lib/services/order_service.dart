import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../config/app_config.dart';
import '../core/errors.dart';
import '../core/notification_ids.dart';
import '../models/cart_item.dart';
import '../models/order.dart';
import '../models/payment_transaction.dart';
import '../models/product.dart';
import '../models/user_profile.dart';
import 'auth_service.dart';
import 'cart_service.dart';
import 'checkout_validation.dart';
import 'product_service.dart';

/// The customer-facing result of submitting an order request.
///
/// There is deliberately no official order number here: customers submit a
/// provisional request and the administrator assigns `orderNumber` when the
/// request is confirmed.
class OrderRequestResult {
  const OrderRequestResult({
    required this.orderId,
    required this.requestedTotal,
    required this.itemCount,
    required this.paymentMethod,
    required this.requestReference,
  });

  final String orderId;
  final int requestedTotal;
  final int itemCount;
  final String paymentMethod;
  final String requestReference;
}

/// Customer-side order service for the Spark-only (no Cloud Functions)
/// deployment.
///
/// A customer can only:
/// * create a provisional `pending_confirmation` request at the current
///   catalogue prices, without reserving stock or assigning an order number;
/// * withdraw that request while it is still pending;
/// * read the orders they own.
///
/// Confirmation, rejection, stock deduction, inventory logs, official order
/// numbers, verified totals and payment status are administrator-only
/// operations performed by the React dashboard through Firestore rules.
class OrderService {
  OrderService._();

  static final OrderService instance = OrderService._();

  FirebaseFirestore get _db => FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _orders =>
      _db.collection(AppConfig.ordersCollection);

  String newClientOrderId(String uid) {
    final random = Random.secure();
    final suffix = List.generate(
      6,
      (_) => random.nextInt(36).toRadixString(36),
    ).join();
    return 'ord_${uid.hashCode.abs().toRadixString(36)}_${DateTime.now().millisecondsSinceEpoch}_$suffix';
  }

  /// Only the customer's most recent 100 orders are streamed. The admin
  /// dashboard owns historical reporting, so the mobile app never needs an
  /// unbounded listener (which also protects Spark read quotas).
  Stream<List<CustomerOrder>> watchOrders(String customerId) {
    return _orders
        .where('customerId', isEqualTo: customerId)
        .limit(100)
        .snapshots()
        .map(_sortedOrders);
  }

  Future<List<CustomerOrder>> fetchOrders(String customerId) async {
    final snapshot = await _orders
        .where('customerId', isEqualTo: customerId)
        .limit(100)
        .get();
    return _sortedOrders(snapshot);
  }

  Stream<CustomerOrder?> watchOrder(String orderId) {
    return _orders.doc(orderId).snapshots().map((doc) {
      if (!doc.exists) return null;
      return CustomerOrder.fromDoc(doc);
    });
  }

  Future<CustomerOrder?> fetchOrder(String orderId) async {
    final doc = await _orders.doc(orderId).get();
    if (!doc.exists) return null;
    return CustomerOrder.fromDoc(doc);
  }

  List<CustomerOrder> _sortedOrders(QuerySnapshot<Map<String, dynamic>> snapshot) {
    final orders = snapshot.docs.map(CustomerOrder.fromDoc).toList();
    orders.sort((a, b) {
      final aTime = a.createdAt?.millisecondsSinceEpoch ?? 0;
      final bTime = b.createdAt?.millisecondsSinceEpoch ?? 0;
      return bTime.compareTo(aTime);
    });
    return orders;
  }

  Stream<List<PaymentTransaction>> watchTransactions(String customerId) {
  return watchOrders(customerId).map(
    (orders) => orders.map(PaymentTransaction.fromOrder).toList(),
  );
}

Future<List<PaymentTransaction>> fetchTransactions(
  String customerId,
) async {
  final orders = await fetchOrders(customerId);
  return orders.map(PaymentTransaction.fromOrder).toList();
}
  /// Submits a provisional order request.
  ///
  /// Everything is written in one Firestore transaction:
  /// * the request itself (`pending_confirmation`, unpaid, unverified totals);
  /// * the requested line items and totals computed from the current product
  ///   documents, so a tampered local cart price cannot change the request;
  /// * the customer acknowledgement and the administrator alert, using
  ///   deterministic ids;
  /// * deletion of only the selected cart lines.
  ///
  /// Nothing here deducts stock, increments the order counter or assigns an
  /// official order number. Those remain administrator-only actions.
  Future<OrderRequestResult> submitOrderRequest({
    required UserProfile profile,
    required List<CartItem> items,
    required String paymentMethod,
    required String clientOrderId,
    String? customerNote,
  }) async {
    final validationError = CheckoutValidation.validate(
      authUid: AuthService.instance.currentUser?.uid,
      profile: profile,
      items: items,
      paymentMethod: paymentMethod,
    );
    if (validationError != null) {
      throw OrderFailure(validationError);
    }

    final simulated = paymentMethod == 'GCash' || paymentMethod == 'Card';
    final orderRef = _orders.doc(clientOrderId);
    final settingsRef = _db
        .collection(AppConfig.settingsCollection)
        .doc(AppConfig.storeSettingsDoc);
    final customerNotificationRef = _db
        .collection(AppConfig.notificationsCollection)
        .doc(NotificationIds.customerOrderRequested(clientOrderId));
    final adminNotificationRef = _db
        .collection(AppConfig.notificationsCollection)
        .doc(NotificationIds.adminNewOrder(clientOrderId));
    final cartRefs = items
        .map((item) => CartService.instance.itemsRef(profile.uid).doc(item.id))
        .toList();

    try {
      return await _db.runTransaction<OrderRequestResult>((transaction) async {
        final existingOrder = await transaction.get(orderRef);
        if (existingOrder.exists) {
          throw const DuplicateOrderFailure(
            'This request has already been submitted. Open your orders to view it.',
          );
        }

        final requestedItems = <Map<String, dynamic>>[];
        var subtotal = 0;
        var totalQuantity = 0;

        for (final item in items) {
          final productRef = _db
              .collection(AppConfig.productsCollection)
              .doc(item.productId);
          final productSnapshot = await transaction.get(productRef);
          if (!productSnapshot.exists) {
            throw OrderFailure(
              '${item.name} is no longer available. Remove it from your cart.',
            );
          }
          final product = Product.fromDoc(productSnapshot);
          if (!product.isActive) {
            throw OrderFailure('${product.name} is not available right now.');
          }
          final available = product.stockFor(item.size);
          if (available < item.quantity) {
            throw OrderFailure(
              available <= 0
                  ? '${product.name} (${item.size}) is out of stock.'
                  : 'Only $available of ${product.name} (${item.size}) remain.',
            );
          }

          final lineTotal = product.price * item.quantity;
          subtotal += lineTotal;
          totalQuantity += item.quantity;
          requestedItems.add({
            'productId': product.id,
            'name': product.name,
            'size': item.size,
            'price': product.price,
            'quantity': item.quantity,
            'subtotal': lineTotal,
            'imageId': product.imageId,
            'category': product.category,
          });
        }

        final settingsSnapshot = await transaction.get(settingsRef);
        final settings = StoreSettings.fromMap(settingsSnapshot.data());
        var shippingFee = settings.shippingFee;
        final threshold = settings.freeShippingThreshold;
        if (threshold != null && subtotal >= threshold) shippingFee = 0;

        final requestedTotal = subtotal + shippingFee;
        final now = Timestamp.now();
        final reference =
            'REQ-${DateTime.now().millisecondsSinceEpoch.toRadixString(36).toUpperCase()}';

        transaction.set(orderRef, {
          // Provisional request. No order number, no stock reservation.
          'status': OrderStatuses.pendingConfirmation,
          'customerId': profile.uid,
          'customerName': profile.fullName,
          'customerEmail': profile.email,
          'requestedItems': requestedItems,
          'items': requestedItems,
          'itemCount': totalQuantity,
          'requestedSubtotal': subtotal,
          'requestedShippingFee': shippingFee,
          'requestedTotal': requestedTotal,
          'subtotal': subtotal,
          'shippingFee': shippingFee,
          'total': requestedTotal,
          'totalsVerified': false,
          'paymentMethod': paymentMethod,
          'paymentStatus': 'unpaid',
          'paymentSimulated': simulated,
          'simulatedPaymentStatus': simulated ? 'not_charged' : 'not_applicable',
          'requestReference': reference,
          'fulfillmentStatus': 'unfulfilled',
          'customerTotalsApplied': false,
          'shippingAddress': profile.address.singleLine,
          'shippingAddressMap': profile.address.toMap(),
          'customerNote': customerNote?.trim().isEmpty == true
              ? null
              : customerNote?.trim(),
          'clientOrderId': clientOrderId,
          'source': 'mobile',
          'timeline': [
            {
              'status': OrderStatuses.pendingConfirmation,
              'title': 'Request submitted',
              'note':
                  'The store will verify prices and stock before confirming '
                  'this order.',
              'at': now,
            },
          ],
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });

        transaction.set(customerNotificationRef, {
          'recipientId': profile.uid,
          'type': 'order_requested',
          'title': 'Request received',
          'body':
              'Your request for ${_money(requestedTotal)} was received. The '
              'store will verify prices and stock before confirming it.',
          'orderId': orderRef.id,
          'isRead': false,
          'createdAt': FieldValue.serverTimestamp(),
        });

        transaction.set(adminNotificationRef, {
          'recipientId': 'admin',
          'type': 'new_order_request',
          'title': 'New order request',
          'body':
              '${profile.fullName} requested $totalQuantity '
              '${totalQuantity == 1 ? 'item' : 'items'} worth '
              '${_money(requestedTotal)}. Review prices and stock.',
          'orderId': orderRef.id,
          'isRead': false,
          'createdAt': FieldValue.serverTimestamp(),
        });

        for (final ref in cartRefs) {
          transaction.delete(ref);
        }

        return OrderRequestResult(
          orderId: orderRef.id,
          requestedTotal: requestedTotal,
          itemCount: totalQuantity,
          paymentMethod: paymentMethod,
          requestReference: reference,
        );
      });
    } on DuplicateOrderFailure {
      rethrow;
    } on OrderFailure {
      rethrow;
    } on FirebaseException catch (error, stack) {
      logTechnicalError('submitOrderRequest.transaction', error, stack);
      throw OrderFailure(
        error.code == 'permission-denied'
            ? 'Your request was blocked by the current Firestore rules. Please contact the store owner.'
            : 'Your request could not be submitted. Please try again.',
      );
    } catch (error, stack) {
      logTechnicalError('submitOrderRequest.transaction', error, stack);
      throw const OrderFailure(
        'Your request could not be submitted. Your cart has not been cleared.',
      );
    }
  }

  /// Withdraws a request that the administrator has not acted on yet.
  ///
  /// The customer cannot cancel a confirmed order: stock has already been
  /// deducted and only the administrator can reverse that safely.
  Future<void> cancelRequest({
    required CustomerOrder order,
    required String reason,
  }) async {
    if (!order.canCancel) {
      throw const OrderFailure('This request can no longer be cancelled.');
    }
    final currentUid = AuthService.instance.currentUser?.uid;
    if (currentUid == null || currentUid != order.customerId) {
      throw const OrderFailure('Please sign in again to cancel this request.');
    }

    final orderRef = _orders.doc(order.id);
    final trimmedReason = reason.trim();
    try {
      await _db.runTransaction((transaction) async {
        final snapshot = await transaction.get(orderRef);
        if (!snapshot.exists) {
          throw const OrderFailure('This request could not be found.');
        }
        final data = snapshot.data() ?? <String, dynamic>{};
        if (data['customerId'] != currentUid) {
          throw const OrderFailure('This request belongs to another account.');
        }
        if (data['status'] != OrderStatuses.pendingConfirmation) {
          throw const OrderFailure(
            'The store has already reviewed this request. Contact the store '
            'to cancel a confirmed order.',
          );
        }
        final timeline = <Map<String, dynamic>>[];
        final raw = data['timeline'];
        if (raw is List) {
          for (final entry in raw) {
            if (entry is Map) timeline.add(Map<String, dynamic>.from(entry));
          }
        }
        timeline.add({
          'status': OrderStatuses.cancelled,
          'title': 'Request cancelled',
          'note': trimmedReason.isEmpty
              ? 'Cancelled by customer.'
              : trimmedReason,
          'at': Timestamp.now(),
        });
        transaction.update(orderRef, {
          'status': OrderStatuses.cancelled,
          'fulfillmentStatus': 'cancelled',
          'cancelReason': trimmedReason.isEmpty
              ? 'Cancelled by customer.'
              : trimmedReason,
          'cancelledAt': FieldValue.serverTimestamp(),
          'cancelledBy': currentUid,
          'customerTotalsApplied': false,
          'restockPending': false,
          'timeline': timeline,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      });
    } on OrderFailure {
      rethrow;
    } on FirebaseException catch (error, stack) {
      logTechnicalError('cancelRequest.transaction', error, stack);
      throw const OrderFailure(
        'This request could not be cancelled. Please contact the store.',
      );
    }

    // Best-effort administrator alert. A rules problem must not undo a
    // successful cancellation, and the deterministic id prevents duplicates.
    try {
      await _db
          .collection(AppConfig.notificationsCollection)
          .doc(NotificationIds.adminOrderCancelled(order.id))
          .set({
            'recipientId': 'admin',
            'type': 'order_cancelled',
            'title': 'Request cancelled',
            'body':
                '${order.customerName ?? 'A customer'} cancelled request '
                '${order.label}.',
            'orderId': order.id,
            'isRead': false,
            'createdAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));
    } catch (error, stack) {
      logTechnicalError('notifyAdminOrderCancelled', error, stack);
    }
  }

  String _money(int centavos) =>
      '${AppConfig.currencySymbol}${(centavos / 100).toStringAsFixed(2)}';
}

class OrderFailure implements Exception {
  const OrderFailure(this.message);

  final String message;

  @override
  String toString() => message;
}

class DuplicateOrderFailure extends OrderFailure {
  const DuplicateOrderFailure(super.message);
}
