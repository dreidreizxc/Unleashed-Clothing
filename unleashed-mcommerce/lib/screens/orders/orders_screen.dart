import 'package:flutter/material.dart';

import '../../core/app_theme.dart';
import '../../core/formatters.dart';
import '../../models/order.dart';
import '../../services/order_service.dart';
import '../../state/app_state.dart';
import '../../state/shell_tabs.dart';
import '../../widgets/common.dart';
import '../../widgets/editorial.dart';
import '../../widgets/product_image.dart';
import '../../widgets/status_badge.dart';
import 'order_detail_screen.dart';

class OrdersScreen extends StatefulWidget {
  const OrdersScreen({super.key});

  @override
  State<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends State<OrdersScreen> {
  late Stream<List<CustomerOrder>> _stream;
  String _filter = 'All';

  @override
  void initState() {
    super.initState();
    _bindStream();
  }

  void _bindStream() {
    final uid = AppState.instance.user?.uid;
    _stream = uid == null
        ? const Stream<List<CustomerOrder>>.empty()
        : OrderService.instance.watchOrders(uid);
  }

  Future<void> _refresh() async {
    setState(_bindStream);
    await Future<void>.delayed(const Duration(milliseconds: 500));
  }

  List<CustomerOrder> _filtered(List<CustomerOrder> orders) {
    switch (_filter) {
      case 'Pending':
        return orders.where((order) => order.isPendingRequest).toList();
      case 'Active':
        return orders.where((order) => !order.isCompleted).toList();
      case 'Delivered':
        return orders.where((order) => order.status == 'delivered').toList();
      case 'Closed':
        return orders
            .where(
              (order) =>
                  order.isRejected ||
                  order.status == 'cancelled' ||
                  order.status == 'refunded',
            )
            .toList();
      default:
        return orders;
    }
  }

  @override
  Widget build(BuildContext context) {
    final uid = AppState.instance.user?.uid;
    return Scaffold(
      backgroundColor: AppColors.paper,
      appBar: AppBar(
        title: const Text('YOUR ORDERS'),
        actions: [
          IconButton(
            tooltip: 'Refresh orders',
            onPressed: _refresh,
            icon: const Icon(Icons.refresh, size: 20),
          ),
          const SizedBox(width: 6),
        ],
      ),
      body: uid == null
          ? AppStateView.empty(
              icon: Icons.lock_outline,
              title: 'Sign in to see orders',
              message:
                  'Your order history, live delivery updates and receipts are '
                  'tied to your customer account.',
              actionLabel: 'Sign in',
              onAction: AppState.instance.requestSignIn,
            )
          : StreamBuilder<List<CustomerOrder>>(
              stream: _stream,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const AppStateView.loading(
                    message: 'Loading your orders…',
                  );
                }
                if (snapshot.hasError) {
                  return AppStateView.error(
                    title: 'Could not load orders',
                    message:
                        'Check your connection and try again. Orders are read '
                        'in real time from Firebase.',
                    onAction: _refresh,
                  );
                }

                final orders = snapshot.data ?? const <CustomerOrder>[];
                final filtered = _filtered(orders);

                return RefreshIndicator(
                  onRefresh: _refresh,
                  child: CustomScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    slivers: [
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              const Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Eyebrow('The archive'),
                                    SizedBox(height: 6),
                                    Text(
                                      'YOUR ORDERS',
                                      style: TextStyle(
                                        fontSize: 30,
                                        fontWeight: FontWeight.w900,
                                        letterSpacing: -1.3,
                                        height: 0.96,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Text(
                                '${orders.length} '
                                '${orders.length == 1 ? 'REQUEST' : 'REQUESTS'}',
                                style: const TextStyle(
                                  fontSize: 8.5,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 1.4,
                                  color: AppColors.muted,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      SliverToBoxAdapter(
                        child: SizedBox(
                          height: 48,
                          child: ListView(
                            scrollDirection: Axis.horizontal,
                            padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
                            children: [
                              for (final filter in const [
                                'All',
                                'Pending',
                                'Active',
                                'Delivered',
                                'Closed',
                              ])
                                Padding(
  padding: const EdgeInsets.only(right: 7),
  child: Transform.scale(
    scale: 0.88,
    child: OutlinePill(
      label: filter,
      selected: _filter == filter,
      onTap: () => setState(() => _filter = filter),
    ),
  ),
),
                            ],
                          ),
                        ),
                      ),
                      if (orders.isEmpty)
                        SliverFillRemaining(
  hasScrollBody: true,
                          child: AppStateView.empty(
                            icon: Icons.receipt_long_outlined,
                            title: 'No requests yet',
                            message:
                                'When you send an order request it will appear '
                                'here with live confirmation updates.',
                            actionLabel: 'Start shopping',
                            onAction: () => ShellTabs.go(ShellTabs.home),
                          ),
                        )
                      else if (filtered.isEmpty)
                        SliverFillRemaining(
                          hasScrollBody: true,
                          child: AppStateView.empty(
                            icon: Icons.filter_alt_off_outlined,
                            title: 'Nothing in this filter',
                            message: 'Try another request filter.',
                            actionLabel: 'Show all requests',
                            onAction: () => setState(() => _filter = 'All'),
                          ),
                        )
                      else
                        SliverPadding(
                          padding: const EdgeInsets.fromLTRB(16, 10, 16, 24),
                          sliver: SliverList.separated(
                            itemCount: filtered.length,
                            separatorBuilder: (_, _) =>
                                const SizedBox(height: 10),
                            itemBuilder: (context, index) {
                              final order = filtered[index];
                              return _OrderCard(
                                order: order,
                                onTap: () => Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) =>
                                        OrderDetailScreen(orderId: order.id),
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                    ],
                  ),
                );
              },
            ),
    );
  }
}

class _OrderCard extends StatelessWidget {
  const _OrderCard({required this.order, required this.onTap});

  final CustomerOrder order;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final items = order.totalsVerified
        ? order.items
        : order.effectiveRequestedItems;
    final firstItem = items.isEmpty ? null : items.first;
    final total = order.totalsVerified ? order.total : order.requestedTotalValue;
    return Material(
      color: AppColors.surface,
      shape: const RoundedRectangleBorder(
        side: BorderSide(color: AppColors.line),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      order.label.toUpperCase(),
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ),
                  StatusBadge.order(order.status),
                ],
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  Text(
                    formatDateTime(order.createdAt).toUpperCase(),
                    style: const TextStyle(
                      fontSize: 8,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1,
                      color: AppColors.muted,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '${order.itemCount} '
                    '${order.itemCount == 1 ? 'ITEM' : 'ITEMS'}',
                    style: const TextStyle(
                      fontSize: 8,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1,
                      color: AppColors.muted,
                    ),
                  ),
                ],
              ),
              Container(
                height: 1,
                margin: const EdgeInsets.symmetric(vertical: 12),
                color: AppColors.line,
              ),
              Row(
                children: [
                  SizedBox(
                    width: 60,
                    height: 74,
                    child: ProductImage(
                      imageId: firstItem?.imageId,
                      iconSize: 20,
                      showLabel: false,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          firstItem == null
                              ? 'Requested items'
                              : (items.length == 1
                                    ? firstItem.name
                                    : '${firstItem.name} +${items.length - 1} more'),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 5),
                        Text(
                          paymentMethodLabel(order.paymentMethod).toUpperCase(),
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
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        formatMoney(total),
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -0.3,
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Icon(Icons.arrow_outward, size: 14),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
