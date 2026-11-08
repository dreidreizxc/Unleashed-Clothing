import 'package:cloud_firestore/cloud_firestore.dart';

import '../config/app_config.dart';
import '../core/errors.dart';
import '../models/app_notification.dart';

/// In-app notifications only. The app does not claim push delivery: every
/// notification is a Firestore document read in real time while the customer
/// is signed in.
class NotificationService {
  NotificationService._();

  static final NotificationService instance = NotificationService._();

  FirebaseFirestore get _db => FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _collection =>
      _db.collection(AppConfig.notificationsCollection);

  Stream<List<AppNotification>> watchFor(String uid) {
    if (uid.isEmpty) return const Stream<List<AppNotification>>.empty();
    return _collection
        .where('recipientId', isEqualTo: uid)
        .limit(100)
        .snapshots()
        .map((snapshot) {
          final list = snapshot.docs
              .map(AppNotification.fromDoc)
              // Defense in depth: even if a query or rule regresses, the app
              // never renders an alert addressed to another account.
              .where((notification) => notification.recipientId == uid)
              .toList();
          list.sort((a, b) {
            final aTime = a.createdAt?.millisecondsSinceEpoch ?? 0;
            final bTime = b.createdAt?.millisecondsSinceEpoch ?? 0;
            return bTime.compareTo(aTime);
          });
          return list;
        })
        .handleError((Object error, StackTrace stack) {
          logTechnicalError('watchNotifications', error, stack);
          throw error;
        });
  }

  Stream<int> watchUnreadCount(String uid) {
    if (uid.isEmpty) return Stream<int>.value(0);
    return _collection
        .where('recipientId', isEqualTo: uid)
        .where('isRead', isEqualTo: false)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .where((doc) => doc.data()['recipientId'] == uid)
              .length,
        )
        .handleError((Object error, StackTrace stack) {
          logTechnicalError('watchUnreadNotifications', error, stack);
          return 0;
        });
  }

  Future<void> markRead(String uid, String notificationId) async {
    try {
      await _collection.doc(notificationId).update({
        'isRead': true,
        'readAt': FieldValue.serverTimestamp(),
      });
    } catch (error, stack) {
      logTechnicalError('markNotificationRead', error, stack);
    }
  }

  Future<void> markAllRead(String uid) async {
    final snapshot = await _collection
        .where('recipientId', isEqualTo: uid)
        .where('isRead', isEqualTo: false)
        .get();
    if (snapshot.docs.isEmpty) return;
    final batch = _db.batch();
    for (final doc in snapshot.docs) {
      batch.update(doc.reference, {
        'isRead': true,
        'readAt': FieldValue.serverTimestamp(),
      });
    }
    await batch.commit();
  }

  Future<void> delete(String uid, String notificationId) async {
    await _collection.doc(notificationId).delete();
  }
}
