import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:unleashed_mcommerce/models/order.dart';

void main() {
  CustomerOrder order({
    String status = 'pending_confirmation',
    List<OrderTimelineEvent> timeline = const [],
    Timestamp? createdAt,
  }) {
    return CustomerOrder(
      id: 'order-1',
      customerId: 'uid-1',
      items: const [],
      total: 150000,
      paymentMethod: 'COD',
      paymentStatus: 'unpaid',
      status: status,
      createdAt: createdAt,
      timeline: timeline,
    );
  }

  group('OrderTimelineEvent', () {
    test('parses status, title, note, and timestamp', () {
      final at = Timestamp.fromDate(DateTime.utc(2026, 5, 1, 9, 30));
      final event = OrderTimelineEvent.fromMap({
        'status': 'shipped',
        'title': 'Order shipped',
        'note': 'Handed to the courier.',
        'at': at,
      });

      expect(event.status, 'shipped');
      expect(event.title, 'Order shipped');
      expect(event.note, 'Handed to the courier.');
      expect(event.at?.toUtc(), DateTime.utc(2026, 5, 1, 9, 30));
    });

    test('falls back to createdAt when at is missing', () {
      final createdAt = Timestamp.fromDate(DateTime.utc(2026, 4, 20));
      final event = OrderTimelineEvent.fromMap({
        'status': 'placed',
        'title': 'Order placed',
        'createdAt': createdAt,
      });

      expect(event.at?.toUtc(), DateTime.utc(2026, 4, 20));
      expect(event.note, isNull);
    });

    test('toMap stamps a fresh timestamp', () {
      final before = DateTime.now().subtract(const Duration(seconds: 1));
      final event = const OrderTimelineEvent(
        status: 'processing',
        title: 'Preparing your order',
        at: null,
        note: 'Being packed.',
      );

      final map = event.toMap();
      final stamped = map['at'] as Timestamp;

      expect(map['status'], 'processing');
      expect(map['title'], 'Preparing your order');
      expect(map['note'], 'Being packed.');
      expect(stamped.toDate().isAfter(before), isTrue);
    });
  });

  group('CustomerOrder timeline', () {
    test('uses stored timeline entries when present', () {
      final timeline = [
        OrderTimelineEvent(
          status: 'placed',
          title: 'Order placed',
          at: DateTime.utc(2026, 5, 1),
        ),
        OrderTimelineEvent(
          status: 'cancelled',
          title: 'Order cancelled',
          at: DateTime.utc(2026, 5, 2),
          note: 'Out of stock.',
        ),
      ];

      final result = order(status: 'cancelled', timeline: timeline);

      expect(result.effectiveTimeline, hasLength(2));
      expect(result.effectiveTimeline.last.status, 'cancelled');
      expect(result.effectiveTimeline.last.note, 'Out of stock.');
    });

    test('synthesizes a request event when timeline is empty', () {
      final createdAt = Timestamp.fromDate(DateTime.utc(2026, 5, 3, 8));
      final result = order(createdAt: createdAt);

      expect(result.effectiveTimeline, hasLength(1));
      expect(result.effectiveTimeline.single.status, 'pending_confirmation');
      expect(result.effectiveTimeline.single.title, 'Request submitted');
      expect(
        result.effectiveTimeline.single.at?.toUtc(),
        DateTime.utc(2026, 5, 3, 8),
      );
    });

    test('only pending requests can be cancelled by the customer', () {
      expect(order(status: 'pending_confirmation').canCancel, isTrue);
      expect(order(status: 'placed').canCancel, isFalse);
      expect(order(status: 'confirmed').canCancel, isFalse);
      expect(order(status: 'rejected').canCancel, isFalse);
      expect(order(status: 'shipped').canCancel, isFalse);
      expect(order(status: 'cancelled').canCancel, isFalse);
    });
  });
}
