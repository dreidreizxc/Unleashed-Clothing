import 'package:cloud_firestore/cloud_firestore.dart';

import '../core/formatters.dart';

class Product {
  const Product({
    required this.id,
    required this.name,
    required this.description,
    required this.price,
    required this.category,
    required this.sizes,
    required this.stock,
    required this.totalStock,
    required this.status,
    this.imageId,
    this.imageUpdatedAt,
    this.imageUrl,
    this.sizeChartUrl,
  });

  final String id;
  final String name;
  final String description;

  /// Integer centavos.
  final int price;
  final String category;
  final List<String> sizes;
  final Map<String, int> stock;
  final int totalStock;
  final String status;
  final String? imageId;
  final Timestamp? imageUpdatedAt;
  final String? imageUrl;
  final String? sizeChartUrl;

  bool get isActive => status == 'active';

  List<String> get availableSizes =>
      sizes.where((size) => (stock[size] ?? 0) > 0).toList(growable: false);

  bool get inStock => availableSizes.isNotEmpty && totalStock > 0;

  int stockFor(String size) => stock[size] ?? 0;

  factory Product.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? <String, dynamic>{};
    final rawStock = data['stock'];
    final parsedStock = <String, int>{};
    if (rawStock is Map) {
      rawStock.forEach((key, value) {
        if (value is num) parsedStock[key.toString()] = value.toInt();
      });
    }
    final rawSizes = data['sizes'];
    final sizes = <String>[];
    if (rawSizes is List) {
      for (final value in rawSizes) {
        if (value is String && value.trim().isNotEmpty) sizes.add(value);
      }
    }
    if (sizes.isEmpty) sizes.addAll(parsedStock.keys);
    final calculatedStock =
        parsedStock.values.fold<int>(0, (total, value) => total + value);
    final totalStock = (data['totalStock'] as num?)?.toInt() ?? calculatedStock;

    return Product(
      id: doc.id,
      name: (data['name'] ?? 'Untitled product').toString(),
      description: (data['description'] ?? '').toString(),
      price: (data['price'] as num?)?.toInt() ?? 0,
      category: (data['category'] ?? 'T-Shirt').toString(),
      sizes: List.unmodifiable(sizes),
      stock: Map.unmodifiable(parsedStock),
      totalStock: totalStock < 0 ? 0 : totalStock,
      status: (data['status'] ?? 'inactive').toString(),
      imageId: data['imageId']?.toString(),
      imageUpdatedAt: data['imageUpdatedAt'] is Timestamp
          ? data['imageUpdatedAt'] as Timestamp
          : null,
      imageUrl: data['imageUrl']?.toString(),
      sizeChartUrl: data['sizeChartUrl']?.toString(),
    );
  }

  String get priceLabel => formatMoney(price);
}
