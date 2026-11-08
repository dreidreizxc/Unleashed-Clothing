import 'package:flutter/material.dart';

import '../../core/app_theme.dart';
import '../../core/formatters.dart';
import '../../models/payment_transaction.dart';
import '../../services/order_service.dart';
import '../../state/app_state.dart';
import '../../widgets/common.dart';
import '../../widgets/editorial.dart';
import '../../widgets/status_badge.dart';
import '../orders/order_detail_screen.dart';

class TransactionsScreen extends StatefulWidget {
  const TransactionsScreen({super.key});

  @override
  State<TransactionsScreen> createState() => _TransactionsScreenState();
}

class _TransactionsScreenState extends State<TransactionsScreen> {
  late Stream<List<PaymentTransaction>> _stream;

  @override
  void initState() {
    super.initState();
    _bind();
  }

  void _bind() {
    final uid = AppState.instance.user?.uid;
    _stream = uid == null
        ? const Stream<List<PaymentTransaction>>.empty()
        : OrderService.instance.watchTransactions(uid);
  }

  Future<void> _refresh() async {
    setState(_bind);
    await Future<void>.delayed(const Duration(milliseconds: 400));
  }

  @override
  Widget build(BuildContext context) {
    final uid = AppState.instance.user?.uid;
    return Scaffold(
      backgroundColor: AppColors.paper,
      appBar: AppBar(title: const Text('TRANSACTIONS')),
      body: uid == null
          ? const AppStateView.empty(
              icon: Icons.lock_outline,
              title: 'Sign in to view transactions',
              message: 'Payment records are tied to your account.',
            )
          : StreamBuilder<List<PaymentTransaction>>(
              stream: _stream,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const AppStateView.loading(
                    message: 'Loading transactions…',
                  );
                }
                if (snapshot.hasError) {
                  return AppStateView.error(
                    title: 'Transactions are unavailable',
                    message:
                        'Payment records become available once the store '
                        'publishes its transaction rules.',
                    onAction: _refresh,
                  );
                }
                final transactions =
                    snapshot.data ?? const <PaymentTransaction>[];
                if (transactions.isEmpty) {
                  return RefreshIndicator(
                    onRefresh: _refresh,
                    child: ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      children: const [
                        SizedBox(height: 80),
                        AppStateView.empty(
                          icon: Icons.account_balance_wallet_outlined,
                          title: 'No transactions yet',
                          message:
                              'A record is created for every order, including '
                              'cash-on-delivery and simulated payments.',
                        ),
                      ],
                    ),
                  );
                }
                final simulated = transactions.where((t) => t.simulated).length;
                return RefreshIndicator(
                  onRefresh: _refresh,
                  child: ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
                    children: [
                      const _TransactionsIntro(),
                      const SizedBox(height: 14),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFBF1DE),
                          border: Border.all(
                            color: AppColors.warning.withValues(alpha: 0.25),
                          ),
                        ),
                        child: Text(
                          'GCash and card entries are demonstrations only. '
                          'No card number, CVV, GCash number or PIN is ever '
                          'collected. ${simulated > 0 ? '$simulated simulated record${simulated == 1 ? '' : 's'} shown.' : 'Cash on delivery is the only real payment method.'}',
                          style: const TextStyle(
                            fontSize: 10.5,
                            height: 1.45,
                            fontWeight: FontWeight.w600,
                            color: AppColors.warning,
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      for (var i = 0; i < transactions.length; i++) ...[
                        _TransactionTile(transaction: transactions[i]),
                        if (i != transactions.length - 1)
                          const SizedBox(height: 8),
                      ],
                    ],
                  ),
                );
              },
            ),
    );
  }
}

class _TransactionsIntro extends StatelessWidget {
  const _TransactionsIntro();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.fromLTRB(4, 10, 4, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              AccentMark(),
              SizedBox(width: 7),
              Eyebrow('Ledger'),
              Spacer(),
              StatusDot(label: 'Demo payments', color: AppColors.warning),
            ],
          ),
          SizedBox(height: 10),
          Text(
            'TRANSACTIONS',
            style: TextStyle(
              fontSize: 30,
              fontWeight: FontWeight.w900,
              letterSpacing: -1.3,
              height: 0.96,
            ),
          ),
          SizedBox(height: 8),
          Text(
            'Every order request produces a payment record, including '
            'cash-on-delivery and demonstration entries.',
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

class _TransactionTile extends StatelessWidget {
  const _TransactionTile({required this.transaction});

  final PaymentTransaction transaction;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      shape: const RoundedRectangleBorder(
        side: BorderSide(color: AppColors.line),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: (transaction.orderId.isEmpty)
            ? null
            : () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => OrderDetailScreen(
                    orderId: transaction.orderId,
                  ),
                ),
              ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      transaction.label.toUpperCase(),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.6,
                      ),
                    ),
                  ),
                  StatusBadge.transaction(transaction.status),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                paymentMethodLabel(transaction.paymentMethod).toUpperCase(),
                style: const TextStyle(
                  fontSize: 8.5,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.1,
                  color: AppColors.muted,
                ),
              ),
              Container(
                height: 1,
                margin: const EdgeInsets.symmetric(vertical: 12),
                color: AppColors.line,
              ),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if ((transaction.orderNumber ?? '').isNotEmpty)
                          Text(
                            'ORDER ${transaction.orderNumber}',
                            style: const TextStyle(
                              fontSize: 8.5,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 1,
                              color: AppColors.muted,
                            ),
                          ),
                        const SizedBox(height: 3),
                        Text(
                          formatDateTime(transaction.createdAt).toUpperCase(),
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
                  Text(
                    formatMoney(transaction.amount),
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.4,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                transaction.statusLabel.toUpperCase(),
                style: TextStyle(
                  fontSize: 8,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1,
                  color: transaction.status == 'simulated_success' ||
                          transaction.status == 'paid'
                      ? AppColors.success
                      : transaction.status == 'simulated_failed'
                      ? AppColors.danger
                      : AppColors.muted,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
