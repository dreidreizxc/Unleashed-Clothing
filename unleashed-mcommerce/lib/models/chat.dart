import 'package:cloud_firestore/cloud_firestore.dart';

class ChatMessage {
  const ChatMessage({
    required this.id,
    required this.senderId,
    required this.senderRole,
    required this.text,
    required this.isRead,
    this.createdAt,
  });

  final String id;
  final String senderId;
  final String senderRole;
  final String text;
  final bool isRead;
  final Timestamp? createdAt;

  bool get fromAdmin => senderRole == 'admin';

  factory ChatMessage.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? <String, dynamic>{};
    return ChatMessage(
      id: doc.id,
      senderId: (data['senderId'] ?? '').toString(),
      senderRole: (data['senderRole'] ?? 'customer').toString(),
      text: (data['text'] ?? '').toString(),
      isRead: data['isRead'] as bool? ?? false,
      createdAt: data['createdAt'] is Timestamp
          ? data['createdAt'] as Timestamp
          : null,
    );
  }
}

class CustomerChat {
  const CustomerChat({
    required this.customerId,
    required this.customerName,
    required this.lastMessage,
    required this.unreadByAdmin,
    required this.unreadByCustomer,
    this.lastMessageAt,
  });

  final String customerId;
  final String customerName;
  final String lastMessage;
  final int unreadByAdmin;
  final int unreadByCustomer;
  final Timestamp? lastMessageAt;

  factory CustomerChat.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? <String, dynamic>{};
    return CustomerChat(
      customerId: (data['customerId'] ?? doc.id).toString(),
      customerName: (data['customerName'] ?? 'Customer').toString(),
      lastMessage: (data['lastMessage'] ?? '').toString(),
      unreadByAdmin: (data['unreadByAdmin'] as num?)?.toInt() ?? 0,
      unreadByCustomer: (data['unreadByCustomer'] as num?)?.toInt() ?? 0,
      lastMessageAt: data['lastMessageAt'] is Timestamp
          ? data['lastMessageAt'] as Timestamp
          : null,
    );
  }
}
