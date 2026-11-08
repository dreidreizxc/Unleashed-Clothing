import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../config/app_config.dart';
import '../core/errors.dart';
import '../models/cart_item.dart';
import '../models/product.dart';
import 'cart_service.dart';

/// Stores a guest's cart on the device until they sign in.
///
/// The cart is deliberately local-only: no Firestore document is created for a
/// guest, so the security rules never have to trust an unauthenticated writer.
/// Prices and stock are treated as display hints while browsing; the account
/// cart and checkout re-read the catalogue before an order is created.
class GuestCartService extends ChangeNotifier {
  GuestCartService._();

  static final GuestCartService instance = GuestCartService._();

  static const String storageKey = 'unleashed_guest_cart_v1';

  final List<CartItem> _items = [];
  bool _loaded = false;

  List<CartItem> get items => List<CartItem>.unmodifiable(_items);

  bool get isEmpty => _items.isEmpty;

  int get count => _items.fold<int>(0, (total, item) => total + item.quantity);

  int get total => _items.fold<int>(0, (total, item) => total + item.subtotal);

  CartItem? find(String productId, String size) {
    final id = CartService.itemIdFor(productId, size);
    for (final item in _items) {
      if (item.id == id) return item;
    }
    return null;
  }

  Future<void> load() async {
    if (_loaded) return;
    _loaded = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(storageKey);
      if (raw == null || raw.trim().isEmpty) return;
      final decoded = jsonDecode(raw);
      if (decoded is! List) return;
      for (final entry in decoded) {
        if (entry is! Map) continue;
        final item = CartItem.fromLocalMap(Map<String, dynamic>.from(entry));
        if (item != null) _items.add(item);
      }
      notifyListeners();
    } catch (error, stack) {
      logTechnicalError('guestCart.load', error, stack);
    }
  }

  Future<int> addItem({
    required Product product,
    required String size,
    required int quantity,
  }) async {
    if (quantity < 1) {
      throw const CartFailure('Choose at least one item.');
    }
    if (!product.isActive) {
      throw const CartFailure('This product is not available right now.');
    }
    if (!product.availableSizes.contains(size)) {
      throw const CartFailure('That size is no longer available.');
    }
    final available = product.stockFor(size);
    if (available <= 0) {
      throw const CartFailure('This size is out of stock.');
    }

    final id = CartService.itemIdFor(product.id, size);
    final index = _items.indexWhere((item) => item.id == id);
    final existingQuantity = index < 0 ? 0 : _items[index].quantity;
    final nextQuantity = existingQuantity + quantity;
    if (nextQuantity > available) {
      throw CartFailure(
        'Only $available item${available == 1 ? '' : 's'} left in size $size.',
      );
    }
    if (nextQuantity > AppConfig.maxCartQuantity) {
      throw const CartFailure(
        'You have reached the maximum quantity for this item.',
      );
    }

    final line = CartItem(
      id: id,
      productId: product.id,
      name: product.name,
      size: size,
      price: product.price,
      quantity: nextQuantity,
      imageId: product.imageId,
      category: product.category,
      addedAt: index < 0
          ? Timestamp.now()
          : (_items[index].addedAt ?? Timestamp.now()),
    );
    if (index < 0) {
      _items.add(line);
    } else {
      _items[index] = line;
    }
    await _commit();
    return nextQuantity;
  }

  Future<void> setQuantity({
    required CartItem item,
    required int quantity,
    Product? product,
  }) async {
    final index = _items.indexWhere((line) => line.id == item.id);
    if (index < 0) return;
    if (quantity < 1) {
      await removeItem(item.id);
      return;
    }
    if (quantity > AppConfig.maxCartQuantity) {
      throw const CartFailure(
        'You have reached the maximum quantity for this item.',
      );
    }
    if (product != null) {
      if (!product.isActive) {
        throw const CartFailure('This product is not available right now.');
      }
      final available = product.stockFor(item.size);
      if (quantity > available) {
        throw CartFailure(
          'Only $available item${available == 1 ? '' : 's'} left in size '
          '${item.size}.',
        );
      }
    }
    _items[index] = _items[index].copyWith(quantity: quantity);
    await _commit();
  }

  Future<void> removeItem(String itemId) async {
    _items.removeWhere((item) => item.id == itemId);
    await _commit();
  }

  /// Removes only the selected guest cart lines in one storage write.
  Future<void> removeItems(Iterable<String> itemIds) async {
    final ids = itemIds.toSet();
    if (ids.isEmpty) return;
    final before = _items.length;
    _items.removeWhere((item) => ids.contains(item.id));
    if (_items.length == before) return;
    await _commit();
  }

  Future<void> clear() async {
    if (_items.isEmpty) {
      await _save();
      return;
    }
    _items.clear();
    await _commit();
  }

  /// Updates stored prices/names/images from the live catalogue. Availability
  /// and quantity problems are reported by the cart screen, never silently
  /// removed here.
  Future<int> syncPrices(Map<String, Product> catalog) async {
    var updated = 0;
    for (var index = 0; index < _items.length; index++) {
      final item = _items[index];
      final product = catalog[item.productId];
      if (product == null || !product.isActive) continue;
      if (item.price == product.price &&
          item.name == product.name &&
          item.imageId == product.imageId) {
        continue;
      }
      _items[index] = item.copyWith(
        name: product.name,
        price: product.price,
        imageId: product.imageId,
        category: product.category,
      );
      updated++;
    }
    if (updated > 0) {
      await _commit();
    }
    return updated;
  }

  Future<void> replaceAll(List<CartItem> items) async {
    _items
      ..clear()
      ..addAll(items);
    await _commit();
  }

  Future<void> _commit() async {
    notifyListeners();
    await _save();
  }

  Future<void> _save() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        storageKey,
        jsonEncode(_items.map((item) => item.toLocalMap()).toList()),
      );
    } catch (error, stack) {
      logTechnicalError('guestCart.save', error, stack);
    }
  }
}
