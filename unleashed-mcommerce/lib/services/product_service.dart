import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../config/app_config.dart';
import '../core/errors.dart';
import '../models/product.dart';
import '../models/product_review.dart';

class StoreSettings {
  const StoreSettings({
    this.storeName = AppConfig.storeName,
    this.contactEmail = '',
    this.contactNumber = '',
    this.shippingFee = 0,
    this.freeShippingThreshold,
    this.processingNotice =
        'Orders are prepared within 3–5 working days before shipment.',
  });

  final String storeName;
  final String contactEmail;
  final String contactNumber;
  final int shippingFee;
  final int? freeShippingThreshold;
  final String processingNotice;

  factory StoreSettings.fromMap(Map<String, dynamic>? data) {
    data ??= <String, dynamic>{};
    final rawFee = data['shippingFee'] ?? data['deliveryFee'];
    final rawThreshold =
        data['freeShippingThreshold'] ?? data['freeShippingMinimum'];
    return StoreSettings(
      storeName: (data['storeName'] ?? AppConfig.storeName).toString(),
      contactEmail: (data['contactEmail'] ?? '').toString(),
      contactNumber: (data['contactNumber'] ?? '').toString(),
      shippingFee: (rawFee as num?)?.toInt() ?? 0,
      freeShippingThreshold: (rawThreshold as num?)?.toInt(),
      processingNotice:
          (data['processingNotice'] ?? data['processingDaysText'] ?? '')
                  .toString()
                  .trim()
                  .isEmpty
              ? 'Orders are prepared within 3–5 working days before shipment.'
              : (data['processingNotice'] ?? data['processingDaysText'])
                    .toString(),
    );
  }
}

class ProductService {
  ProductService._();

  static final ProductService instance = ProductService._();

  final Map<String, Uint8List?> _imageCache = {};
  final Map<String, StoreSettings> _settingsCache = {};

  FirebaseFirestore get _db => FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _products =>
      _db.collection(AppConfig.productsCollection);

  Stream<List<Product>> watchActiveProducts() {
    return _products.where('status', isEqualTo: 'active').snapshots().map((
      snapshot,
    ) {
      final list = snapshot.docs
          .map(Product.fromDoc)
          .where((product) => product.isActive)
          .toList();
      list.sort(
        (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
      );
      return list;
    });
  }

  Future<List<Product>> fetchActiveProducts() async {
    final snapshot = await _products
        .where('status', isEqualTo: 'active')
        .get();
    final list = snapshot.docs
        .map(Product.fromDoc)
        .where((product) => product.isActive)
        .toList();
    list.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    return list;
  }

  Stream<Product?> watchProduct(String productId) {
    return _products.doc(productId).snapshots().map((doc) {
      if (!doc.exists) return null;
      return Product.fromDoc(doc);
    });
  }

  Future<Product?> fetchProduct(String productId) async {
    final doc = await _products.doc(productId).get();
    if (!doc.exists) return null;
    return Product.fromDoc(doc);
  }

  /// Product images are stored as bytes in Firestore for the current Spark
  /// plan. They are cached for the lifetime of the process so scrolling the
  /// grid does not re-read the same document.
  Future<Uint8List?> loadProductImage(String? imageId) async {
    if (imageId == null || imageId.isEmpty) return null;
    if (_imageCache.containsKey(imageId)) return _imageCache[imageId];
    try {
      final doc = await _db
          .collection(AppConfig.productImagesCollection)
          .doc(imageId)
          .get();
      if (!doc.exists) {
        _imageCache[imageId] = null;
        return null;
      }
      final raw = doc.data()?['bytes'];
      Uint8List? bytes;
      if (raw is Blob) bytes = raw.bytes;
      if (raw is Uint8List) bytes = raw;
      if (raw is List<int>) bytes = Uint8List.fromList(raw);
      if (bytes != null && bytes.isEmpty) bytes = null;
      _imageCache[imageId] = bytes;
      return bytes;
    } catch (error, stack) {
      logTechnicalError('loadProductImage', error, stack);
      return null;
    }
  }

  void invalidateImage(String? imageId) {
    if (imageId != null) _imageCache.remove(imageId);
  }

  Future<StoreSettings> loadStoreSettings({bool force = false}) async {
    if (!force && _settingsCache.containsKey('store')) {
      return _settingsCache['store']!;
    }
    try {
      final doc = await _db
          .collection(AppConfig.settingsCollection)
          .doc(AppConfig.storeSettingsDoc)
          .get();
      final settings = StoreSettings.fromMap(doc.data());
      _settingsCache['store'] = settings;
      return settings;
    } catch (error, stack) {
      logTechnicalError('loadStoreSettings', error, stack);
      const fallback = StoreSettings();
      _settingsCache['store'] = fallback;
      return fallback;
    }
  }

  Stream<List<ProductReview>> watchReviews(String productId) {
    return _db
        .collection(AppConfig.reviewsCollection)
        .where('productId', isEqualTo: productId)
        .snapshots()
        .map((snapshot) {
          final reviews = snapshot.docs.map(ProductReview.fromDoc).toList();
          reviews.sort((a, b) {
            final aTime = a.createdAt?.millisecondsSinceEpoch ?? 0;
            final bTime = b.createdAt?.millisecondsSinceEpoch ?? 0;
            return bTime.compareTo(aTime);
          });
          return reviews;
        });
  }

  Future<List<ProductReview>> fetchReviews(String productId) async {
    final snapshot = await _db
        .collection(AppConfig.reviewsCollection)
        .where('productId', isEqualTo: productId)
        .get();
    final reviews = snapshot.docs.map(ProductReview.fromDoc).toList();
    reviews.sort((a, b) {
      final aTime = a.createdAt?.millisecondsSinceEpoch ?? 0;
      final bTime = b.createdAt?.millisecondsSinceEpoch ?? 0;
      return bTime.compareTo(aTime);
    });
    return reviews;
  }
}
