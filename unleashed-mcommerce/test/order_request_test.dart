import 'package:flutter_test/flutter_test.dart';
import 'package:unleashed_mcommerce/models/order.dart';

void main() {
  const requestedItem = OrderItem(
    productId: 'tee-1',
    name: 'Oversized Tee',
    size: 'M',
    price: 94900,
    quantity: 2,
  );

  CustomerOrder request({
    String status = OrderStatuses.pendingConfirmation,
    String? orderNumber,
    bool totalsVerified = false,
    int? requestedSubtotal,
    int? requestedShippingFee,
    int? requestedTotal,
    int total = 189800,
    String? rejectionReason,
  }) {
    return CustomerOrder(
      id: 'request-1',
      orderNumber: orderNumber,
      customerId: 'uid-1',
      items: const [requestedItem],
      requestedItems: const [requestedItem],
      requestedSubtotal: requestedSubtotal,
      requestedShippingFee: requestedShippingFee,
      requestedTotal: requestedTotal,
      subtotal: requestedSubtotal,
      shippingFee: requestedShippingFee ?? 0,
      total: total,
      totalsVerified: totalsVerified,
      paymentMethod: 'COD',
      paymentStatus: 'unpaid',
      status: status,
      rejectionReason: rejectionReason,
      createdAt: null,
    );
  }

  group('Order request model', () {
    test('a pending request is cancellable and keeps unverified totals', () {
      final order = request();

      expect(order.isPendingRequest, isTrue);
      expect(order.canCancel, isTrue);
      expect(order.hasOrderNumber, isFalse);
      expect(order.totalsVerified, isFalse);
      expect(order.effectiveRequestedItems, hasLength(1));
      expect(order.requestedSubtotalValue, 189800);
      expect(order.requestedTotalValue, 189800);
      expect(order.payableTotal, 189800);
      expect(order.label, startsWith('#'));
    });

    test('a confirmed order uses verified totals and cannot be cancelled', () {
      final order = request(
        status: OrderStatuses.confirmed,
        orderNumber: 'UND-000123',
        totalsVerified: true,
        requestedSubtotal: 189800,
        requestedShippingFee: 5000,
        requestedTotal: 194800,
        total: 199800,
      );

      expect(order.isConfirmed, isTrue);
      expect(order.canCancel, isFalse);
      expect(order.hasOrderNumber, isTrue);
      expect(order.label, 'UND-000123');
      expect(order.requestedTotalValue, 194800);
      expect(order.payableTotal, 199800);
      expect(order.isCompleted, isFalse);
    });

    test('a rejected request is closed and keeps the reason', () {
      final order = request(
        status: OrderStatuses.rejected,
        rejectionReason: 'Out of stock.',
      );

      expect(order.isRejected, isTrue);
      expect(order.canCancel, isFalse);
      expect(order.isCompleted, isTrue);
      expect(order.rejectionReason, 'Out of stock.');
    });

    test('a cancelled request is closed and cannot be cancelled again', () {
      final order = request(status: OrderStatuses.cancelled);

      expect(order.isCancelled, isTrue);
      expect(order.canCancel, isFalse);
      expect(order.isCompleted, isTrue);
    });
  });
}
