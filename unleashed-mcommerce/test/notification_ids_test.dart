import 'package:flutter_test/flutter_test.dart';
import 'package:unleashed_mcommerce/core/notification_ids.dart';

void main() {
  group('Administrator notification ids', () {
    test('are deterministic for the same event', () {
      expect(
        NotificationIds.adminNewOrder('order-123'),
        NotificationIds.adminNewOrder('order-123'),
      );
      expect(
        NotificationIds.adminOrderCancelled('order-123'),
        NotificationIds.adminOrderCancelled('order-123'),
      );
      expect(
        NotificationIds.adminChatMessage('message-123'),
        NotificationIds.adminChatMessage('message-123'),
      );
    });

    test('separate event types so they cannot overwrite each other', () {
      const eventId = 'event-123';
      final ids = {
        NotificationIds.adminNewOrder(eventId),
        NotificationIds.adminOrderCancelled(eventId),
        NotificationIds.adminChatMessage(eventId),
      };

      expect(ids, hasLength(3));
    });

    test('keep the Firestore-safe prefixes administrators rely on', () {
      expect(NotificationIds.adminNewOrder('abc'), 'admin_new_order_abc');
      expect(
        NotificationIds.adminOrderCancelled('abc'),
        'admin_order_cancelled_abc',
      );
      expect(NotificationIds.adminChatMessage('abc'), 'admin_chat_abc');
    });
  });

  group('Customer notification ids', () {
    test('are deterministic for the same event', () {
      expect(
        NotificationIds.customerOrderRequested('order-123'),
        NotificationIds.customerOrderRequested('order-123'),
      );
      expect(
        NotificationIds.customerOrderRejected('order-123'),
        NotificationIds.customerOrderRejected('order-123'),
      );
      expect(
        NotificationIds.customerOrderStatus('order-123', 'shipped'),
        NotificationIds.customerOrderStatus('order-123', 'shipped'),
      );
      expect(
        NotificationIds.customerChatReply('message-123'),
        NotificationIds.customerChatReply('message-123'),
      );
    });

    test(
      'separate each order status so updates cannot overwrite each other',
      () {
        const orderId = 'order-123';
        final ids = {
          NotificationIds.customerOrderStatus(orderId, 'confirmed'),
          NotificationIds.customerOrderStatus(orderId, 'processing'),
          NotificationIds.customerOrderStatus(orderId, 'shipped'),
          NotificationIds.customerOrderStatus(orderId, 'delivered'),
        };

        expect(ids, hasLength(4));
      },
    );

    test('do not collide with administrator alerts', () {
      const eventId = 'event-123';
      final adminIds = {
        NotificationIds.adminNewOrder(eventId),
        NotificationIds.adminOrderCancelled(eventId),
        NotificationIds.adminChatMessage(eventId),
      };
      final customerIds = {
        NotificationIds.customerOrderRequested(eventId),
        NotificationIds.customerOrderRejected(eventId),
        NotificationIds.customerOrderStatus(eventId, 'cancelled'),
        NotificationIds.customerChatReply(eventId),
      };

      expect(adminIds.intersection(customerIds), isEmpty);
    });

    test('keep the ids Cloud Functions and the dashboard share', () {
      expect(
        NotificationIds.customerOrderRequested('abc'),
        'customer_order_abc_pending_confirmation',
      );
      expect(
        NotificationIds.customerOrderRejected('abc'),
        'customer_order_abc_rejected',
      );
      expect(
        NotificationIds.customerOrderStatus('abc', 'shipped'),
        'customer_order_abc_shipped',
      );
      expect(NotificationIds.customerChatReply('abc'), 'customer_chat_abc');
    });
  });
}
