import 'package:cloud_firestore/cloud_firestore.dart';

import '../config/app_config.dart';
import '../core/errors.dart';
import '../core/notification_ids.dart';
import '../models/chat.dart';

/// Customer <-> store messaging. One conversation per customer, stored at
/// `chats/{uid}` with messages in `chats/{uid}/messages`.
class ChatService {
  ChatService._();

  static final ChatService instance = ChatService._();

  static const int maxMessageLength = 2000;

  FirebaseFirestore get _db => FirebaseFirestore.instance;

  DocumentReference<Map<String, dynamic>> chatRef(String uid) =>
      _db.collection(AppConfig.chatsCollection).doc(uid);

  CollectionReference<Map<String, dynamic>> messagesRef(String uid) =>
      chatRef(uid).collection('messages');

  Stream<CustomerChat?> watchChat(String uid) {
    return chatRef(uid).snapshots().map((doc) {
      if (!doc.exists) return null;
      return CustomerChat.fromDoc(doc);
    });
  }

  Stream<List<ChatMessage>> watchMessages(String uid) {
    return messagesRef(uid)
        .limit(200)
        .snapshots()
        .map((snapshot) {
          final list = snapshot.docs.map(ChatMessage.fromDoc).toList();
          list.sort((a, b) {
            final aTime = a.createdAt?.millisecondsSinceEpoch ?? 0;
            final bTime = b.createdAt?.millisecondsSinceEpoch ?? 0;
            return aTime.compareTo(bTime);
          });
          return list;
        })
        .handleError((Object error, StackTrace stack) {
          logTechnicalError('watchMessages', error, stack);
          throw error;
        });
  }

  Future<void> sendMessage({
    required String uid,
    required String customerName,
    required String text,
  }) async {
    final message = text.trim();
    if (message.isEmpty) {
      throw const ChatFailure('Type a message before sending.');
    }
    if (message.length > maxMessageLength) {
      throw const ChatFailure('Messages must be 2,000 characters or fewer.');
    }
    final chat = chatRef(uid);
    final messageRef = messagesRef(uid).doc();
    try {
      await _db.runTransaction((transaction) async {
        final chatSnapshot = await transaction.get(chat);
        final data = chatSnapshot.data() ?? <String, dynamic>{};
        transaction.set(messageRef, {
          'senderId': uid,
          'senderRole': 'customer',
          'text': message,
          'isRead': false,
          'createdAt': FieldValue.serverTimestamp(),
        });
        transaction.set(chat, {
          'customerId': uid,
          'customerName': customerName,
          'lastMessage': message,
          'lastMessageAt': FieldValue.serverTimestamp(),
          'lastSenderRole': 'customer',
          'unreadByAdmin': ((data['unreadByAdmin'] as num?)?.toInt() ?? 0) + 1,
          'unreadByCustomer': 0,
          'createdAt': data['createdAt'] ?? FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      });

      // Best-effort administrator alert. The deterministic document id makes
      // the write idempotent, and a rules problem must not block the message.
      try {
        final preview = message.runes.take(120).map(String.fromCharCode).join();
        await _db
            .collection(AppConfig.notificationsCollection)
            .doc(NotificationIds.adminChatMessage(messageRef.id))
            .set({
              'recipientId': 'admin',
              'type': 'chat_message',
              'title': 'New customer message',
              'body': preview,
              'customerId': uid,
              'chatId': uid,
              'isRead': false,
              'createdAt': FieldValue.serverTimestamp(),
            }, SetOptions(merge: true));
      } catch (error, stack) {
        logTechnicalError('notifyAdminChatMessage', error, stack);
      }
    } on FirebaseException catch (error, stack) {
      logTechnicalError('sendMessage', error, stack);
      throw ChatFailure(
        error.code == 'permission-denied'
            ? 'Messaging is not available with the current store rules.'
            : 'Your message could not be sent. Please try again.',
      );
    }
  }

  /// Marks every admin message in the conversation as read. Failures are not
  /// surfaced to the customer: the badge will simply refresh on the next load.
  Future<void> markCustomerMessagesRead(String uid) async {
    try {
      final snapshot = await messagesRef(uid)
          .where('senderRole', isEqualTo: 'admin')
          .where('isRead', isEqualTo: false)
          .get();
      if (snapshot.docs.isEmpty) return;
      final batch = _db.batch();
      for (final doc in snapshot.docs) {
        batch.update(doc.reference, {'isRead': true});
      }
      batch.set(chatRef(uid), {
        'unreadByCustomer': 0,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      await batch.commit();
    } catch (error, stack) {
      logTechnicalError('markCustomerMessagesRead', error, stack);
    }
  }
}

class ChatFailure implements Exception {
  const ChatFailure(this.message);

  final String message;

  @override
  String toString() => message;
}
