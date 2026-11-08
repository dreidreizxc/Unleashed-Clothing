import 'package:cloud_firestore/cloud_firestore.dart';

import '../core/formatters.dart';

class CartItem {
  const CartItem({
    required this.id,
    required this.productId,
    required this.name,
    required this.size,
    required this.price,
    required this.quantity,
    this.imageId,
    this.category,
    this.addedAt,
  });

  final String id;
  final String productId;
  final String name;
  final String size;
  final int price;
  final int quantity;
  final String? imageId;
  final String? category;
  final Timestamp? addedAt;

  int get subtotal => price * quantity;

  String get priceLabel => formatMoney(price);

  factory CartItem.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? <String, dynamic>{};
    return CartItem(
      id: doc.id,
      productId: (data['productId'] ?? '').toString(),
      name: (data['name'] ?? 'Product').toString(),
      size: (data['size'] ?? 'One size').toString(),
      price: (data['price'] as num?)?.toInt() ?? 0,
      quantity: (data['quantity'] as num?)?.toInt() ?? 1,
      imageId: data['imageId']?.toString(),
      category: data['category']?.toString(),
      addedAt: data['addedAt'] is Timestamp
          ? data['addedAt'] as Timestamp
          : null,
    );
  }

  CartItem copyWith({
    String? id,
    String? name,
    int? price,
    int? quantity,
    String? imageId,
    String? category,
    Timestamp? addedAt,
  }) => CartItem(
    id: id ?? this.id,
    productId: productId,
    name: name ?? this.name,
    size: size,
    price: price ?? this.price,
    quantity: quantity ?? this.quantity,
    imageId: imageId ?? this.imageId,
    category: category ?? this.category,
    addedAt: addedAt ?? this.addedAt,
  );

  /// Local persistence used by the guest cart. Firestore uses its own
  /// `Timestamp` type, while `shared_preferences` can only store primitives.
  Map<String, dynamic> toLocalMap() => {
    'id': id,
    'productId': productId,
    'name': name,
    'size': size,
    'price': price,
    'quantity': quantity,
    'imageId': imageId,
    'category': category,
    'addedAt': addedAt?.millisecondsSinceEpoch,
  };

  static CartItem? fromLocalMap(Map<String, dynamic> data) {
    final id = (data['id'] ?? '').toString();
    final productId = (data['productId'] ?? '').toString();
    final size = (data['size'] ?? '').toString();
    if (id.isEmpty || productId.isEmpty || size.isEmpty) return null;
    final addedAtMillis = (data['addedAt'] as num?)?.toInt();
    return CartItem(
      id: id,
      productId: productId,
      name: (data['name'] ?? 'Product').toString(),
      size: size,
      price: (data['price'] as num?)?.toInt() ?? 0,
      quantity: ((data['quantity'] as num?)?.toInt() ?? 1).clamp(1, 999),
      imageId: data['imageId']?.toString(),
      category: data['category']?.toString(),
      addedAt: addedAtMillis == null
          ? null
          : Timestamp.fromMillisecondsSinceEpoch(addedAtMillis),
    );
  }
}
