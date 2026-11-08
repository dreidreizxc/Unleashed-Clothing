import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../core/app_theme.dart';
import '../../core/formatters.dart';
import '../../models/order.dart';
import '../../models/product.dart';
import '../../models/product_review.dart';
import '../../services/cart_service.dart';
import '../../services/product_service.dart';
import '../../services/review_service.dart';
import '../../state/app_state.dart';
import '../../widgets/common.dart';
import '../../widgets/editorial.dart';
import '../../widgets/product_image.dart';
import '../../widgets/quantity_stepper.dart';
import '../cart/cart_screen.dart';
import '../reviews/write_review_screen.dart';

class ProductDetailScreen extends StatefulWidget {
  const ProductDetailScreen({super.key, required this.productId});

  final String productId;

  @override
  State<ProductDetailScreen> createState() => _ProductDetailScreenState();
}

class _ProductDetailScreenState extends State<ProductDetailScreen> {
  late final Stream<Product?> _productStream;
  late final Stream<List<ProductReview>> _reviewsStream;
  Future<CustomerOrder?>? _eligibility;
  String? _selectedSize;
  int _quantity = 1;
  bool _adding = false;

  @override
  void initState() {
    super.initState();
    _productStream = ProductService.instance.watchProduct(widget.productId);
    _reviewsStream = ProductService.instance.watchReviews(widget.productId);
    final uid = AppState.instance.user?.uid;
    if (uid != null) {
      _eligibility = ReviewService.instance.eligibleOrderForProduct(
        customerId: uid,
        productId: widget.productId,
      );
    }
  }

  String? _effectiveSize(Product product) {
    final available = product.availableSizes;
    if (available.isEmpty) return null;
    if (_selectedSize != null && available.contains(_selectedSize)) {
      return _selectedSize;
    }
    return available.first;
  }

  Future<void> _addToCart(Product product) async {
    final uid = AppState.instance.user?.uid;
    final size = _effectiveSize(product);
    if (size == null) {
      showAppSnack(context, 'This product is out of stock.', error: true);
      return;
    }
    setState(() => _adding = true);
    try {
      if (uid == null) {
        // Guests keep their cart on this device. It is merged into the account
        // after sign-in, so adding to the cart never forces an account.
        await AppState.instance.addGuestCartItem(
          product: product,
          size: size,
          quantity: _quantity,
        );
      } else {
        await CartService.instance.addToCart(
          uid: uid,
          product: product,
          size: size,
          quantity: _quantity,
        );
      }
      if (!mounted) return;
      showAppSnack(context, '${product.name} · $size added to your cart.');
    } on CartFailure catch (error) {
      if (mounted) showAppSnack(context, error.message, error: true);
    } catch (_) {
      if (mounted) {
        showAppSnack(
          context,
          'That item could not be added. Check your connection and try again.',
          error: true,
        );
      }
    } finally {
      if (mounted) setState(() => _adding = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<Product?>(
      stream: _productStream,
      builder: (context, snapshot) {
        final product = snapshot.data;
        final loading =
            snapshot.connectionState == ConnectionState.waiting &&
            product == null;

        return Scaffold(
          backgroundColor: AppColors.paper,
          body: SafeArea(
            bottom: false,
            child: Column(
              children: [
                _DetailTopBar(
                  onBack: () => Navigator.of(context).maybePop(),
                  onCart: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const CartScreen()),
                  ),
                ),
                Expanded(
                  child: loading
                      ? const _DetailSkeleton()
                      : snapshot.hasError
                      ? AppStateView.error(
                          title: 'Could not load this piece',
                          message: 'Check your connection and try again.',
                          onAction: () => setState(() {}),
                        )
                      : product == null
                      ? const AppStateView.empty(
                          icon: Icons.remove_shopping_cart_outlined,
                          title: 'Product not found',
                          message:
                              'This product may have been removed or archived '
                              'by the store.',
                        )
                      : _ProductBody(
                          product: product,
                          reviewsStream: _reviewsStream,
                          eligibility: _eligibility,
                          selectedSize: _effectiveSize(product),
                          onSizeSelected: (size) => setState(() {
                            _selectedSize = size;
                            final stock = product.stockFor(size);
                            if (_quantity > stock) {
                              _quantity = stock <= 0 ? 1 : stock;
                            }
                          }),
                          quantity: _quantity,
                          onQuantityChanged: (value) =>
                              setState(() => _quantity = value),
                          onAddToCart: () => _addToCart(product),
                          adding: _adding,
                        ),
                ),
                if (!loading && product != null)
                  _AddToCartBar(
                    product: product,
                    selectedSize: _effectiveSize(product),
                    quantity: _quantity,
                    adding: _adding,
                    onAdd: () => _addToCart(product),
                    onViewCart: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const CartScreen()),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _DetailTopBar extends StatelessWidget {
  const _DetailTopBar({required this.onBack, required this.onCart});

  final VoidCallback onBack;
  final VoidCallback onCart;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(8, 2, 8, 6),
      color: AppColors.paper,
      child: Row(
        children: [
          IconButton(
            tooltip: 'Back',
            onPressed: onBack,
            icon: const Icon(Icons.arrow_back, size: 20),
          ),
          const SizedBox(width: 2),
          const Text(
            'THE PIECE',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w900,
              letterSpacing: 2.6,
            ),
          ),
          const Spacer(),
          IconButton(
            tooltip: 'Cart',
            onPressed: onCart,
            icon: AppStateBuilder(
              builder: (context, state) => Badge.count(
                count: state.cartCount,
                isLabelVisible: state.cartCount > 0,
                backgroundColor: AppColors.accent,
                textColor: Colors.white,
                smallSize: 14,
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: const Icon(Icons.shopping_bag_outlined, size: 21),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ProductBody extends StatelessWidget {
  const _ProductBody({
    required this.product,
    required this.reviewsStream,
    required this.eligibility,
    required this.selectedSize,
    required this.onSizeSelected,
    required this.quantity,
    required this.onQuantityChanged,
    required this.onAddToCart,
    required this.adding,
  });

  final Product product;
  final Stream<List<ProductReview>> reviewsStream;
  final Future<CustomerOrder?>? eligibility;
  final String? selectedSize;
  final ValueChanged<String> onSizeSelected;
  final int quantity;
  final ValueChanged<int> onQuantityChanged;
  final VoidCallback onAddToCart;
  final bool adding;

  @override
  Widget build(BuildContext context) {
    final stock = selectedSize == null ? 0 : product.stockFor(selectedSize!);
    return SingleChildScrollView(
      padding: const EdgeInsets.only(bottom: 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Stack(
            children: [
              AspectRatio(
                aspectRatio: 4 / 5,
                child: ProductImage(
                  imageId: product.imageId,
                  version: product.imageUpdatedAt?.millisecondsSinceEpoch,
                  iconSize: 72,
                  showLabel: false,
                ),
              ),
              Positioned(
                top: 12,
                left: 12,
                child: Container(
                  color: AppColors.ink,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 9,
                    vertical: 5,
                  ),
                  child: Text(
                    product.category.toUpperCase(),
                    style: const TextStyle(
                      fontSize: 8,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.4,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
              Positioned(
                bottom: 12,
                left: 12,
                child: Container(
                  color: AppColors.surface,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 9,
                    vertical: 5,
                  ),
                  child: StatusDot(
                    label: product.inStock ? 'IN STOCK' : 'SOLD OUT',
                    color: product.inStock
                        ? AppColors.success
                        : AppColors.accent,
                  ),
                ),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        product.name.toUpperCase(),
                        style: const TextStyle(
                          fontSize: 30,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -1.3,
                          height: 0.98,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      product.priceLabel,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.6,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Text(
                  product.description.isEmpty
                      ? 'No description was provided for this product.'
                      : product.description,
                  style: const TextStyle(
                    fontSize: 13,
                    height: 1.65,
                    color: AppColors.muted,
                  ),
                ),
                const SizedBox(height: 22),
                const Hairline(),
                const SizedBox(height: 20),
                Row(
                  children: [
                    const Eyebrow('Select size'),
                    const Spacer(),
                    if (selectedSize != null)
                      Text(
                        stock <= 3 ? '$stock LEFT · LOW' : '$stock IN STOCK',
                        style: TextStyle(
                          fontSize: 8.5,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.3,
                          color: stock <= 3
                              ? AppColors.accent
                              : AppColors.muted,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                if (product.sizes.isEmpty)
                  const Text(
                    'This product has no size options.',
                    style: TextStyle(fontSize: 12, color: AppColors.muted),
                  )
                else
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final size in product.sizes)
                        _SizeOption(
                          label: size,
                          selected: selectedSize == size,
                          enabled: product.stockFor(size) > 0,
                          onTap: () => onSizeSelected(size),
                        ),
                    ],
                  ),
                if (product.sizeChartUrl?.trim().isNotEmpty == true) ...[
                  const SizedBox(height: 18),
                  _SizeChartSection(url: product.sizeChartUrl!),
                ],
                const SizedBox(height: 24),
                Row(
                  children: [
                    const Eyebrow('Quantity'),
                    const SizedBox(width: 14),
                    Text(
                      'MAX ${stock <= 0 ? 1 : (stock > 20 ? 20 : stock)}',
                      style: const TextStyle(
                        fontSize: 8,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.2,
                        color: AppColors.muted,
                      ),
                    ),
                    const Spacer(),
                    QuantityStepper(
                      value: quantity,
                      min: 1,
                      max: stock <= 0 ? 1 : (stock > 20 ? 20 : stock),
                      enabled: stock > 0 && !adding,
                      onChanged: onQuantityChanged,
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceAlt,
                    border: Border.all(color: AppColors.line),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.local_shipping_outlined, size: 17),
                      SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Cash on delivery available nationwide. Order '
                          'requests are confirmed by the store before dispatch.',
                          style: TextStyle(
                            fontSize: 11,
                            height: 1.5,
                            color: AppColors.muted,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 28),
                const _ReviewsHeader(),
                const SizedBox(height: 12),
                _ReviewsSection(
                  product: product,
                  reviewsStream: reviewsStream,
                  eligibility: eligibility,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SizeOption extends StatelessWidget {
  const _SizeOption({
    required this.label,
    required this.selected,
    required this.enabled,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final textColor = !enabled
        ? AppColors.warmGray
        : selected
        ? Colors.white
        : AppColors.ink;
    return Material(
      color: selected ? AppColors.ink : Colors.transparent,
      child: InkWell(
        onTap: enabled ? onTap : null,
        child: Container(
          constraints: const BoxConstraints(minWidth: 54),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            border: Border.all(
              color: selected
                  ? AppColors.ink
                  : enabled
                  ? AppColors.line
                  : AppColors.subtle,
            ),
          ),
          alignment: Alignment.center,
          child: Text(
            label.toUpperCase(),
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.8,
              color: textColor,
              decoration: enabled ? null : TextDecoration.lineThrough,
            ),
          ),
        ),
      ),
    );
  }
}

class _AddToCartBar extends StatelessWidget {
  const _AddToCartBar({
    required this.product,
    required this.selectedSize,
    required this.quantity,
    required this.adding,
    required this.onAdd,
    required this.onViewCart,
  });

  final Product product;
  final String? selectedSize;
  final int quantity;
  final bool adding;
  final VoidCallback onAdd;
  final VoidCallback onViewCart;

  @override
  Widget build(BuildContext context) {
    final canAdd = product.inStock && selectedSize != null;
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.line)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          child: Row(
            children: [
              IconButton(
                tooltip: 'View cart',
                onPressed: onViewCart,
                style: IconButton.styleFrom(
                  side: const BorderSide(color: AppColors.line),
                  shape: const RoundedRectangleBorder(),
                  minimumSize: const Size(48, 48),
                ),
                icon: const Icon(Icons.shopping_bag_outlined, size: 20),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: SizedBox(
                  height: 48,
                  child: ElevatedButton(
                    onPressed: canAdd && !adding ? onAdd : null,
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size.fromHeight(48),
                    ),
                    child: adding
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : Text(
                            !product.inStock
                                ? 'SOLD OUT'
                                : selectedSize == null
                                ? 'SELECT A SIZE'
                                : 'ADD TO CART · '
                                      '${formatMoney(product.price * quantity)}',
                          ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ReviewsHeader extends StatelessWidget {
  const _ReviewsHeader();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Eyebrow('The verdict'),
        const SizedBox(width: 14),
        Expanded(child: Container(height: 1, color: AppColors.line)),
      ],
    );
  }
}

class _ReviewsSection extends StatelessWidget {
  const _ReviewsSection({
    required this.product,
    required this.reviewsStream,
    required this.eligibility,
  });

  final Product product;
  final Stream<List<ProductReview>> reviewsStream;
  final Future<CustomerOrder?>? eligibility;

  @override
  Widget build(BuildContext context) {
    final uid = AppState.instance.user?.uid;
    return StreamBuilder<List<ProductReview>>(
      stream: reviewsStream,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const Text(
            'Reviews are unavailable right now. They become visible once the '
            'store publishes its review rules.',
            style: TextStyle(fontSize: 12, color: AppColors.muted),
          );
        }
        final reviews = snapshot.data ?? const <ProductReview>[];
        final average = reviews.isEmpty
            ? 0.0
            : reviews.fold<int>(0, (sum, review) => sum + review.rating) /
                  reviews.length;
        ProductReview? mine;
        if (uid != null) {
          for (final review in reviews) {
            if (review.customerId == uid) {
              mine = review;
              break;
            }
          }
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  reviews.isEmpty ? '—' : average.toStringAsFixed(1),
                  style: const TextStyle(
                    fontSize: 40,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -2,
                    height: 1,
                  ),
                ),
                const SizedBox(width: 10),
                Padding(
                  padding: const EdgeInsets.only(bottom: 5),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _Stars(rating: average, size: 14),
                      const SizedBox(height: 3),
                      Text(
                        '${reviews.length} '
                        '${reviews.length == 1 ? 'REVIEW' : 'REVIEWS'}',
                        style: const TextStyle(
                          fontSize: 8,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.3,
                          color: AppColors.muted,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            if (reviews.isEmpty)
              Text(
                'No reviews yet. Reviews can only be written after a delivered '
                'purchase.',
                style: Theme.of(context).textTheme.bodySmall,
              )
            else
              ...reviews.take(8).map((review) => _ReviewTile(review: review)),
            const SizedBox(height: 8),
            if (eligibility != null)
              FutureBuilder<CustomerOrder?>(
                future: eligibility,
                builder: (context, snapshot) {
                  final order = snapshot.data;
                  if (order == null) {
                    return Text(
                      'Buy and receive this item to leave a review.',
                      style: Theme.of(context).textTheme.bodySmall,
                    );
                  }
                  return Align(
                    alignment: Alignment.centerLeft,
                    child: OutlinedButton.icon(
                      onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => WriteReviewScreen(
                            productId: product.id,
                            productName: product.name,
                            orderId: order.id,
                          ),
                        ),
                      ),
                      icon: const Icon(Icons.rate_review_outlined, size: 16),
                      label: Text(
                        mine == null ? 'WRITE A REVIEW' : 'EDIT YOUR REVIEW',
                      ),
                    ),
                  );
                },
              ),
          ],
        );
      },
    );
  }
}

class _ReviewTile extends StatelessWidget {
  const _ReviewTile({required this.review});

  final ProductReview review;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border.all(color: AppColors.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  (review.customerName ?? 'Verified customer').toUpperCase(),
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.8,
                  ),
                ),
              ),
              _Stars(rating: review.rating.toDouble(), size: 12),
            ],
          ),
          if (review.text.trim().isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              review.text,
              style: const TextStyle(fontSize: 13, height: 1.55),
            ),
          ],
          const SizedBox(height: 8),
          Text(
            'DELIVERED PURCHASE · ${timeAgo(review.createdAt).toUpperCase()}',
            style: const TextStyle(
              fontSize: 8,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.1,
              color: AppColors.muted,
            ),
          ),
        ],
      ),
    );
  }
}

class _Stars extends StatelessWidget {
  const _Stars({required this.rating, this.size = 16});

  final double rating;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (index) {
        final position = index + 1;
        final icon = rating >= position
            ? Icons.star
            : rating >= position - 0.5
            ? Icons.star_half
            : Icons.star_border;
        return Icon(
          icon,
          size: size,
          color: rating >= position - 0.5
              ? AppColors.accent
              : AppColors.warmGray,
        );
      }),
    );
  }
}

class _DetailSkeleton extends StatelessWidget {
  const _DetailSkeleton();

  @override
  Widget build(BuildContext context) {
    return const SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AspectRatio(
            aspectRatio: 4 / 5,
            child: SkeletonBox(height: double.infinity),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(20, 20, 20, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SkeletonBox(width: 220, height: 26),
                SizedBox(height: 12),
                SkeletonBox(width: 90, height: 18),
                SizedBox(height: 18),
                SkeletonBox(height: 12),
                SizedBox(height: 8),
                SkeletonBox(height: 12),
                SizedBox(height: 8),
                SkeletonBox(width: 180, height: 12),
                SizedBox(height: 26),
                SkeletonBox(height: 46),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SizeChartSection extends StatefulWidget {
  const _SizeChartSection({required this.url});

  final String url;

  @override
  State<_SizeChartSection> createState() => _SizeChartSectionState();
}

class _SizeChartSectionState extends State<_SizeChartSection> {
  Future<Uint8List?>? _chartFuture;
  String? _documentId;

  String? _resolveDocumentId(String value) {
    final uri = Uri.tryParse(value);

    if (uri != null &&
        uri.scheme == 'firestore' &&
        uri.host == 'product_images' &&
        uri.pathSegments.isNotEmpty) {
      return uri.pathSegments.last;
    }

    if (value.startsWith('product_images/')) {
      return value.substring('product_images/'.length);
    }

    return null;
  }

  void _loadChart() {
    _documentId = _resolveDocumentId(widget.url);
    if (_documentId != null && _documentId!.isNotEmpty) {
      _chartFuture =
          ProductService.instance.loadProductImage(_documentId);
    } else {
      _chartFuture = null;
    }
  }

  @override
  void initState() {
    super.initState();
    _loadChart();
  }

  @override
  void didUpdateWidget(covariant _SizeChartSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.url != widget.url) {
      _loadChart();
    }
  }

  void _showZoom(Uint8List? bytes) {
    final isRemote = widget.url.startsWith('https://') ||
        widget.url.startsWith('http://');

    showDialog<void>(
      context: context,
      barrierColor: Colors.black87,
      builder: (dialogContext) => Dialog(
        backgroundColor: AppColors.surface,
        insetPadding: const EdgeInsets.all(16),
        child: Stack(
          children: [
            InteractiveViewer(
              minScale: 0.8,
              maxScale: 4,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: isRemote
                    ? Image.network(
                        widget.url,
                        fit: BoxFit.contain,
                        errorBuilder: (_, _, _) => const Center(
                          child: Text('Could not load size chart.'),
                        ),
                      )
                    : bytes != null
                    ? Image.memory(bytes, fit: BoxFit.contain)
                    : const Center(
                        child: Text('Size chart is unavailable.'),
                      ),
              ),
            ),
            Positioned(
              top: 4,
              right: 4,
              child: IconButton(
                tooltip: 'Close',
                onPressed: () => Navigator.of(dialogContext).pop(),
                icon: const Icon(Icons.close),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _chartCard(Uint8List? bytes) {
    final isRemote = widget.url.startsWith('https://') ||
        widget.url.startsWith('http://');

    Widget image;

    if (isRemote) {
      image = Image.network(
        widget.url,
        fit: BoxFit.contain,
        width: double.infinity,
        height: 240,
        errorBuilder: (_, _, _) => const SizedBox(
          height: 100,
          child: Center(child: Text('Could not load size chart.')),
        ),
      );
    } else if (bytes != null && bytes.isNotEmpty) {
      image = Image.memory(
        bytes,
        fit: BoxFit.contain,
        width: double.infinity,
        height: 240,
        errorBuilder: (_, _, _) => const SizedBox(
          height: 100,
          child: Center(child: Text('Could not display size chart.')),
        ),
      );
    } else {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Row(
          children: [
            Eyebrow('Size guide'),
            Spacer(),
            Icon(
              Icons.zoom_in,
              size: 15,
              color: AppColors.muted,
            ),
            SizedBox(width: 4),
            Text(
              'TAP TO ENLARGE',
              style: TextStyle(
                fontSize: 8,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.1,
                color: AppColors.muted,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Material(
          color: AppColors.surface,
          child: InkWell(
            onTap: () => _showZoom(bytes),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                border: Border.all(color: AppColors.line),
              ),
              child: image,
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final isRemote = widget.url.startsWith('https://') ||
        widget.url.startsWith('http://');

    if (isRemote) return _chartCard(null);

    if (_documentId == null) return const SizedBox.shrink();

    return FutureBuilder<Uint8List?>(
      future: _chartFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Center(
              child: CircularProgressIndicator(strokeWidth: 1.5),
            ),
          );
        }

        if (snapshot.hasError || snapshot.data == null) {
          return const SizedBox.shrink();
        }

        return _chartCard(snapshot.data);
      },
    );
  }
}
