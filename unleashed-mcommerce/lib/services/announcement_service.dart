import 'package:cloud_firestore/cloud_firestore.dart';

import '../config/app_config.dart';
import '../core/errors.dart';
import '../models/announcement.dart';

/// Public store announcements. Reads are allowed for guests through the
/// `announcements` Firestore rule; writes remain administrator-only.
class AnnouncementService {
  AnnouncementService._();

  static final AnnouncementService instance = AnnouncementService._();

  FirebaseFirestore get _db => FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _announcements =>
      _db.collection(AppConfig.announcementsCollection);

  Stream<List<Announcement>> watchActive({int limit = 6}) {
    // Sorting is done on the client so the public query needs no composite
    // index and continues to work on a fresh Firebase project.
    return _announcements
        .where('active', isEqualTo: true)
        .limit(limit)
        .snapshots()
        .map(_sort);
  }

  Future<List<Announcement>> fetchActive({int limit = 6}) async {
    final snapshot = await _announcements
        .where('active', isEqualTo: true)
        .limit(limit)
        .get();
    return _sort(snapshot);
  }

  List<Announcement> _sort(QuerySnapshot<Map<String, dynamic>> snapshot) {
    final list = snapshot.docs.map(Announcement.fromDoc).toList();
    list.sort((a, b) {
      if (a.pinned != b.pinned) return a.pinned ? -1 : 1;
      final aTime = a.createdAt?.millisecondsSinceEpoch ?? 0;
      final bTime = b.createdAt?.millisecondsSinceEpoch ?? 0;
      return bTime.compareTo(aTime);
    });
    return list;
  }

  Future<void> save(Announcement announcement) async {
    try {
      if (announcement.id.isEmpty) {
        await _announcements.add({
          ...announcement.toMap(),
          'createdAt': FieldValue.serverTimestamp(),
        });
      } else {
        await _announcements.doc(announcement.id).set(
          announcement.toMap(),
          SetOptions(merge: true),
        );
      }
    } catch (error, stack) {
      logTechnicalError('announcement.save', error, stack);
      rethrow;
    }
  }

  Future<void> delete(String id) async {
    await _announcements.doc(id).delete();
  }
}
