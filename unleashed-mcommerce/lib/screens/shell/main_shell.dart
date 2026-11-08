import 'package:flutter/material.dart';

import '../../core/app_theme.dart';
import '../../services/cart_service.dart';
import '../../services/product_service.dart';
import '../../state/app_state.dart';
import '../../state/shell_tabs.dart';
import '../../widgets/common.dart';
import '../cart/cart_screen.dart';
import '../catalog/home_screen.dart';
import '../checkout/checkout_screen.dart';
import '../notifications/notifications_screen.dart';
import '../orders/orders_screen.dart';
import '../profile/profile_screen.dart';

class ShellTab {
  static const int home = 0;
  static const int orders = 1;
  static const int cart = 2;
  static const int notifications = 3;
  static const int profile = 4;
}

/// Lets any descendant switch the main tab (for example, an empty cart's
/// "Start shopping" button).
class ShellScope extends InheritedWidget {
  const ShellScope({super.key, required this.selectTab, required super.child});

  final ValueChanged<int> selectTab;

  static ShellScope? maybeOf(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<ShellScope>();
  }

  static void goTo(BuildContext context, int tab) {
    maybeOf(context)?.selectTab(tab);
  }

  @override
  bool updateShouldNotify(ShellScope oldWidget) => false;
}

class MainShell extends StatefulWidget {
  const MainShell({super.key, this.initialTab = ShellTab.home});

  final int initialTab;

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  late int _index = widget.initialTab;

  @override
  void initState() {
    super.initState();
    ShellTabs.request.addListener(_handleTabRequest);
    WidgetsBinding.instance.addPostFrameCallback((_) => _afterAuth());
  }

  /// Shows a one-off cart-merge message and resumes the checkout a guest
  /// started before signing in. The account cart is re-read so checkout never
  /// uses stale local prices or a partially merged cart.
  Future<void> _afterAuth() async {
    final mergeMessage = AppState.instance.takeMergeMessage();
    if (mergeMessage != null && mounted) {
      showAppSnack(context, mergeMessage);
    }

    final pending = AppState.instance.peekPendingCheckout();
    if (pending == null) return;

    // The guest chose specific lines. Remember which ones so the checkout is
    // reopened with those lines only after the cart merge.
    final pendingIds = pending.map((item) => item.id).toSet();
    await AppState.instance.cartMergeFuture;
    if (!mounted) return;

    final items = AppState.instance.consumePendingCheckout();
    final uid = AppState.instance.user?.uid;
    if (items == null || uid == null) return;

    try {
      final settings = await ProductService.instance.loadStoreSettings();
      final cart = await CartService.instance.fetchCart(uid);
      // Use the merged account lines so quantities and prices reflect the
      // current catalogue, but keep only the lines the guest selected.
      final selected = cart
          .where((line) => pendingIds.contains(line.id))
          .toList(growable: false);
      if (!mounted) return;
      if (selected.isEmpty) {
        showAppSnack(
          context,
          'Your selected cart items are no longer available. Open your cart '
          'to review the remaining items.',
          error: true,
        );
        return;
      }
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => CheckoutScreen(items: selected, settings: settings),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      showAppSnack(
        context,
        'Checkout could not be reopened. Open your cart to continue.',
        error: true,
      );
    }
  }

  @override
  void dispose() {
    ShellTabs.request.removeListener(_handleTabRequest);
    super.dispose();
  }

  void _handleTabRequest() {
    if (mounted) _selectTab(ShellTabs.request.value);
  }

  void _selectTab(int index) {
    if (index == _index) return;
    setState(() => _index = index);
  }

  @override
  Widget build(BuildContext context) {
    return AppStateBuilder(
      builder: (context, state) {
        return Scaffold(
          backgroundColor: AppColors.paper,
          body: ShellScope(
            selectTab: _selectTab,
            child: IndexedStack(
              index: _index,
              children: const [
                HomeScreen(),
                OrdersScreen(),
                CartScreen(),
                NotificationsScreen(),
                ProfileScreen(),
              ],
            ),
          ),
          bottomNavigationBar: _EditorialNavBar(
            index: _index,
            cartCount: state.cartCount,
            notificationCount: state.unreadNotifications,
            onSelect: _selectTab,
          ),
        );
      },
    );
  }
}

class _EditorialNavBar extends StatelessWidget {
  const _EditorialNavBar({
    required this.index,
    required this.cartCount,
    required this.notificationCount,
    required this.onSelect,
  });

  final int index;
  final int cartCount;
  final int notificationCount;
  final ValueChanged<int> onSelect;

  static const _items = [
    (Icons.storefront_outlined, Icons.storefront, 'SHOP', 0),
    (Icons.receipt_long_outlined, Icons.receipt_long, 'ORDERS', 0),
    (Icons.shopping_bag_outlined, Icons.shopping_bag, 'CART', 0),
    (Icons.notifications_none, Icons.notifications, 'ALERTS', 0),
    (Icons.person_outline, Icons.person, 'PROFILE', 0),
  ];

  int _badgeFor(int tab) {
    if (tab == ShellTab.cart) return cartCount;
    if (tab == ShellTab.notifications) return notificationCount;
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.ink, width: 1)),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 62,
          child: Row(
            children: [
              for (var i = 0; i < _items.length; i++)
                Expanded(
                  child: _NavItem(
                    icon: _items[i].$1,
                    activeIcon: _items[i].$2,
                    label: _items[i].$3,
                    selected: index == i,
                    badge: _badgeFor(i),
                    onTap: () => onSelect(i),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.selected,
    required this.badge,
    required this.onTap,
  });

  final IconData icon;
  final IconData activeIcon;
  final String label;
  final bool selected;
  final int badge;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      splashColor: AppColors.ink.withValues(alpha: 0.04),
      highlightColor: Colors.transparent,
      child: Stack(
        alignment: Alignment.topCenter,
        children: [
          AnimatedContainer(
            duration: AppMotion.fast,
            height: 2,
            width: selected ? 26 : 0,
            margin: const EdgeInsets.only(bottom: 8),
            color: selected ? AppColors.accent : Colors.transparent,
          ),
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Badge.count(
                  count: badge,
                  isLabelVisible: badge > 0,
                  backgroundColor: AppColors.accent,
                  textColor: Colors.white,
                  smallSize: 8,
                  child: Icon(
                    selected ? activeIcon : icon,
                    size: 21,
                    color: selected ? AppColors.ink : AppColors.warmGray,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 7.5,
                    fontWeight: selected ? FontWeight.w900 : FontWeight.w700,
                    letterSpacing: 1.2,
                    color: selected ? AppColors.ink : AppColors.warmGray,
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
