import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/hero_banner.dart';

class HeroBannerService {
  HeroBannerService._();

  static final HeroBannerService instance = HeroBannerService._();

  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Stream<List<HeroBanner>> watchActive({int limit = 10}) {
    return _db
        .collection('hero_banners')
        .where('active', isEqualTo: true)
        .limit(limit)
        .snapshots()
        .map((snapshot) {
          final banners = snapshot.docs
              .map(HeroBanner.fromDoc)
              .where((banner) => banner.imageUrl.isNotEmpty)
              .toList();

          banners.sort((a, b) => a.order.compareTo(b.order));
          return banners;
        });
  }
}