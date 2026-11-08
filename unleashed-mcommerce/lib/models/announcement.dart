import 'package:cloud_firestore/cloud_firestore.dart';

import '../core/formatters.dart';

/// A public store announcement shown on the customer home screen.
///
/// The `announcements` collection is readable by guests when `active` is true
/// and writable only by administrators.
class Announcement {
  const Announcement({
    required this.id,
    required this.title,
    required this.body,
    required this.active,
    required this.pinned,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String title;
  final String body;
  final bool active;
  final bool pinned;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  factory Announcement.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    return Announcement.fromMap(doc.data() ?? <String, dynamic>{}, id: doc.id);
  }

  factory Announcement.fromMap(
    Map<String, dynamic> data, {
    String id = '',
  }) {
    return Announcement(
      id: id,
      title: (data['title'] ?? '').toString().trim(),
      body: (data['body'] ?? data['message'] ?? '').toString().trim(),
      active: data['active'] as bool? ?? true,
      pinned: data['pinned'] as bool? ?? false,
      createdAt: asDate(data['createdAt']),
      updatedAt: asDate(data['updatedAt']),
    );
  }

  Map<String, dynamic> toMap() => {
    'title': title.trim(),
    'body': body.trim(),
    'active': active,
    'pinned': pinned,
    'updatedAt': FieldValue.serverTimestamp(),
  };
}
