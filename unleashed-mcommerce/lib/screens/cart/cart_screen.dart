import 'package:flutter/material.dart';

import '../../core/app_theme.dart';
import '../../core/formatters.dart';
import '../../models/cart_item.dart';
import '../../models/cart_selection.dart';
import '../../models/product.dart';
import '../../services/cart_service.dart';
import '../../services/guest_cart_service.dart';
import '../../services/product_service.dart';
import '../../state/app_state.dart';
import '../../widgets/common.dart';
import '../../widgets/editorial.dart';
import '../../widgets/product_image.dart';
import '../../widgets/quantity_stepper.dart';
import '../checkout/checkout_screen.dart';
import '../shell/main_shell.dart';

class CartScreen extends StatefulWidget {
  const CartScreen({super.key});

  @override
  State<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends State<CartScreen> {
  final CartSelection _selection = CartSelection();
  Map<String, Product> _catalog = {};
  StoreSettings _settings = const StoreSettings();
  bool _catalogLoading = true;
  String? _catalogError;
  String? _busyItemId;
  bool _clearing = false;
  bool _removingSelected = false;
  bool _refreshingPrices = false;

  @override
  void initState() {
    super.initState();
    _loadCatalog();
  }

  Future<void> _loadCatalog() async {
    setState(() {
      _catalogLoading = true;
      _catalogError = null;
    });
    try {
      final products = await ProductService.instance.fetchActiveProducts();
      final settings = await ProductService.instance.loadStoreSettings();
      if (!mounted) return;
      setState(() {
        _catalog = {for (final product in products) product.id: product};
        _settings = settings;
        _catalogLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _catalogLoading = false;
        _catalogError =
            'Stock and prices could not be checked. Pull to retry before '
            'checking out.';
      });
    }
  }

  String? _issueFor(CartItem item) {
    final product = _catalog[item.productId];
    if (product == null || !product.isActive) return 'No longer available';
    final stock = product.stockFor(item.size);
    if (stock <= 0) return 'Out of stock';
    if (item.quantity > stock) return 'Only $stock left';
    if (product.price != item.price) return 'Price has changed';
    return null;
  }

  /// Brings stored cart lines in line with the current catalog price without
  /// changing quantities. `CartService.setQuantity` re-reads the product and
  /// writes the current price, name and image together, so this is a safe,
  /// explicit recovery path when an administrator changes a price.
  Future<void> _syncPrices(List<CartItem> items) async {
    final uid = AppState.instance.user?.uid;
    if (uid == null) {
      final updated = await GuestCartService.instance.syncPrices(_catalog);
      if (!mounted) return;
      showAppSnack(
        context,
        updated == 0
            ? 'No cart prices can be updated automatically. Remove unavailable '
                  'items or adjust quantities first.'
            : '$updated cart price${updated == 1 ? '' : 's'} updated.',
        error: updated == 0,
      );
      return;
    }
    final stale = items.where((item) {
      final product = _catalog[item.productId];
      return product != null &&
          product.isActive &&
          product.price != item.price &&
          item.quantity <= product.stockFor(item.size);
    }).toList();
    if (stale.isEmpty) {
      showAppSnack(
        context,
        'No cart prices can be updated automatically. Remove unavailable '
        'items or adjust quantities first.',
        error: true,
      );
      return;
    }
    setState(() => _refreshingPrices = true);
    try {
      for (final item in stale) {
        await CartService.instance.setQuantity(
          uid: uid,
          item: item,
          quantity: item.quantity,
        );
      }
      if (mounted) {
        showAppSnack(
          context,
          '${stale.length} cart price${stale.length == 1 ? '' : 's'} updated.',
        );
      }
    } on CartFailure catch (error) {
      if (mounted) showAppSnack(context, error.message, error: true);
    } catch (_) {
      if (mounted) {
        showAppSnack(
          context,
          'Cart prices could not be updated. Please try again.',
          error: true,
        );
      }
    } finally {
      if (mounted) setState(() => _refreshingPrices = false);
    }
  }

  Future<void> _updateQuantity(CartItem item, int quantity) async {
    final uid = AppState.instance.user?.uid;
    setState(() => _busyItemId = item.id);
    try {
      if (uid == null) {
        await GuestCartService.instance.setQuantity(
          item: item,
          quantity: quantity,
          product: _catalog[item.productId],
        );
      } else {
        await CartService.instance.setQuantity(
          uid: uid,
          item: item,
          quantity: quantity,
        );
      }
    } on CartFailure catch (error) {
      if (mounted) showAppSnack(context, error.message, error: true);
    } catch (_) {
      if (mounted) {
        showAppSnack(
          context,
          'The quantity could not be updated. Please try again.',
          error: true,
        );
      }
    } finally {
      if (mounted) setState(() => _busyItemId = null);
    }
  }

  Future<void> _remove(CartItem item) async {
    final uid = AppState.instance.user?.uid;
    final confirmed = await confirmAction(
      context,
      title: 'Remove item?',
      message: 'Remove ${item.name} (size ${item.size}) from your cart?',
      confirmLabel: 'Remove',
      destructive: true,
    );
    if (!confirmed) return;
    try {
      if (uid == null) {
        await GuestCartService.instance.removeItem(item.id);
      } else {
        await CartService.instance.removeItem(uid: uid, itemId: item.id);
      }
      _selection.forget(item.id);
      if (mounted) showAppSnack(context, '${item.name} removed.');
    } catch (_) {
      if (mounted) {
        showAppSnack(context, 'That item could not be removed.', error: true);
      }
    }
  }

  Future<void> _removeSelected(List<CartItem> selected) async {
    if (selected.isEmpty || _removingSelected) return;
    final confirmed = await confirmAction(
      context,
      title: 'Remove selected items?',
      message:
          'This removes ${selected.length} selected '
          '${selected.length == 1 ? 'line' : 'lines'} from your cart. '
          'Unselected items stay.',
      confirmLabel: 'Remove selected',
      destructive: true,
    );
    if (!confirmed || !mounted) return;

    final ids = selected.map((item) => item.id).toList(growable: false);
    final uid = AppState.instance.user?.uid;
    setState(() => _removingSelected = true);
    try {
      if (uid == null) {
        await GuestCartService.instance.removeItems(ids);
      } else {
        await CartService.instance.removeItems(uid: uid, itemIds: ids);
      }
      for (final id in ids) {
        _selection.forget(id);
      }
      if (mounted) {
        showAppSnack(
          context,
          '${ids.length} ${ids.length == 1 ? 'item' : 'items'} removed.',
        );
      }
    } catch (_) {
      if (mounted) {
        showAppSnack(
          context,
          'The selected items could not be removed.',
          error: true,
        );
      }
    } finally {
      if (mounted) setState(() => _removingSelected = false);
    }
  }

  Future<void> _clear(CartItem first, int count) async {
    final uid = AppState.instance.user?.uid;
    final confirmed = await confirmAction(
      context,
      title: 'Clear cart?',
      message:
          'This removes all $count item${count == 1 ? '' : 's'} from your cart.',
      confirmLabel: 'Clear cart',
      destructive: true,
    );
    if (!confirmed) return;
    setState(() => _clearing = true);
    try {
      if (uid == null) {
        await GuestCartService.instance.clear();
      } else {
        await CartService.instance.clearCart(uid);
      }
      _selection.reset();
      if (mounted) showAppSnack(context, 'Your cart is empty.');
    } catch (_) {
      if (mounted) {
        showAppSnack(context, 'The cart could not be cleared.', error: true);
      }
    } finally {
      if (mounted) setState(() => _clearing = false);
    }
  }

  void _continueShopping() {
    final scope = ShellScope.maybeOf(context);
    if (scope != null) {
      scope.selectTab(ShellTab.home);
    } else {
      Navigator.of(context).maybePop();
    }
  }

  int _shippingFor(int subtotal) {
    final fee = _settings.shippingFee;
    final threshold = _settings.freeShippingThreshold;
    if (threshold != null && subtotal >= threshold) return 0;
    return fee;
  }

  @override
  Widget build(BuildContext context) {
    return AppStateBuilder(
      builder: (context, state) {
        final uid = state.user?.uid;

        // Guests read the cart from local storage so browsing and cart
        // maintenance never trigger a sign-in prompt.
        if (uid == null) {
          return _cartScaffold(context, state.guestCartItems, guest: true);
        }

        return StreamBuilder<List<CartItem>>(
          stream: CartService.instance.watchCart(uid),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return Scaffold(
                appBar: AppBar(title: const Text('YOUR CART')),
                body: const AppStateView.loading(message: 'Loading your cart…'),
              );
            }
            if (snapshot.hasError) {
              return Scaffold(
                appBar: AppBar(title: const Text('YOUR CART')),
                body: AppStateView.error(
                  title: 'Could not load your cart',
                  message: 'Check your connection and try again.',
                  onAction: _loadCatalog,
                ),
              );
            }
            return _cartScaffold(
              context,
              snapshot.data ?? const <CartItem>[],
              guest: false,
            );
          },
        );
      },
    );
  }

  Widget _cartScaffold(
    BuildContext context,
    List<CartItem> items, {
    required bool guest,
  }) {
    final issues = <String, String>{
      for (final item in items)
        if (_issueFor(item) != null) item.id: _issueFor(item)!,
    };
    final priceChanges = items.where((item) {
      final product = _catalog[item.productId];
      return product != null && product.isActive && product.price != item.price;
    }).toList();
    final selectedItems = _selection.selected(items);
    final selectedIssues = <String, String>{
      for (final item in selectedItems)
        if (_issueFor(item) != null) item.id: _issueFor(item)!,
    };
    final selectedSubtotal = selectedItems.fold<int>(
      0,
      (total, item) => total + item.subtotal,
    );
    final selectedCount = selectedItems.fold<int>(
      0,
      (total, item) => total + item.quantity,
    );
    final shipping = selectedItems.isEmpty ? 0 : _shippingFor(selectedSubtotal);
    final total = selectedSubtotal + shipping;
    final count = CartService.instance.cartCount(items);
    final allSelected =
        items.isNotEmpty && selectedItems.length == items.length;
    final selectionEmpty = selectedItems.isEmpty;
    final blocked =
        selectionEmpty ||
        _removingSelected ||
        _catalogLoading ||
        _catalogError != null ||
        _refreshingPrices ||
        selectedIssues.isNotEmpty;
    final checkoutLabel = selectionEmpty
        ? 'Select items to checkout'
        : _removingSelected
        ? 'Removing…'
        : _catalogLoading
        ? 'Checking stock…'
        : _catalogError != null
        ? 'Retry cart check'
        : _refreshingPrices
        ? 'Updating prices…'
        : selectedIssues.isNotEmpty
        ? 'Resolve selected issues'
        : guest
        ? 'Sign in to checkout'
        : 'Checkout';

    return Scaffold(
      backgroundColor: AppColors.paper,
      appBar: AppBar(
        title: const Text('YOUR CART'),
        actions: [
          if (items.isNotEmpty)
            TextButton(
              onPressed: _clearing ? null : () => _clear(items.first, count),
              child: const Text('CLEAR'),
            ),
          const SizedBox(width: 6),
        ],
      ),
      body: items.isEmpty
          ? AppStateView.empty(
              icon: Icons.shopping_bag_outlined,
              title: 'Your cart is empty',
              message: 'Add a tee and it will appear here.',
              actionLabel: 'Start shopping',
              onAction: _continueShopping,
            )
          : RefreshIndicator(
              onRefresh: _loadCatalog,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                children: [
                  if (guest)
                    const Padding(
                      padding: EdgeInsets.only(bottom: 12),
                      child: _GuestCartNotice(),
                    ),
                  _CartSelectionBar(
                    allSelected: allSelected,
                    selectedLines: selectedItems.length,
                    selectedCount: selectedCount,
                    busy: _removingSelected,
                    onToggleAll: () => setState(() {
                      if (allSelected) {
                        _selection.clearAll(items);
                      } else {
                        _selection.selectAll(items);
                      }
                    }),
                    onRemoveSelected: selectionEmpty
                        ? null
                        : () => _removeSelected(selectedItems),
                  ),
                  const SizedBox(height: 12),
                  if (_catalogLoading)
                    const Padding(
                      padding: EdgeInsets.only(bottom: 12),
                      child: LinearProgressIndicator(minHeight: 2),
                    ),
                  if (_catalogError != null)
                    _CartNotice(
                      message: _catalogError!,
                      actionLabel: 'Retry',
                      onAction: _loadCatalog,
                    ),
                  if (!_catalogLoading &&
                      _catalogError == null &&
                      issues.isNotEmpty)
                    _CartNotice(
                      message: selectedIssues.isNotEmpty
                          ? priceChanges.isNotEmpty
                                ? 'Some selected prices changed while you '
                                      'were shopping. Update prices to '
                                      'continue, or adjust the items flagged '
                                      'below.'
                                : 'Some selected items need attention before '
                                      'checkout. Remove unavailable items or '
                                      'update quantities.'
                          : 'Some unchecked items need attention. You can '
                                'check out the selected items; fix or remove '
                                'the flagged items whenever you like.',
                      actionLabel: priceChanges.isNotEmpty
                          ? (_refreshingPrices ? 'Updating…' : 'Update prices')
                          : 'Refresh cart',
                      onAction: priceChanges.isNotEmpty
                          ? () => _syncPrices(items)
                          : _loadCatalog,
                    ),
                  for (final item in items)
                    _CartRow(
                      item: item,
                      product: _catalog[item.productId],
                      issue: issues[item.id],
                      busy: _busyItemId == item.id,
                      selected: _selection.isSelected(item),
                      onSelectedChanged: (value) =>
                          setState(() => _selection.setSelected(item, value)),
                      onQuantityChanged: (value) =>
                          _updateQuantity(item, value),
                      onRemove: () => _remove(item),
                    ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: const BoxDecoration(
                      color: AppColors.ink,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            AccentMark(size: 6, color: Colors.white),
                            SizedBox(width: 7),
                            Eyebrow(
                              'Order summary',
                              color: Colors.white70,
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        KeyValueRow(
                          'Subtotal ($selectedCount selected)',
                          formatMoney(selectedSubtotal),
                          valueColor: Colors.white,
                        ),
                        KeyValueRow(
                          'Shipping',
                          selectedItems.isEmpty
                              ? '—'
                              : shipping == 0
                              ? 'Free'
                              : formatMoney(shipping),
                          valueColor: selectedItems.isNotEmpty && shipping == 0
                              ? const Color(0xFF8FD9A8)
                              : Colors.white,
                        ),
                        Container(
                          height: 1,
                          margin: const EdgeInsets.symmetric(vertical: 10),
                          color: Colors.white.withValues(alpha: 0.18),
                        ),
                        KeyValueRow(
                          'Total',
                          formatMoney(total),
                          strong: true,
                          valueColor: Colors.white,
                        ),
                        const SizedBox(height: 10),
                        Text(
                          guest
                              ? 'Prices and stock are checked again when '
                                    'you sign in to place the order. Only '
                                    'selected items are ordered; unchecked '
                                    'items stay in your cart.'
                              : 'Final stock, prices and shipping are '
                                    're-verified when the order is placed. '
                                    'Only selected items are ordered; the '
                                    'rest stay in your cart.',
                          style: TextStyle(
                            fontSize: 10.5,
                            height: 1.45,
                            color: Colors.white.withValues(alpha: 0.6),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
      bottomNavigationBar: items.isEmpty
          ? null
          : Container(
              decoration: const BoxDecoration(
                color: AppColors.surface,
                border: Border(top: BorderSide(color: AppColors.ink)),
              ),
              child: SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                  child: Row(
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Eyebrow(
                            selectionEmpty
                                ? 'Total'
                                : 'Total · $selectedCount '
                                      '${selectedCount == 1 ? 'item' : 'items'}',
                          ),
                          const SizedBox(height: 3),
                          Text(
                            formatMoney(total),
                            style: const TextStyle(
                              fontSize: 19,
                              fontWeight: FontWeight.w900,
                              letterSpacing: -0.6,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: PrimaryButton(
                          label: checkoutLabel,
                          accent: !blocked,
                          icon: blocked ? null : Icons.arrow_forward,
                          onPressed: blocked
                              ? null
                              : () {
                                  if (guest) {
                                    AppState.instance.requestSignIn(
                                      pendingCheckout: selectedItems,
                                      message:
                                          'Sign in or create an account to '
                                          'place your order. Your selected '
                                          'items and guest cart are saved on '
                                          'this device and will follow you.',
                                    );
                                    return;
                                  }
                                  Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder: (_) => CheckoutScreen(
                                        items: selectedItems,
                                        settings: _settings,
                                      ),
                                    ),
                                  );
                                },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
    );
  }
}

class _CartSelectionBar extends StatelessWidget {
  const _CartSelectionBar({
    required this.allSelected,
    required this.selectedLines,
    required this.selectedCount,
    required this.busy,
    required this.onToggleAll,
    required this.onRemoveSelected,
  });

  final bool allSelected;
  final int selectedLines;
  final int selectedCount;
  final bool busy;
  final VoidCallback onToggleAll;
  final VoidCallback? onRemoveSelected;

  @override
  Widget build(BuildContext context) {
    final none = selectedLines == 0;
    return Container(
      padding: const EdgeInsets.fromLTRB(6, 4, 8, 4),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border.all(color: AppColors.line),
      ),
      child: Row(
        children: [
          Checkbox(
            value: allSelected ? true : (none ? false : null),
            tristate: true,
            onChanged: busy ? null : (_) => onToggleAll(),
            visualDensity: VisualDensity.compact,
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
          const SizedBox(width: 4),
          Expanded(
            child: GestureDetector(
              onTap: busy ? null : onToggleAll,
              child: const Text(
                'SELECT ALL',
                style: TextStyle(
                  fontSize: 9.5,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.3,
                ),
              ),
            ),
          ),
          Text(
            none
                ? 'NONE SELECTED'
                : allSelected
                ? 'ALL SELECTED'
                : '$selectedCount SELECTED',
            style: const TextStyle(
              fontSize: 8,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.1,
              color: AppColors.muted,
            ),
          ),
          if (onRemoveSelected != null) ...[
            const SizedBox(width: 4),
            TextButton(
              onPressed: busy ? null : onRemoveSelected,
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                minimumSize: const Size(0, 32),
                foregroundColor: AppColors.accent,
                textStyle: const TextStyle(
                  fontSize: 9.5,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.1,
                ),
              ),
              child: Text(busy ? 'REMOVING…' : 'REMOVE'),
            ),
          ],
        ],
      ),
    );
  }
}

class _GuestCartNotice extends StatelessWidget {
  const _GuestCartNotice();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        color: AppColors.surfaceAlt,
        border: Border.all(color: AppColors.line),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.person_outline, size: 17),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              'Shopping as a guest. Your cart stays on this device and will '
              'move to your account when you sign in.',
              style: TextStyle(fontSize: 11.5, height: 1.45),
            ),
          ),
        ],
      ),
    );
  }
}

class _CartRow extends StatelessWidget {
  const _CartRow({
    required this.item,
    required this.product,
    required this.issue,
    required this.busy,
    required this.selected,
    required this.onSelectedChanged,
    required this.onQuantityChanged,
    required this.onRemove,
  });

  final CartItem item;
  final Product? product;
  final String? issue;
  final bool busy;
  final bool selected;
  final ValueChanged<bool> onSelectedChanged;
  final ValueChanged<int> onQuantityChanged;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final maxQuantity = product == null
        ? 20
        : (product!.stockFor(item.size) > 20
              ? 20
              : (product!.stockFor(item.size) < 1
                    ? 1
                    : product!.stockFor(item.size)));
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border.all(
          color: selected ? AppColors.ink : AppColors.line,
          width: selected ? 1.4 : 1,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(2, 8, 0, 8),
            child: Checkbox(
              value: selected,
              onChanged: busy
                  ? null
                  : (value) => onSelectedChanged(value ?? false),
              visualDensity: VisualDensity.compact,
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          ),
          SizedBox(
            width: 86,
            height: 116,
            child: ProductImage(
              imageId: item.imageId ?? product?.imageId,
              version: product?.imageUpdatedAt?.millisecondsSinceEpoch,
              iconSize: 26,
              showLabel: false,
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 10, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          item.name.toUpperCase(),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -0.1,
                            height: 1.25,
                          ),
                        ),
                      ),
                      InkWell(
                        onTap: busy ? null : onRemove,
                        child: const Padding(
                          padding: EdgeInsets.all(2),
                          child: Icon(
                            Icons.close,
                            size: 15,
                            color: AppColors.muted,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'SIZE ${item.size.toUpperCase()}',
                    style: const TextStyle(
                      fontSize: 8,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.3,
                      color: AppColors.muted,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    item.priceLabel,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  if (issue != null) ...[
                    const SizedBox(height: 5),
                    Text(
                      issue!.toUpperCase(),
                      style: const TextStyle(
                        fontSize: 8,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.9,
                        color: AppColors.accent,
                      ),
                    ),
                  ],
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      QuantityStepper(
                        value: item.quantity,
                        min: 1,
                        max: maxQuantity,
                        compact: true,
                        enabled: !busy,
                        onChanged: onQuantityChanged,
                      ),
                      const Spacer(),
                      Text(
                        formatMoney(item.subtotal),
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: AppColors.muted,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CartNotice extends StatelessWidget {
  const _CartNotice({
    required this.message,
    required this.actionLabel,
    required this.onAction,
  });

  final String message;
  final String actionLabel;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
      decoration: BoxDecoration(
        color: const Color(0xFFFBF1DE),
        border: Border.all(color: AppColors.warning.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.warning_amber_rounded,
            size: 17,
            color: AppColors.warning,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                fontSize: 11.5,
                height: 1.45,
                color: AppColors.warning,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          TextButton(
            onPressed: onAction,
            style: TextButton.styleFrom(
              foregroundColor: AppColors.warning,
              textStyle: const TextStyle(
                fontSize: 9.5,
                fontWeight: FontWeight.w900,
                letterSpacing: 0.9,
              ),
            ),
            child: Text(actionLabel.toUpperCase()),
          ),
        ],
      ),
    );
  }
}
