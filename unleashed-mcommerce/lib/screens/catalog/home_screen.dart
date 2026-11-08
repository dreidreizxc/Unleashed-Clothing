import 'package:flutter/material.dart';

import '../../config/app_config.dart';
import '../../core/app_theme.dart';
import '../../models/announcement.dart';
import '../../models/product.dart';
import '../../services/announcement_service.dart';
import '../../services/product_service.dart';
import '../../widgets/common.dart';
import '../../widgets/editorial.dart';
import '../../widgets/product_card.dart';

import '../cart/cart_screen.dart';
import '../notifications/notifications_screen.dart';
import 'product_detail_screen.dart';
import '../../models/hero_banner.dart';
import '../../services/hero_banner_service.dart';

/// The storefront: an editorial home and the complete shop catalogue in one
/// scroll. Every tile is driven by the live `products` collection; nothing is
/// hardcoded.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

enum _SortMode { featured, priceLow, priceHigh, name }

class _HomeScreenState extends State<HomeScreen> {
  final _search = TextEditingController();
  final _scroll = ScrollController();
  final _collectionKey = GlobalKey();
  late Stream<List<Product>> _stream;
  String _query = '';
  String _category = 'All';
  _SortMode _sort = _SortMode.featured;

  @override
  void initState() {
    super.initState();
    _stream = ProductService.instance.watchActiveProducts();
  }

  @override
  void dispose() {
    _search.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    setState(() {
      _stream = ProductService.instance.watchActiveProducts();
    });
    await Future<void>.delayed(const Duration(milliseconds: 500));
  }

  List<Product> _filter(List<Product> products) {
    final query = _query.trim().toLowerCase();
    final filtered = products.where((product) {
      final categoryMatches =
          _category == 'All' || product.category == _category;
      final queryMatches =
          query.isEmpty ||
          product.name.toLowerCase().contains(query) ||
          product.description.toLowerCase().contains(query) ||
          product.category.toLowerCase().contains(query);
      return categoryMatches && queryMatches;
    }).toList();

    switch (_sort) {
      case _SortMode.featured:
        break;
      case _SortMode.priceLow:
        filtered.sort((a, b) => a.price.compareTo(b.price));
      case _SortMode.priceHigh:
        filtered.sort((a, b) => b.price.compareTo(a.price));
      case _SortMode.name:
        filtered.sort(
          (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
        );
    }
    return filtered;
  }

  void _openProduct(Product product) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ProductDetailScreen(productId: product.id),
      ),
    );
  }

  void _scrollToCollection() {
    final context = _collectionKey.currentContext;
    if (context != null) {
      Scrollable.ensureVisible(
        context,
        duration: AppMotion.slow,
        curve: AppMotion.curve,
        alignment: 0,
      );
    } else if (_scroll.hasClients) {
      _scroll.animateTo(760, duration: AppMotion.slow, curve: AppMotion.curve);
    }
  }

  void _resetFilters() {
    _search.clear();
    setState(() {
      _query = '';
      _category = 'All';
      _sort = _SortMode.featured;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.paper,
      body: SafeArea(
        bottom: false,
        child: StreamBuilder<List<Product>>(
          stream: _stream,
          builder: (context, snapshot) {
            final all = snapshot.data ?? const <Product>[];
            final products = _filter(all);
            final loading =
                snapshot.connectionState == ConnectionState.waiting &&
                !snapshot.hasData;

            return RefreshIndicator(
              onRefresh: _refresh,
              color: AppColors.ink,
              backgroundColor: AppColors.surface,
              child: CustomScrollView(
                controller: _scroll,
                physics: const AlwaysScrollableScrollPhysics(),
                slivers: [
                  SliverToBoxAdapter(
                    child: EditorialHeader(
                      actions: [
                        AppStateBuilder(
                          builder: (context, state) {
                            return _HeaderAction(
                              icon: Icons.notifications_none,
                              badge: state.unreadNotifications,
                              tooltip: 'Notifications',
                              onPressed: () => Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => const NotificationsScreen(),
                                ),
                              ),
                            );
                          },
                        ),
                        AppStateBuilder(
                          builder: (context, state) {
                            return _HeaderAction(
                              icon: Icons.shopping_bag_outlined,
                              badge: state.cartCount,
                              tooltip: 'Cart',
                              onPressed: () => Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => const CartScreen(),
                                ),
                              ),
                            );
                          },
                        ),
                        const SizedBox(width: 4),
                      ],
                    ),
                  ),
                  if (loading)
                    const SliverToBoxAdapter(child: _HomeSkeleton())
                  else if (snapshot.hasError)
                    SliverFillRemaining(
                      hasScrollBody: false,
                      child: AppStateView.error(
                        title: 'The catalogue is offline',
                        message:
                            'The store reads products directly from Firebase. '
                            'Check your connection and try again.',
                        onAction: _refresh,
                      ),
                    )
                  else ...[
                    SliverToBoxAdapter(
                     child:_Hero(
  onShop: _scrollToCollection,
),
                    ),
                    const SliverToBoxAdapter(child: _PillTicker()),
                    SliverToBoxAdapter(
                      child: _SearchAndFilter(
                        controller: _search,
                        query: _query,
                        category: _category,
                        sort: _sort,
                        onQuery: (value) => setState(() => _query = value),
                        onClear: () {
                          _search.clear();
                          setState(() => _query = '');
                        },
                        onCategory: (value) =>
                            setState(() => _category = value),
                        onSort: (value) => setState(() => _sort = value),
                      ),
                    ),
                    if (_query.isEmpty && _category == 'All' && all.isNotEmpty)
                      SliverToBoxAdapter(
                        child: _NewArrivals(
                          products: all.take(6).toList(growable: false),
                          onOpen: _openProduct,
                        ),
                      ),
                    const SliverToBoxAdapter(child: _AnnouncementStrip()),
                    SliverToBoxAdapter(
                      child: Container(
                        key: _collectionKey,
                        child: EditorialSectionHeader(
                          eyebrow: _category == 'All'
                              ? 'The full collection'
                              : 'Filtered selection',
                          title: _category == 'All'
                              ? 'Shop all pieces'
                              : _category,
                          accent: true,
                          trailing: Text(
                            '${products.length} '
                            '${products.length == 1 ? 'ITEM' : 'ITEMS'}',
                            style: const TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 1.6,
                              color: AppColors.muted,
                            ),
                          ),
                        ),
                      ),
                    ),
                    if (products.isEmpty)
                      SliverFillRemaining(
                        hasScrollBody: false,
                        child: all.isEmpty
                            ? AppStateView.empty(
                                icon: Icons.checkroom_outlined,
                                title: 'The first drop is loading',
                                message:
                                    'Active products added by the store will '
                                    'appear here automatically.',
                                actionLabel: 'Refresh catalogue',
                                onAction: _refresh,
                              )
                            : AppStateView.empty(
                                icon: Icons.search_off,
                                title: 'Nothing matches that',
                                message:
                                    'Try a different search, category, or '
                                    'clear the filters to see the full drop.',
                                actionLabel: 'Clear filters',
                                onAction: _resetFilters,
                              ),
                      )
                    else
                      SliverPadding(
                        padding: const EdgeInsets.fromLTRB(20, 0, 20, 30),
                        sliver: SliverGrid(
                          gridDelegate:
                              SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount:
                                    MediaQuery.sizeOf(context).width >= 760
                                    ? 3
                                    : 2,
                                crossAxisSpacing: 12,
                                mainAxisSpacing: 20,
                                childAspectRatio: 0.63,
                              ),
                          delegate: SliverChildBuilderDelegate((
                            context,
                            index,
                          ) {
                            final product = products[index];
                            return Reveal(
                              delay: Duration(milliseconds: (index % 6) * 40),
                              child: ProductCard(
                                product: product,
                                onTap: () => _openProduct(product),
                              ),
                            );
                          }, childCount: products.length),
                        ),
                      ),
                  ],
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _HeaderAction extends StatelessWidget {
  const _HeaderAction({
    required this.icon,
    required this.badge,
    required this.tooltip,
    required this.onPressed,
  });

  final IconData icon;
  final int badge;
  final String tooltip;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: tooltip,
      onPressed: onPressed,
      icon: Badge.count(
        count: badge,
        isLabelVisible: badge > 0,
        backgroundColor: AppColors.accent,
        textColor: Colors.white,
        smallSize: 14,
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: Icon(icon, size: 22),
      ),
    );
  }
}

/// Large editorial hero built from the first live product image.

/// Editorial hero carousel powered by active Firestore banners.
class _Hero extends StatefulWidget {
  const _Hero({required this.onShop});

  final VoidCallback onShop;

  @override
  State<_Hero> createState() => _HeroState();
}

class _HeroState extends State<_Hero> {
  final PageController _pageController = PageController();
  late final Stream<List<HeroBanner>> _bannerStream;
  int _currentPage = 0;

  static const _headlines = [
    'WEAR YOUR\nIDENTITY.',
    'MADE FOR\nTHE STREETS.',
    'OWN YOUR\nEVERYDAY.',
  ];

  static const _captions = [
    'Express yourself with streetwear made for everyday movement.',
    'A statement in every piece. Find your next everyday essential.',
    'Your style. Your rules. Discover the latest Unleashed collection.',
  ];

  @override
  void initState() {
    super.initState();
    _bannerStream = HeroBannerService.instance.watchActive();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<HeroBanner>>(
      stream: _bannerStream,
      builder: (context, snapshot) {
        final banners = snapshot.data ?? const <HeroBanner>[];
        final slideCount = banners.isEmpty ? 1 : banners.length;
        final currentPage = _currentPage.clamp(0, slideCount - 1);

        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 2, 20, 0),
          child: SizedBox(
            height: 462,
            child: ClipRect(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  PageView.builder(
                    controller: _pageController,
                    itemCount: slideCount,
                    onPageChanged: (index) {
                      setState(() => _currentPage = index);
                    },
                    itemBuilder: (context, index) {
                      final banner =
                          banners.isEmpty ? null : banners[index];

                      return _buildSlide(banner, index);
                    },
                  ),

                  Positioned(
                    left: 20,
                    right: 20,
                    bottom: 16,
                    child: Row(
                      children: [
                        Text(
                          '${(currentPage + 1).toString().padLeft(2, '0')}'
                          ' / ${slideCount.toString().padLeft(2, '0')}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 9,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.5,
                          ),
                        ),
                        const Spacer(),
                        Row(
                          children: List.generate(
                            slideCount,
                            (index) => AnimatedContainer(
                              duration: const Duration(milliseconds: 250),
                              margin: const EdgeInsets.only(left: 5),
                              width: currentPage == index ? 22 : 6,
                              height: 6,
                              decoration: BoxDecoration(
                                color: currentPage == index
                                    ? Colors.white
                                    : Colors.white.withValues(alpha: 0.4),
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildSlide(HeroBanner? banner, int index) {
    final headline = banner?.headline.isNotEmpty == true
        ? banner!.headline
        : _headlines[index % _headlines.length];

    final caption = banner?.caption.isNotEmpty == true
        ? banner!.caption
        : _captions[index % _captions.length];

    return Stack(
      fit: StackFit.expand,
      children: [
        if (banner != null)
          Image.network(
            banner.imageUrl,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) {
              return const ColoredBox(color: AppColors.charcoal);
            },
            loadingBuilder: (context, child, progress) {
              if (progress == null) return child;

              return const ColoredBox(color: AppColors.charcoal);
            },
          )
        else
          const ColoredBox(color: AppColors.charcoal),

        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: [
                AppColors.ink.withValues(alpha: 0.96),
                AppColors.ink.withValues(alpha: 0.72),
                AppColors.ink.withValues(alpha: 0.18),
              ],
              stops: const [0, 0.52, 1],
            ),
          ),
        ),

        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                AppColors.ink.withValues(alpha: 0.42),
                Colors.transparent,
                AppColors.ink.withValues(alpha: 0.5),
              ],
              stops: const [0, 0.45, 1],
            ),
          ),
        ),

        Padding(
          padding: const EdgeInsets.fromLTRB(20, 22, 20, 48),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const AccentMark(size: 6, color: Colors.white),
                  const SizedBox(width: 7),
                  Text(
                    'UNLEASHED · 2026',
                    style: TextStyle(
                      fontSize: 8.5,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 2.2,
                      color: Colors.white.withValues(alpha: 0.8),
                    ),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.35),
                      ),
                    ),
                    child: const Text(
                      'RIZAL',
                      style: TextStyle(
                        fontSize: 7.5,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.6,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),

              const Spacer(),

              Reveal(
                child: Text(
                  headline,
                  style: const TextStyle(
                    fontSize: 46,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -2.2,
                    height: 0.9,
                    color: Colors.white,
                  ),
                ),
              ),

              const SizedBox(height: 14),

              Text(
                caption,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12,
                  height: 1.55,
                  color: Colors.white.withValues(alpha: 0.76),
                ),
              ),

              const SizedBox(height: 22),

              SizedBox(
                width: 170,
                child: ElevatedButton(
                  onPressed: widget.onShop,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: AppColors.ink,
                    minimumSize: const Size.fromHeight(48),
                    shape: const RoundedRectangleBorder(),
                  ),
                  child: const Text('SHOP THE DROP'),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}


class _PillTicker extends StatelessWidget {
  const _PillTicker();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 4),
      child: Row(
        children: [
          const StatusDot(label: 'LIVE CATALOGUE'),
          const SizedBox(width: 14),
          Expanded(child: Container(height: 1, color: AppColors.line)),
          const SizedBox(width: 14),
          const Text(
            'T-SHIRT · CAP · HOODIE',
            style: TextStyle(
              fontSize: 7.5,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.4,
              color: AppColors.muted,
            ),
          ),
        ],
      ),
    );
  }
}

class _SearchAndFilter extends StatelessWidget {
  const _SearchAndFilter({
    required this.controller,
    required this.query,
    required this.category,
    required this.sort,
    required this.onQuery,
    required this.onClear,
    required this.onCategory,
    required this.onSort,
  });

  final TextEditingController controller;
  final String query;
  final String category;
  final _SortMode sort;
  final ValueChanged<String> onQuery;
  final VoidCallback onClear;
  final ValueChanged<String> onCategory;
  final ValueChanged<_SortMode> onSort;

  String get _sortLabel => switch (sort) {
    _SortMode.featured => 'FEATURED',
    _SortMode.priceLow => 'PRICE ↑',
    _SortMode.priceHigh => 'PRICE ↓',
    _SortMode.name => 'A–Z',
  };

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: controller,
            textInputAction: TextInputAction.search,
            onChanged: onQuery,
            style: const TextStyle(fontSize: 13),
            decoration: InputDecoration(
              hintText: 'Search the collection',
              prefixIcon: const Icon(Icons.search, size: 20),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 14,
              ),
              suffixIcon: query.isEmpty
                  ? null
                  : IconButton(
                      tooltip: 'Clear search',
                      onPressed: onClear,
                      icon: const Icon(Icons.close, size: 17),
                    ),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 34,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                for (final item in ['All', ...AppConfig.categories])
                  Padding(
                    padding: const EdgeInsets.only(right: 7),
                    child: OutlinePill(
                      label: item,
                      selected: category == item,
                      onTap: () => onCategory(item),
                    ),
                  ),
                PopupMenuButton<_SortMode>(
                  tooltip: 'Sort products',
                  onSelected: onSort,
                  itemBuilder: (context) => const [
                    PopupMenuItem(
                      value: _SortMode.featured,
                      child: Text('Featured order'),
                    ),
                    PopupMenuItem(
                      value: _SortMode.priceLow,
                      child: Text('Price: low to high'),
                    ),
                    PopupMenuItem(
                      value: _SortMode.priceHigh,
                      child: Text('Price: high to low'),
                    ),
                    PopupMenuItem(
                      value: _SortMode.name,
                      child: Text('Name: A to Z'),
                    ),
                  ],
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 13,
                      vertical: 7,
                    ),
                    decoration: BoxDecoration(
                      border: Border.all(color: AppColors.line),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.swap_vert, size: 14),
                        const SizedBox(width: 5),
                        Text(
                          _sortLabel,
                          style: const TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.1,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _NewArrivals extends StatelessWidget {
  const _NewArrivals({required this.products, required this.onOpen});

  final List<Product> products;
  final void Function(Product) onOpen;

  @override
  Widget build(BuildContext context) {
    if (products.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const EditorialSectionHeader(
          eyebrow: 'Just landed',
          title: 'New arrivals',
          accent: true,
          padding: EdgeInsets.fromLTRB(20, 26, 20, 12),
          trailing: Row(
            children: [
              Icon(Icons.arrow_outward, size: 14),
              SizedBox(width: 4),
              Text(
                'LIVE',
                style: TextStyle(
                  fontSize: 8.5,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.6,
                ),
              ),
            ],
          ),
        ),
        SizedBox(
          height: 270,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            itemCount: products.length,
            separatorBuilder: (_, _) => const SizedBox(width: 12),
            itemBuilder: (context, index) {
              final product = products[index];
              return SizedBox(
                width: 168,
                child: ProductCard(
                  product: product,
                  onTap: () => onOpen(product),
                  showStock: false,
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _AnnouncementStrip extends StatelessWidget {
  const _AnnouncementStrip();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Announcement>>(
      stream: AnnouncementService.instance.watchActive(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          debugPrint('ANNOUNCEMENT FIRESTORE ERROR: ${snapshot.error}');

          return Padding(
            padding: const EdgeInsets.all(20),
            child: Text(
              'Announcement error: ${snapshot.error}',
              style: const TextStyle(color: Colors.red),
            ),
          );
        }

        if (snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData) {
          debugPrint('ANNOUNCEMENTS: Loading...');
          return const SizedBox.shrink();
        }

        final announcements = snapshot.data ?? const <Announcement>[];

        debugPrint('ANNOUNCEMENTS LOADED: ${announcements.length}');

        if (announcements.isEmpty) {
          return const Padding(
            padding: EdgeInsets.all(20),
            child: Text('No active announcements found.'),
          );
        }
        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 28, 20, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  AccentMark(),
                  SizedBox(width: 7),
                  Eyebrow('From the store'),
                  Spacer(),
                  Text(
                    'PUBLIC',
                    style: TextStyle(
                      fontSize: 7.5,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.4,
                      color: AppColors.muted,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              for (var i = 0; i < announcements.take(3).length; i++)
                Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.fromLTRB(0, 0, 14, 0),
                  decoration: const BoxDecoration(
                    color: AppColors.surface,
                    border: Border(
                      left: BorderSide(color: AppColors.ink, width: 3),
                      top: BorderSide(color: AppColors.line),
                      right: BorderSide(color: AppColors.line),
                      bottom: BorderSide(color: AppColors.line),
                    ),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(14),
                        child: Text(
                          (i + 1).toString().padLeft(2, '0'),
                          style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1,
                            color: AppColors.muted,
                          ),
                        ),
                      ),
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 13),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                announcements[i].title.toUpperCase(),
                                style: const TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.3,
                                  height: 1.3,
                                ),
                              ),
                              if (announcements[i].body.isNotEmpty) ...[
                                const SizedBox(height: 4),
                                Text(
                                  announcements[i].body,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 11,
                                    height: 1.45,
                                    color: AppColors.muted,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                      if (announcements[i].pinned)
                        const Align(
                          alignment: Alignment.topRight,
                          child: Padding(
                            padding: EdgeInsets.only(top: 13),
                            child: Icon(Icons.push_pin, size: 13),
                          ),
                        ),
                    ],
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _HomeSkeleton extends StatelessWidget {
  const _HomeSkeleton();

  @override
  Widget build(BuildContext context) {
    return const Column(
      children: [
        Padding(
          padding: EdgeInsets.fromLTRB(20, 2, 20, 0),
          child: SkeletonBox(height: 462),
        ),
        SizedBox(height: 20),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 20),
          child: SkeletonBox(height: 50),
        ),
        ProductGridSkeleton(count: 2),
      ],
    );
  }
}
