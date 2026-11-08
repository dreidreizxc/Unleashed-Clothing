import 'package:cloud_firestore/cloud_firestore.dart';

import '../config/app_config.dart';
import '../core/errors.dart';
import '../core/validators.dart';
import '../models/order.dart';
import '../models/product_review.dart';

class ReviewService {
  ReviewService._();

  static final ReviewService instance = ReviewService._();

  FirebaseFirestore get _db => FirebaseFirestore.instance;

  /// Finds a delivered order that contains [productId]. Reviews are only
  /// allowed against a completed purchase, and that is re-checked by
  /// Firestore rules on write.
  Future<CustomerOrder?> eligibleOrderForProduct({
    required String customerId,
    required String productId,
  }) async {
    final snapshot = await _db
        .collection(AppConfig.ordersCollection)
        .where('customerId', isEqualTo: customerId)
        .where('status', isEqualTo: 'delivered')
        .get();
    final orders = snapshot.docs.map(CustomerOrder.fromDoc).toList();
    orders.sort((a, b) {
      final aTime = a.createdAt?.millisecondsSinceEpoch ?? 0;
      final bTime = b.createdAt?.millisecondsSinceEpoch ?? 0;
      return bTime.compareTo(aTime);
    });
    for (final order in orders) {
      if (order.items.any((item) => item.productId == productId)) {
        return order;
      }
    }
    return null;
  }

  Future<void> submitReview({
  required String customerId,
  required String customerName,
  required String productId,
  required String orderId,
  required int rating,
  required String text,
}) async {
  if (rating < 1 || rating > 5) {
    throw const ReviewFailure('Choose a rating between 1 and 5 stars.');
  }

  final textError = Validators.reviewText(text);
  if (textError != null) throw ReviewFailure(textError);

  final id = ProductReview.idFor(productId, customerId);
  final ref = _db.collection(AppConfig.reviewsCollection).doc(id);

  try {
    final existing = await ref.get();
    final batch = _db.batch();

    batch.set(ref, {
      'productId': productId,
      'customerId': customerId,
      'customerName': customerName,
      'orderId': orderId,
      'rating': rating,
      'text': text.trim(),
      'createdAt': existing.exists
          ? (existing.data()?['createdAt'] ?? FieldValue.serverTimestamp())
          : FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    // Notify the admin only when a customer submits a new review.
    if (!existing.exists) {
      final notificationRef = _db.collection('notifications').doc();

      batch.set(notificationRef, {
        'recipientId': 'admin',
        'type': 'new_review',
        'title': 'New Customer Review',
        'body': '$customerName submitted a $rating-star review.',
                'customerId': customerId,
        'orderId': orderId,
        'reviewId': id,
        'productId': productId,
        'rating': rating,
        'isRead': false,
        'createdAt': FieldValue.serverTimestamp(),
      });
    }

    await batch.commit();
  } catch (error, stack) {
    logTechnicalError('submitReview', error, stack);
    throw const ReviewFailure(
      'Could not save your review. A completed delivery is required for each product.',
    );
  }
}
}

class ReviewFailure implements Exception {
  const ReviewFailure(this.message);

  final String message;

  @override
  String toString() => message;
}
