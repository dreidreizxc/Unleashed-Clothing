import 'package:cloud_firestore/cloud_firestore.dart';

class ProductReview {
  const ProductReview({
    required this.id,
    required this.productId,
    required this.customerId,
    required this.rating,
    required this.text,
    this.orderId,
    this.customerName,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String productId;
  final String customerId;
  final int rating;
  final String text;
  final String? orderId;
  final String? customerName;
  final Timestamp? createdAt;
  final Timestamp? updatedAt;

  factory ProductReview.fromDoc(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? <String, dynamic>{};
    return ProductReview(
      id: doc.id,
      productId: (data['productId'] ?? '').toString(),
      customerId: (data['customerId'] ?? '').toString(),
      rating: ((data['rating'] as num?)?.toInt() ?? 0).clamp(0, 5),
      text: (data['text'] ?? '').toString(),
      orderId: data['orderId']?.toString(),
      customerName: data['customerName']?.toString(),
      createdAt: data['createdAt'] is Timestamp
          ? data['createdAt'] as Timestamp
          : null,
      updatedAt: data['updatedAt'] is Timestamp
          ? data['updatedAt'] as Timestamp
          : null,
    );
  }

  static String idFor(String productId, String customerId) =>
      '${productId}_$customerId';
}
