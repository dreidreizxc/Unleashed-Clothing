/// Deterministic document ids for in-app notifications.
///
/// Reusing the same event id means a retried write updates the same document
/// instead of creating a duplicate alert. The prefix also keeps administrator
/// alerts distinct from customer notifications written by the admin dashboard
/// or a trusted backend.
class NotificationIds {
  NotificationIds._();

  /// Administrator alert for a newly submitted order request.
  static String adminNewOrder(String orderId) => 'admin_new_order_$orderId';

  /// Administrator alert when a customer withdraws a pending request.
  static String adminOrderCancelled(String orderId) =>
      'admin_order_cancelled_$orderId';

  static String adminChatMessage(String messageId) => 'admin_chat_$messageId';

  /// One customer alert per order status, so replayed writes cannot duplicate
  /// an update.
  static String customerOrderStatus(String orderId, String status) =>
      'customer_order_${orderId}_$status';

  /// Customer acknowledgement that the request was received. This is distinct
  /// from the administrator's later confirmation so both can coexist.
  static String customerOrderRequested(String orderId) =>
      customerOrderStatus(orderId, 'pending_confirmation');

  static String customerOrderRejected(String orderId) =>
      customerOrderStatus(orderId, 'rejected');

  static String customerChatReply(String messageId) =>
      'customer_chat_$messageId';
}
