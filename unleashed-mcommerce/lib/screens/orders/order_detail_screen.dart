import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/app_theme.dart';
import '../../core/formatters.dart';
import '../../models/order.dart';
import '../../services/order_service.dart';
import '../../state/app_state.dart';
import '../../widgets/common.dart';
import '../../widgets/editorial.dart';
import '../../widgets/product_image.dart';
import '../../widgets/status_badge.dart';
import '../chat/chat_screen.dart';
import '../reviews/write_review_screen.dart';

class OrderDetailScreen extends StatefulWidget {
  const OrderDetailScreen({super.key, required this.orderId});

  final String orderId;

  @override
  State<OrderDetailScreen> createState() => _OrderDetailScreenState();
}

class _OrderDetailScreenState extends State<OrderDetailScreen> {
  bool _cancelling = false;

  Future<void> _copyLabel(String label, {required bool hasOrderNumber}) async {
    await Clipboard.setData(ClipboardData(text: label));
    if (mounted) {
      showAppSnack(
        context,
        hasOrderNumber ? 'Order number copied.' : 'Request ID copied.',
      );
    }
  }

  Future<void> _cancel(CustomerOrder order) async {
    final controller = TextEditingController();
    final reason = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Cancel request?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'This withdraws your pending request. No stock was reserved, so '
              'nothing is returned to inventory. Confirmed orders must be '
              'cancelled by the store.',
              style: TextStyle(fontSize: 13, height: 1.45),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: controller,
              maxLines: 2,
              maxLength: 200,
              decoration: const InputDecoration(
                labelText: 'Reason (optional)',
                hintText: 'Changed my mind, wrong size…',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Keep request'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(
              controller.text.trim().isEmpty
                  ? 'Cancelled by customer.'
                  : controller.text.trim(),
            ),
            style: TextButton.styleFrom(foregroundColor: AppColors.danger),
            child: const Text('Cancel request'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (reason == null || !mounted) return;

    setState(() => _cancelling = true);
    try {
      await OrderService.instance.cancelRequest(order: order, reason: reason);
      if (mounted) showAppSnack(context, 'Your request has been cancelled.');
    } on OrderFailure catch (error) {
      if (mounted) showAppSnack(context, error.message, error: true);
    } catch (_) {
      if (mounted) {
        showAppSnack(
          context,
          'The request could not be cancelled. Please contact the store.',
          error: true,
        );
      }
    } finally {
      if (mounted) setState(() => _cancelling = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.paper,
      appBar: AppBar(
        title: const Text('ORDER DETAILS'),
        actions: [
          IconButton(
            tooltip: 'Message the store',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const ChatScreen()),
            ),
            icon: const Icon(Icons.chat_bubble_outline, size: 20),
          ),
          const SizedBox(width: 6),
        ],
      ),
      body: StreamBuilder<CustomerOrder?>(
        stream: OrderService.instance.watchOrder(widget.orderId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const AppStateView.loading(message: 'Loading order…');
          }
          if (snapshot.hasError) {
            return const AppStateView.error(
              title: 'Could not load this order',
              message: 'Check your connection and try again.',
            );
          }
          final order = snapshot.data;
          if (order == null) {
            return const AppStateView.empty(
              icon: Icons.receipt_long_outlined,
              title: 'Order not found',
              message:
                  'This order may have been removed, or you may not have '
                  'permission to view it.',
            );
          }
          return _OrderBody(
            order: order,
            cancelling: _cancelling,
            onCancel: () => _cancel(order),
            onCopy: () => _copyLabel(
              order.label,
              hasOrderNumber: order.hasOrderNumber,
            ),
            onMessageStore: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const ChatScreen()),
            ),
          );
        },
      ),
    );
  }
}

class _OrderBody extends StatelessWidget {
  const _OrderBody({
    required this.order,
    required this.cancelling,
    required this.onCancel,
    required this.onCopy,
    required this.onMessageStore,
  });

  final CustomerOrder order;
  final bool cancelling;
  final VoidCallback onCancel;
  final VoidCallback onCopy;
  final VoidCallback onMessageStore;

  @override
  Widget build(BuildContext context) {
    final uid = AppState.instance.user?.uid;
    final totalsVerified = order.totalsVerified;
    final displayItems = totalsVerified
        ? order.items
        : order.effectiveRequestedItems;
    final displaySubtotal = totalsVerified
        ? (order.subtotal ?? order.items.fold<int>(0, (s, i) => s + i.subtotal))
        : order.requestedSubtotalValue;
    final displayShipping = totalsVerified
        ? order.shippingFee
        : (order.requestedShippingFee ?? order.shippingFee);
    final displayTotal = totalsVerified
        ? order.total
        : order.requestedTotalValue;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(18),
          color: AppColors.ink,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const AccentMark(size: 6),
                  const SizedBox(width: 7),
                  Eyebrow(
                    order.isPendingRequest ? 'Request status' : 'Order status',
                    color: Colors.white70,
                  ),
                  const Spacer(),
                  StatusBadge.order(order.status),
                ],
              ),
              const SizedBox(height: 14),
              Text(
                orderStatusLabel(order.status).toUpperCase(),
                style: const TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -1,
                  height: 0.98,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 14),
              Container(height: 1, color: Colors.white.withValues(alpha: 0.18)),
              const SizedBox(height: 12),
              Row(
                children: [
                  Text(
                    order.label,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.8,
                      color: Colors.white.withValues(alpha: 0.9),
                    ),
                  ),
                  const SizedBox(width: 6),
                  InkWell(
                    onTap: onCopy,
                    child: Icon(
                      Icons.copy,
                      size: 13,
                      color: Colors.white.withValues(alpha: 0.7),
                    ),
                  ),
                  const Spacer(),
                  Text(
                    formatDateTime(order.createdAt).toUpperCase(),
                    style: TextStyle(
                      fontSize: 8,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1,
                      color: Colors.white.withValues(alpha: 0.55),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        if (order.isPendingRequest) ...[
          const _Notice(
            tone: _NoticeTone.warning,
            title: 'Awaiting store confirmation',
            message:
                'This is a request, not a confirmed order. No stock is '
                'reserved and no money has been charged. The store verifies '
                'the current prices and stock before confirming or rejecting '
                'it.',
          ),
          const SizedBox(height: 12),
        ],
        if (order.isRejected) ...[
          _Notice(
            tone: _NoticeTone.danger,
            title: 'Request rejected',
            message:
                order.rejectionReason?.isNotEmpty == true
                ? order.rejectionReason!
                : 'The store could not confirm this request. No stock was '
                      'deducted and no payment is due.',
          ),
          const SizedBox(height: 12),
        ],
        _Section(
          title: 'Timeline',
          child: _Timeline(events: _timeline(order)),
        ),
        if (order.status == 'cancelled' &&
            (order.cancelReason ?? '').isNotEmpty) ...[
          const SizedBox(height: 12),
          _Section(
            title: 'Cancellation',
            child: Text(
              order.cancelReason!,
              style: const TextStyle(
                fontSize: 12.5,
                height: 1.45,
                color: AppColors.danger,
              ),
            ),
          ),
        ],
        const SizedBox(height: 12),
        _Section(
          title: totalsVerified ? 'Items (verified)' : 'Requested items',
          child: Column(
            children: [
              for (final item in displayItems)
                _OrderItemRow(
                  item: item,
                  priceVerified: totalsVerified,
                  canReview: order.status == 'delivered' && uid != null,
                  onReview: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => WriteReviewScreen(
                        productId: item.productId,
                        productName: item.name,
                        orderId: order.id,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _Section(
          title: 'Delivery',
          child: Column(
            children: [
              KeyValueRow('Recipient', order.customerName ?? '—'),
              KeyValueRow('Address', order.shippingAddress ?? '—'),
              if ((order.courierName ?? '').isNotEmpty)
                KeyValueRow('Courier', order.courierName!),
              if ((order.trackingNumber ?? '').isNotEmpty)
                KeyValueRow('Tracking no.', order.trackingNumber!),
              if ((order.trackingUrl ?? '').isNotEmpty)
                SelectableText(
                  order.trackingUrl!,
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.muted,
                    height: 1.4,
                  ),
                ),
              if ((order.trackingNumber ?? '').isEmpty &&
                  (order.trackingUrl ?? '').isEmpty &&
                  order.status != 'delivered')
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      order.isPendingRequest
                          ? 'Tracking details appear after the store confirms '
                                'and ships your order.'
                          : 'Tracking details appear here once the store ships '
                                'your order.',
                      style: const TextStyle(
                        fontSize: 10.5,
                        height: 1.4,
                        color: AppColors.muted,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _Section(
          title: 'Payment',
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      paymentMethodLabel(order.paymentMethod),
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  StatusBadge.payment(order.paymentStatus),
                ],
              ),
              const SizedBox(height: 8),
              if (order.isSimulatedPayment)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(10),
                  color: const Color(0xFFFBF1DE),
                  child: const Text(
                    'SIMULATED — no real money was charged for this order. '
                    'Cash on delivery remains the only real payment method.',
                    style: TextStyle(
                      fontSize: 10.5,
                      height: 1.45,
                      fontWeight: FontWeight.w600,
                      color: AppColors.warning,
                    ),
                  ),
                ),
              if ((order.transactionReference ?? order.requestReference ?? '')
                  .isNotEmpty)
                KeyValueRow(
                  'Reference',
                  order.transactionReference ?? order.requestReference!,
                ),
              const SizedBox(height: 4),
              const Divider(),
              const SizedBox(height: 4),
              KeyValueRow(
                totalsVerified ? 'Subtotal' : 'Requested subtotal',
                formatMoney(displaySubtotal),
              ),
              KeyValueRow(
                totalsVerified ? 'Shipping' : 'Shipping (estimate)',
                displayShipping == 0 ? 'Free' : formatMoney(displayShipping),
              ),
              KeyValueRow(
                totalsVerified ? 'Verified total' : 'Requested total',
                formatMoney(displayTotal),
                strong: true,
              ),
              if (!totalsVerified)
                const Padding(
                  padding: EdgeInsets.only(top: 6),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'The store verifies these prices and the shipping fee '
                      'before confirming the order.',
                      style: TextStyle(
                        fontSize: 10.5,
                        height: 1.4,
                        color: AppColors.muted,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        if (order.canCancel)
          PrimaryButton(
            label: 'Cancel request',
            outlined: true,
            loading: cancelling,
            onPressed: cancelling ? null : onCancel,
          ),
        if (order.canCancel) const SizedBox(height: 10),
        PrimaryButton(
          label: 'Message the store',
          icon: Icons.chat_bubble_outline,
          outlined: !order.canCancel,
          onPressed: onMessageStore,
        ),
        if (order.status == 'delivered') ...[
          const SizedBox(height: 12),
          const Text(
            'Delivered? Leave a review on each item above. Reviews are only '
            'available for delivered purchases.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 10.5,
              height: 1.5,
              color: AppColors.muted,
            ),
          ),
        ],
      ],
    );
  }

  List<OrderTimelineEvent> _timeline(CustomerOrder order) {
    final events = List<OrderTimelineEvent>.from(order.effectiveTimeline);
    if (!events.any((event) => event.status == order.status)) {
      events.add(
        OrderTimelineEvent(
          status: order.status,
          title: orderStatusLabel(order.status),
          at: asDate(order.updatedAt),
          note: null,
        ),
      );
    }
    events.sort((a, b) {
      final aTime = a.at?.millisecondsSinceEpoch ?? 0;
      final bTime = b.at?.millisecondsSinceEpoch ?? 0;
      return aTime.compareTo(bTime);
    });
    return events;
  }
}

enum _NoticeTone { warning, danger }

class _Notice extends StatelessWidget {
  const _Notice({
    required this.tone,
    required this.title,
    required this.message,
  });

  final _NoticeTone tone;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    final danger = tone == _NoticeTone.danger;
    final color = danger ? AppColors.danger : AppColors.warning;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: danger ? const Color(0xFFFBE9E7) : const Color(0xFFFBF1DE),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                danger ? Icons.error_outline : Icons.hourglass_top,
                size: 17,
                color: color,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title.toUpperCase(),
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.8,
                    color: color,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            message,
            style: TextStyle(
              fontSize: 11.5,
              height: 1.45,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border.all(color: AppColors.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const AccentMark(size: 5),
              const SizedBox(width: 7),
              Text(
                title.toUpperCase(),
                style: const TextStyle(
                  fontSize: 9.5,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

class _OrderItemRow extends StatelessWidget {
  const _OrderItemRow({
    required this.item,
    required this.priceVerified,
    required this.canReview,
    required this.onReview,
  });

  final OrderItem item;
  final bool priceVerified;
  final bool canReview;
  final VoidCallback onReview;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 54,
            height: 66,
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
                  style: const TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.2,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  'SIZE ${item.size.toUpperCase()} · QTY ${item.quantity} · '
                  '${formatMoney(item.price)} EACH',
                  style: const TextStyle(
                    fontSize: 8,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1,
                    color: AppColors.muted,
                  ),
                ),
                if (!priceVerified)
                  const Text(
                    'Requested price — verified by the store',
                    style: TextStyle(
                      fontSize: 9.5,
                      color: AppColors.muted,
                    ),
                  ),
                if (canReview)
                  InkWell(
                    onTap: onReview,
                    child: const Padding(
                      padding: EdgeInsets.only(top: 4),
                      child: Text(
                        'Write a review →',
                        style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w800,
                          decoration: TextDecoration.underline,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            formatMoney(item.subtotal),
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
          ),
        ],
      ),
    );
  }
}

class _Timeline extends StatelessWidget {
  const _Timeline({required this.events});

  final List<OrderTimelineEvent> events;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (var index = 0; index < events.length; index++)
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(
                  width: 20,
                  child: Column(
                    children: [
                      Container(
                        width: 9,
                        height: 9,
                        margin: const EdgeInsets.only(top: 4),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: index == events.length - 1
                              ? AppColors.ink
                              : AppColors.line,
                          border: Border.all(color: AppColors.ink),
                        ),
                      ),
                      if (index != events.length - 1)
                        Expanded(
                          child: Container(
                            width: 1,
                            color: AppColors.line,
                            margin: const EdgeInsets.symmetric(vertical: 3),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          eventTitle(events[index]),
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        if ((events[index].note ?? '').isNotEmpty) ...[
                          const SizedBox(height: 3),
                          Text(
                            events[index].note!,
                            style: const TextStyle(
                              fontSize: 11,
                              height: 1.45,
                              color: AppColors.muted,
                            ),
                          ),
                        ],
                        const SizedBox(height: 3),
                        Text(
                          formatDateTime(events[index].at).toUpperCase(),
                          style: const TextStyle(
                            fontSize: 8,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1,
                            color: AppColors.muted,
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
    );
  }

  String eventTitle(OrderTimelineEvent event) {
    if (event.title.trim().isNotEmpty) return event.title;
    return orderStatusLabel(event.status);
  }
}
