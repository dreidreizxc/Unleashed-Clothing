import 'package:flutter/material.dart';

import '../core/app_theme.dart';
import '../models/product.dart';
import 'product_image.dart';

/// Minimal editorial product tile: large image, restrained metadata and a
/// single availability cue. All data comes from the live [Product] record.
class ProductCard extends StatelessWidget {
  const ProductCard({
    super.key,
    required this.product,
    required this.onTap,
    this.showStock = true,
  });

  final Product product;
  final VoidCallback onTap;
  final bool showStock;

  @override
  Widget build(BuildContext context) {
    final available = product.inStock;
    return Semantics(
      button: true,
      label: '${product.name}, ${product.priceLabel}',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          splashColor: AppColors.ink.withValues(alpha: 0.05),
          highlightColor: AppColors.ink.withValues(alpha: 0.03),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AspectRatio(
                aspectRatio: 4 / 5,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    DecoratedBox(
                      decoration: BoxDecoration(
                        color: AppColors.subtle,
                        border: Border.all(color: AppColors.line),
                      ),
                      child: ProductImage(
                        imageId: product.imageId,
                        version: product.imageUpdatedAt?.millisecondsSinceEpoch,
                        iconSize: 36,
                        showLabel: false,
                      ),
                    ),
                    Positioned(
                      top: 0,
                      left: 0,
                      child: Container(
                        color: available ? AppColors.ink : AppColors.warmGray,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 5,
                        ),
                        child: Text(
                          product.category.toUpperCase(),
                          style: const TextStyle(
                            fontSize: 7.5,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.2,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                    if (!available)
                      Positioned(
                        bottom: 0,
                        left: 0,
                        right: 0,
                        child: Container(
                          color: AppColors.ink.withValues(alpha: 0.86),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 6,
                          ),
                          child: const Text(
                            'SOLD OUT',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 8.5,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 2,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              Text(
                product.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.1,
                ),
              ),
              const SizedBox(height: 3),
              Row(
                children: [
                  Text(
                    product.priceLabel,
                    style: const TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.2,
                    ),
                  ),
                  if (showStock) ...[
                    const Spacer(),
                    Container(
                      width: 5,
                      height: 5,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: !available
                            ? AppColors.accent
                            : product.totalStock <= 5
                            ? AppColors.warning
                            : AppColors.success,
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
