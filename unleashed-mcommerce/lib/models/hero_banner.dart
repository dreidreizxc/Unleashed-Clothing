import 'package:cloud_firestore/cloud_firestore.dart';

class HeroBanner {
  const HeroBanner({
    required this.id,
    required this.imageUrl,
    required this.active,
    required this.order,
    this.headline = '',
    this.caption = '',
  });

  final String id;
  final String imageUrl;
  final bool active;
  final int order;
  final String headline;
  final String caption;

  factory HeroBanner.fromDoc(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? <String, dynamic>{};

    return HeroBanner(
      id: doc.id,
      imageUrl: (data['imageUrl'] ?? '').toString().trim(),
      active: data['active'] as bool? ?? true,
      order: (data['order'] as num?)?.toInt() ?? 0,
      headline: (data['headline'] ?? '').toString().trim(),
      caption: (data['caption'] ?? '').toString().trim(),
    );
  }
}