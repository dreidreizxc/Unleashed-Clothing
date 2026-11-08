import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../config/app_config.dart';
import '../models/cart_item.dart';
import '../models/product.dart';

class CartService {
  CartService._();

  static final CartService instance = CartService._();

  FirebaseFirestore get _db => FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> itemsRef(String uid) =>
      _db.collection(AppConfig.cartsCollection).doc(uid).collection('items');

  Stream<List<CartItem>> watchCart(String uid) {
    return itemsRef(uid).snapshots().map((snapshot) {
      final items = snapshot.docs.map(CartItem.fromDoc).toList();
      items.sort((a, b) {
        final aTime = a.addedAt?.millisecondsSinceEpoch ?? 0;
        final bTime = b.addedAt?.millisecondsSinceEpoch ?? 0;
        return aTime.compareTo(bTime);
      });
      return items;
    });
  }

  Future<List<CartItem>> fetchCart(String uid) async {
    final snapshot = await itemsRef(uid).get();
    return snapshot.docs.map(CartItem.fromDoc).toList();
  }

  static String itemIdFor(String productId, String size) =>
      '${productId}_${size.replaceAll(RegExp(r'[^A-Za-z0-9]'), '')}';

  Future<int> addToCart({
    required String uid,
    required Product product,
    required String size,
    required int quantity,
  }) async {
    if (quantity < 1) {
      throw const CartFailure('Choose at least one item.');
    }
    if (!product.availableSizes.contains(size)) {
      throw const CartFailure('That size is no longer available.');
    }
    final id = itemIdFor(product.id, size);
    final itemRef = itemsRef(uid).doc(id);

    return _db.runTransaction<int>((transaction) async {
      final productRef = _db
          .collection(AppConfig.productsCollection)
          .doc(product.id);
      final productSnapshot = await transaction.get(productRef);
      final itemSnapshot = await transaction.get(itemRef);
      if (!productSnapshot.exists) {
        throw const CartFailure('This product is no longer available.');
      }
      final current = Product.fromDoc(productSnapshot);
      if (!current.isActive) {
        throw const CartFailure('This product is not available right now.');
      }
      final available = current.stockFor(size);
      if (available <= 0) {
        throw const CartFailure('This size is out of stock.');
      }
      final existingQty = itemSnapshot.exists
          ? (itemSnapshot.data()?['quantity'] as num?)?.toInt() ?? 0
          : 0;
      final nextQty = existingQty + quantity;
      if (nextQty > available) {
        throw CartFailure(
          'Only $available item${available == 1 ? '' : 's'} left in size $size.',
        );
      }
      if (nextQty > AppConfig.maxCartQuantity) {
        throw const CartFailure(
          'You have reached the maximum quantity for this item.',
        );
      }

      transaction.set(itemRef, {
        'productId': current.id,
        'name': current.name,
        'size': size,
        'price': current.price,
        'quantity': nextQty,
        'imageId': current.imageId,
        'category': current.category,
        'addedAt': itemSnapshot.exists
            ? (itemSnapshot.data()?['addedAt'] ?? FieldValue.serverTimestamp())
            : FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      return nextQty;
    });
  }

  Future<void> setQuantity({
    required String uid,
    required CartItem item,
    required int quantity,
  }) async {
    if (quantity < 1) {
      await removeItem(uid: uid, itemId: item.id);
      return;
    }
    final productSnapshot = await _db
        .collection(AppConfig.productsCollection)
        .doc(item.productId)
        .get();
    if (!productSnapshot.exists) {
      throw const CartFailure('This product is no longer available.');
    }
    final product = Product.fromDoc(productSnapshot);
    final available = product.stockFor(item.size);
    if (quantity > available) {
      throw CartFailure(
        'Only $available item${available == 1 ? '' : 's'} left in size ${item.size}.',
      );
    }
    await itemsRef(uid).doc(item.id).update({
      'quantity': quantity,
      'price': product.price,
      'name': product.name,
      'imageId': product.imageId,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> removeItem({required String uid, required String itemId}) async {
    await itemsRef(uid).doc(itemId).delete();
  }

  /// Removes only the selected cart lines, leaving the rest of the cart intact.
  Future<void> removeItems({
    required String uid,
    required Iterable<String> itemIds,
  }) async {
    final ids = itemIds.toSet();
    if (ids.isEmpty) return;
    final batch = _db.batch();
    for (final id in ids) {
      batch.delete(itemsRef(uid).doc(id));
    }
    await batch.commit();
  }

  Future<void> clearCart(String uid) async {
    final snapshot = await itemsRef(uid).get();
    if (snapshot.docs.isEmpty) return;
    final batch = _db.batch();
    for (final doc in snapshot.docs) {
      batch.delete(doc.reference);
    }
    await batch.commit();
  }

  /// Adds every local guest line to the account cart.
  ///
  /// Quantities are merged by the deterministic product/size document id, so
  /// re-running this never creates duplicates. Stock, the per-line maximum and
  /// the current catalogue price are re-read before each line is written. Lines
  /// that cannot be added at all are reported instead of failing the whole
  /// merge; quantities that were reduced to fit stock are reported as adjusted.
  Future<CartMergeResult> mergeItems({
    required String uid,
    required List<CartItem> items,
  }) async {
    var mergedLines = 0;
    var mergedQuantity = 0;
    final skipped = <String>[];
    final adjusted = <String>[];

    for (final item in items) {
      final label = '${item.name} (${item.size})';
      try {
        final productSnapshot = await _db
            .collection(AppConfig.productsCollection)
            .doc(item.productId)
            .get();
        if (!productSnapshot.exists) {
          skipped.add(label);
          continue;
        }
        final product = Product.fromDoc(productSnapshot);
        if (!product.isActive) {
          skipped.add(label);
          continue;
        }
        final available = product.stockFor(item.size);
        if (available <= 0) {
          skipped.add(label);
          continue;
        }
        final existingSnapshot = await itemsRef(uid).doc(item.id).get();
        final existing =
            (existingSnapshot.data()?['quantity'] as num?)?.toInt() ?? 0;
        final room = min(available, AppConfig.maxCartQuantity) - existing;
        if (room <= 0) {
          skipped.add(label);
          continue;
        }
        final quantity = min(item.quantity, room);
        await addToCart(
          uid: uid,
          product: product,
          size: item.size,
          quantity: quantity,
        );
        mergedLines++;
        mergedQuantity += quantity;
        if (quantity < item.quantity) adjusted.add(label);
      } on CartFailure {
        skipped.add(label);
      } catch (_) {
        skipped.add(label);
      }
    }

    return CartMergeResult(
      mergedLines: mergedLines,
      mergedQuantity: mergedQuantity,
      skipped: List<String>.unmodifiable(skipped),
      adjusted: List<String>.unmodifiable(adjusted),
    );
  }

  int cartTotal(List<CartItem> items) =>
      items.fold<int>(0, (total, item) => total + item.subtotal);

  int cartCount(List<CartItem> items) =>
      items.fold<int>(0, (total, item) => total + item.quantity);
}

class CartFailure implements Exception {
  const CartFailure(this.message);

  final String message;

  @override
  String toString() => message;
}

class CartMergeResult {
  const CartMergeResult({
    required this.mergedLines,
    required this.mergedQuantity,
    required this.skipped,
    required this.adjusted,
  });

  final int mergedLines;
  final int mergedQuantity;
  final List<String> skipped;
  final List<String> adjusted;

  bool get hasIssues => skipped.isNotEmpty || adjusted.isNotEmpty;
}
