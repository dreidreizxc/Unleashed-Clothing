import 'package:flutter/material.dart';

import '../../core/app_theme.dart';
import '../../core/formatters.dart';
import '../../models/cart_item.dart';
import '../../models/user_profile.dart';
import '../../services/order_service.dart';
import '../../services/product_service.dart';
import '../../state/app_state.dart';
import '../../widgets/common.dart';
import '../../widgets/editorial.dart';
import '../../widgets/product_image.dart';
import '../profile/edit_profile_screen.dart';
import 'order_success_screen.dart';
import 'payment_simulation_screen.dart';

class CheckoutScreen extends StatefulWidget {
  const CheckoutScreen({
    super.key,
    required this.items,
    required this.settings,
  });

  final List<CartItem> items;
  final StoreSettings settings;

  @override
  State<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen> {
  final _note = TextEditingController();
  String _method = 'COD';
  late final String _clientOrderId;
  bool _placing = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final uid = AppState.instance.user?.uid ?? 'guest';
    _clientOrderId = OrderService.instance.newClientOrderId(uid);
  }

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  int get _subtotal =>
      widget.items.fold<int>(0, (sum, item) => sum + item.subtotal);

  int get _shipping {
    final threshold = widget.settings.freeShippingThreshold;
    if (threshold != null && _subtotal >= threshold) return 0;
    return widget.settings.shippingFee;
  }

  int get _total => _subtotal + _shipping;

  bool get _simulated => _method != 'COD';

  Future<void> _editAddress() async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const EditProfileScreen()),
    );
  }

  Future<void> _place(UserProfile profile) async {
    if (_placing) return;
    FocusScope.of(context).unfocus();

    final state = AppState.instance;
    if (state.user == null) {
      setState(
        () => _error = 'Please sign in again before placing this order.',
      );
      state.requestSignIn(
        message: 'Sign in to finish your order. Your cart is still saved.',
      );
      return;
    }
    if (state.user!.uid != profile.uid) {
      setState(
        () => _error = 'Your session changed. Please sign in again.',
      );
      return;
    }

    if (!profile.address.isComplete) {
      showAppSnack(
        context,
        'Complete your delivery address before placing an order.',
        error: true,
      );
      return;
    }

    if (_simulated) {
      final completed = await Navigator.of(context).push<bool>(
        MaterialPageRoute(
          builder: (_) => PaymentSimulationScreen(
            method: _method,
            amount: _total,
          ),
        ),
      );
      if (completed != true) {
        if (mounted) {
          showAppSnack(
            context,
            completed == false
                ? 'Simulated payment did not complete. No request was sent.'
                : 'Payment simulation closed. No request was sent.',
            error: true,
          );
        }
        return;
      }
    } else {
      final confirmed = await confirmAction(
        context,
      title: 'Place order?',
        message:
            'You are requesting ${formatMoney(_total)} worth of items. The '
            'store will verify the current prices and stock before '
            'confirming. Payment stays unpaid until then, and you can cancel '
            'while the request is still awaiting confirmation.',
        confirmLabel: 'Send request',
      );
      if (!confirmed) return;
    }

    if (!mounted) return;
    setState(() {
      _placing = true;
      _error = null;
    });

    try {
      final result = await OrderService.instance.submitOrderRequest(
        profile: profile,
        items: widget.items,
        paymentMethod: _method,
        clientOrderId: _clientOrderId,
        customerNote: _note.text,
      );
      if (!mounted) return;
      setState(() => _placing = false);
      _openSuccess(result);
    } on DuplicateOrderFailure {
      // The request reached Firestore but the response was lost. Opening the
      // existing request is safer than creating a second one.
      try {
        final existing = await OrderService.instance.fetchOrder(_clientOrderId);
        if (!mounted) return;
        setState(() => _placing = false);
        if (existing != null) {
          _openSuccess(
            OrderRequestResult(
              orderId: existing.id,
              requestedTotal: existing.requestedTotalValue,
              itemCount: existing.itemCount,
              paymentMethod: existing.paymentMethod,
              requestReference: existing.requestReference ?? '',
            ),
          );
          return;
        }
      } catch (_) {
        // Fall through to the friendly message below.
      }
      if (mounted) {
        setState(() {
          _placing = false;
          _error =
              'This request was already submitted. Open your orders to view it.';
        });
      }
    } on OrderFailure catch (error) {
      if (mounted) {
        setState(() {
          _placing = false;
          _error = error.message;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _placing = false;
          _error =
              'Checkout could not be completed. Your cart has not been '
              'cleared. Please try again.';
        });
      }
    }
  }

  void _openSuccess(OrderRequestResult result) {
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(
        builder: (_) => OrderSuccessScreen(
          result: result,
          paymentMethod: _method,
          simulated: _simulated,
        ),
      ),
      (route) => route.isFirst,
    );
  }

  @override
  Widget build(BuildContext context) {
    return AppStateBuilder(
      builder: (context, state) {
        final profile = state.profile;
        final addressComplete = profile?.address.isComplete ?? false;

        // Checkout is an authenticated, verified action. AuthGate normally
        // prevents this screen from being reached otherwise, but the guard is
        // repeated here because the rules are the real enforcement point.
        if (state.user == null) {
          return Scaffold(
            backgroundColor: AppColors.paper,
            appBar: AppBar(title: const Text('CHECKOUT')),
            body: AppStateView.empty(
              icon: Icons.lock_outline,
              title: 'Sign in to check out',
              message:
                  'Your guest cart is saved on this device. Sign in or create '
                  'an account to place the order.',
              actionLabel: 'Sign in',
              onAction: () => state.requestSignIn(
                message:
                    'Sign in to finish your order. Your cart is still saved.',
              ),
            ),
          );
        }

        final blocked =
            _placing ||
            profile == null ||
            widget.items.isEmpty ||
            !addressComplete;

        return Scaffold(
          backgroundColor: AppColors.paper,
          appBar: AppBar(title: const Text('CHECKOUT')),
          body: profile == null
              ? AppStateView.error(
                  title: 'Your profile is not ready',
                  message:
                      'We need your delivery details before checkout. '
                      'Pull to refresh your profile or sign in again.',
                  actionLabel: 'Refresh profile',
                  onAction: state.refreshProfile,
                )
              : ListView(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
                  children: [
                    if (_error != null) _CheckoutError(message: _error!),
                    const _CheckoutIntro(),
                    _SectionCard(
                      title: 'Delivery address',
                      onEdit: _editAddress,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            profile.fullName,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            profile.contactNumber,
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.muted,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            addressComplete
                                ? profile.address.singleLine
                                : 'Your delivery address is incomplete.',
                            style: TextStyle(
                              fontSize: 13,
                              height: 1.5,
                              color: addressComplete
                                  ? AppColors.ink
                                  : AppColors.danger,
                              fontWeight: addressComplete
                                  ? FontWeight.w500
                                  : FontWeight.w700,
                            ),
                          ),
                          if (!addressComplete) ...[
                            const SizedBox(height: 10),
                            OutlinedButton(
                              onPressed: _editAddress,
                              style: OutlinedButton.styleFrom(
                                minimumSize: const Size.fromHeight(44),
                              ),
                              child: const Text('Complete address'),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    _SectionCard(
                      title: 'Payment method',
                      child: Column(
                        children: [
                          _PaymentTile(
                            selected: _method == 'COD',
                            title: 'Cash on delivery',
                            subtitle:
                                'Pay the courier in cash. Available nationwide.',
                            icon: Icons.payments_outlined,
                            tag: 'REAL PAYMENT',
                            onTap: () => setState(() => _method = 'COD'),
                          ),
                          const SizedBox(height: 8),
                          _PaymentTile(
                            selected: _method == 'GCash',
                            title: 'GCash',
                            subtitle:
                                'Demonstration only. No GCash number or PIN is '
                                'ever collected.',
                            icon: Icons.phone_android_outlined,
                            tag: 'SIMULATION',
                            onTap: () => setState(() => _method = 'GCash'),
                          ),
                          const SizedBox(height: 8),
                          _PaymentTile(
                            selected: _method == 'Card',
                            title: 'Card',
                            subtitle:
                                'Demonstration only. No card number, CVV or '
                                'expiry is ever collected.',
                            icon: Icons.credit_card_outlined,
                            tag: 'SIMULATION',
                            onTap: () => setState(() => _method = 'Card'),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    _SectionCard(
                      title: 'Order summary',
                      child: Column(
                        children: [
                          for (final item in widget.items)
                            _SummaryItem(item: item),
                          const SizedBox(height: 8),
                          const Divider(),
                          const SizedBox(height: 6),
                          KeyValueRow(
                            'Requested subtotal',
                            formatMoney(_subtotal),
                          ),
                          KeyValueRow(
                            'Shipping (estimate)',
                            _shipping == 0 ? 'Free' : formatMoney(_shipping),
                            valueColor: _shipping == 0
                                ? AppColors.success
                                : null,
                          ),
                          const Divider(),
                          const SizedBox(height: 6),
                          KeyValueRow(
                            'Requested total',
                            formatMoney(_total),
                            strong: true,
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            'The store verifies the final prices and totals '
                            'before confirming this request.',
                            style: TextStyle(
                              fontSize: 10.5,
                              height: 1.4,
                              color: AppColors.muted,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    _SectionCard(
                      title: 'Order note (optional)',
                      child: TextField(
                        controller: _note,
                        maxLines: 3,
                        maxLength: 300,
                        textCapitalization: TextCapitalization.sentences,
                        decoration: const InputDecoration(
                          hintText:
                              'Delivery instructions, landmark, preferred time…',
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    const Text(
                      'Sending this request does not reserve stock or charge '
                      'you. The store verifies the current prices and stock, '
                      'then confirms or rejects the request. You can cancel '
                      'only while it is awaiting confirmation.',
                      style: TextStyle(
                        fontSize: 10.5,
                        height: 1.5,
                        color: AppColors.muted,
                      ),
                    ),
                    if (_simulated) ...[
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFBF1DE),
                          border: Border.all(
                            color: AppColors.warning.withValues(alpha: 0.25),
                          ),
                        ),
                        child: const Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(
                              Icons.info_outline,
                              size: 17,
                              color: AppColors.warning,
                            ),
                            SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'You selected a simulated payment. You will be '
                                'asked to confirm the demo before the request '
                                'is sent. No money is charged and the request '
                                'stays unpaid for the store to review.',
                                style: TextStyle(
                                  fontSize: 11.5,
                                  height: 1.4,
                                  color: AppColors.warning,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
          bottomNavigationBar: Container(
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
                        const Eyebrow('Requested total'),
                        const SizedBox(height: 3),
                        Text(
                          formatMoney(_total),
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
                        label: _simulated
                            ? 'Continue to simulation'
                            : 'Place order request',
                        accent: !blocked,
                        loading: _placing,
                        onPressed: blocked ? null : () => _place(profile),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _CheckoutIntro extends StatelessWidget {
  const _CheckoutIntro();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.fromLTRB(2, 6, 2, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              AccentMark(),
              SizedBox(width: 7),
              Eyebrow('Secure request'),
              Spacer(),
              StatusDot(label: 'Step 2 of 2', color: AppColors.muted),
            ],
          ),
          SizedBox(height: 10),
          Text(
            'REVIEW & CONFIRM',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w900,
              letterSpacing: -1.2,
              height: 0.98,
            ),
          ),
          SizedBox(height: 8),
          Text(
            'Nothing is charged now. The store verifies prices and stock, '
            'then confirms or rejects your request.',
            style: TextStyle(
              fontSize: 11.5,
              height: 1.5,
              color: AppColors.muted,
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.title, required this.child, this.onEdit});

  final String title;
  final Widget child;
  final VoidCallback? onEdit;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border.all(color: AppColors.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const AccentMark(size: 6),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title.toUpperCase(),
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.6,
                  ),
                ),
              ),
              if (onEdit != null)
                TextButton(
                  onPressed: onEdit,
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    minimumSize: const Size(0, 30),
                    textStyle: const TextStyle(
                      fontSize: 9.5,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.1,
                    ),
                  ),
                  child: const Text('EDIT'),
                ),
            ],
          ),
          Container(
            height: 1,
            margin: const EdgeInsets.only(top: 10, bottom: 12),
            color: AppColors.line,
          ),
          child,
        ],
      ),
    );
  }
}

class _PaymentTile extends StatelessWidget {
  const _PaymentTile({
    required this.selected,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.tag,
    required this.onTap,
  });

  final bool selected;
  final String title;
  final String subtitle;
  final IconData icon;
  final String tag;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final simulated = tag == 'SIMULATION';
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          border: Border.all(
            color: selected ? AppColors.ink : AppColors.line,
            width: selected ? 1.4 : 1,
          ),
          color: selected ? AppColors.surfaceAlt : AppColors.surface,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 34,
              height: 34,
              color: selected ? AppColors.ink : AppColors.subtle,
              alignment: Alignment.center,
              child: Icon(
                icon,
                size: 18,
                color: selected ? Colors.white : AppColors.ink,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          title.toUpperCase(),
                          style: const TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.4,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 5,
                          vertical: 2,
                        ),
                        color: simulated
                            ? const Color(0xFFFBF1DE)
                            : AppColors.subtle,
                        child: Text(
                          tag,
                          style: TextStyle(
                            fontSize: 7,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.8,
                            color: simulated
                                ? AppColors.warning
                                : AppColors.success,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 11,
                      height: 1.45,
                      color: AppColors.muted,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Icon(
              selected
                  ? Icons.radio_button_checked
                  : Icons.radio_button_unchecked,
              size: 18,
              color: selected ? AppColors.accent : AppColors.warmGray,
            ),
          ],
        ),
      ),
    );
  }
}

class _SummaryItem extends StatelessWidget {
  const _SummaryItem({required this.item});

  final CartItem item;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 52,
            height: 64,
            child: ProductImage(
              imageId: item.imageId,
              iconSize: 18,
              showLabel: false,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.name.toUpperCase(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.2,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  'SIZE ${item.size.toUpperCase()} · QTY ${item.quantity}',
                  style: const TextStyle(
                    fontSize: 8,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.1,
                    color: AppColors.muted,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            formatMoney(item.subtotal),
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _CheckoutError extends StatelessWidget {
  const _CheckoutError({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFBE9E7),
        border: Border.all(color: AppColors.danger.withValues(alpha: 0.25)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.error_outline, size: 18, color: AppColors.danger),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                fontSize: 12,
                height: 1.45,
                color: AppColors.danger,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
