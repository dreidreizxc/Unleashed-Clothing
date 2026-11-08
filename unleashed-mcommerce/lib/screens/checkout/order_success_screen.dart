import 'package:flutter/material.dart';

import '../../core/app_theme.dart';
import '../../core/formatters.dart';
import '../../services/order_service.dart';
import '../../state/shell_tabs.dart';
import '../../widgets/common.dart';
import '../../widgets/editorial.dart';
import '../orders/order_detail_screen.dart';

class OrderSuccessScreen extends StatelessWidget {
  const OrderSuccessScreen({
    super.key,
    required this.result,
    required this.paymentMethod,
    required this.simulated,
  });

  final OrderRequestResult result;
  final String paymentMethod;
  final bool simulated;

  @override
  Widget build(BuildContext context) {
    final requestLabel = '#${result.orderId.substring(0, 8).toUpperCase()}';
    return Scaffold(
      backgroundColor: AppColors.paper,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 40, 24, 32),
          children: [
            const Center(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  AccentMark(size: 7),
                  SizedBox(width: 8),
                  Eyebrow('Awaiting store confirmation'),
                ],
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'REQUEST SENT.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 44,
                fontWeight: FontWeight.w900,
                letterSpacing: -2.2,
                height: 0.9,
              ),
            ),
            const SizedBox(height: 14),
            Text(
              'The store has received your request for '
              '${formatMoney(result.requestedTotal)}. It is not an order yet: '
              'the store verifies the current prices and stock before '
              'confirming or rejecting it.',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 12.5,
                height: 1.6,
                color: AppColors.muted,
              ),
            ),
            const SizedBox(height: 28),
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: AppColors.surface,
                border: Border.all(color: AppColors.line),
              ),
              child: Column(
                children: [
                  const Eyebrow('Request id'),
                  const SizedBox(height: 8),
                  Text(
                    requestLabel,
                    style: const TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'An official order number is assigned only after the '
                    'store confirms this request.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 10.5,
                      height: 1.4,
                      color: AppColors.muted,
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Divider(),
                  const SizedBox(height: 10),
                  KeyValueRow(
                    'Requested total',
                    formatMoney(result.requestedTotal),
                    strong: true,
                  ),
                  KeyValueRow(
                    'Items',
                    '${result.itemCount} '
                        '${result.itemCount == 1 ? 'item' : 'items'}',
                  ),
                  KeyValueRow(
                    'Payment',
                    simulated
                        ? '${paymentMethodLabel(paymentMethod)} · demo only, unpaid'
                        : '${paymentMethodLabel(paymentMethod)} · unpaid',
                  ),
                  if (result.requestReference.isNotEmpty)
                    KeyValueRow('Reference', result.requestReference),
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(10),
                    color: AppColors.subtle,
                    child: const Text(
                      'AWAITING CONFIRMATION — no stock is reserved and no '
                      'money has been charged. The store will confirm the '
                      'verified total, or reject the request if prices or '
                      'stock changed.',
                      style: TextStyle(
                        fontSize: 10.5,
                        height: 1.45,
                        fontWeight: FontWeight.w600,
                        color: AppColors.muted,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            PrimaryButton(
              label: 'View request',
              icon: Icons.receipt_long_outlined,
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => OrderDetailScreen(orderId: result.orderId),
                ),
              ),
            ),
            const SizedBox(height: 10),
            PrimaryButton(
              label: 'Continue shopping',
              outlined: true,
              onPressed: () {
                ShellTabs.go(ShellTabs.home);
                Navigator.of(context).popUntil((route) => route.isFirst);
              },
            ),
            const SizedBox(height: 18),
            const Text(
              'You will receive in-app updates when the store confirms, '
              'rejects, packs and ships your order.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 10.5,
                height: 1.5,
                color: AppColors.muted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
