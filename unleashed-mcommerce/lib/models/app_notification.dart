import 'package:cloud_firestore/cloud_firestore.dart';

class AppNotification {
  const AppNotification({
    required this.id,
    required this.recipientId,
    required this.type,
    required this.title,
    required this.body,
    required this.isRead,
    this.orderId,
    this.chatId,
    this.createdAt,
  });

  final String id;
  final String recipientId;
  final String type;
  final String title;
  final String body;
  final String? orderId;
  final String? chatId;
  final bool isRead;
  final Timestamp? createdAt;

  factory AppNotification.fromDoc(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? <String, dynamic>{};
    return AppNotification(
      id: doc.id,
      recipientId: (data['recipientId'] ?? '').toString(),
      type: (data['type'] ?? 'general').toString(),
      title: (data['title'] ?? 'Notification').toString(),
      body: (data['body'] ?? '').toString(),
      orderId: data['orderId']?.toString(),
      chatId: data['chatId']?.toString(),
      isRead: data['isRead'] as bool? ?? false,
      createdAt: data['createdAt'] is Timestamp
          ? data['createdAt'] as Timestamp
          : null,
    );
  }
}
