import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../core/app_theme.dart';
import '../services/product_service.dart';

/// Product images live as bytes in the `product_images` Firestore collection on
/// the current Spark plan. Bytes are cached by [ProductService] so that
/// scrolling the catalogue does not re-read each document.
class ProductImage extends StatefulWidget {
  const ProductImage({
    super.key,
    required this.imageId,
    this.version,
    this.fit = BoxFit.cover,
    this.iconSize = 40,
    this.showLabel = true,
  });

  final String? imageId;
  final int? version;
  final BoxFit fit;
  final double iconSize;
  final bool showLabel;

  @override
  State<ProductImage> createState() => _ProductImageState();
}

class _ProductImageState extends State<ProductImage> {
  Future<Uint8List?>? _future;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant ProductImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.imageId != widget.imageId ||
        oldWidget.version != widget.version) {
      _load();
    }
  }

  void _load() {
    final id = widget.imageId;
    if (id == null || id.isEmpty) {
      _future = Future<Uint8List?>.value(null);
    } else {
      _future = ProductService.instance.loadProductImage(id);
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Uint8List?>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 1.4),
            ),
          );
        }
        final bytes = snapshot.data;
        if (snapshot.hasError || bytes == null || bytes.isEmpty) {
          return _Placeholder(
            iconSize: widget.iconSize,
            showLabel: widget.showLabel,
          );
        }
        return Image.memory(
          bytes,
          fit: widget.fit,
          width: double.infinity,
          height: double.infinity,
          gaplessPlayback: true,
          errorBuilder: (context, error, stack) => _Placeholder(
            iconSize: widget.iconSize,
            showLabel: widget.showLabel,
          ),
        );
      },
    );
  }
}

class _Placeholder extends StatelessWidget {
  const _Placeholder({required this.iconSize, required this.showLabel});

  final double iconSize;
  final bool showLabel;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.subtle,
      alignment: Alignment.center,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: iconSize,
            height: iconSize,
            decoration: const BoxDecoration(
              color: AppColors.ink,
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Text(
              'U',
              style: TextStyle(
                fontSize: iconSize * 0.44,
                fontWeight: FontWeight.w900,
                color: Colors.white,
                height: 1,
              ),
            ),
          ),
          if (showLabel) ...[
            const SizedBox(height: 10),
            const Text(
              'IMAGE PENDING',
              style: TextStyle(
                fontSize: 8,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.8,
                color: AppColors.muted,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
