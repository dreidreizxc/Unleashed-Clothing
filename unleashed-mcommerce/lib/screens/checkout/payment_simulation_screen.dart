import 'package:flutter/material.dart';

import '../../core/app_theme.dart';
import '../../core/formatters.dart';
import '../../widgets/editorial.dart';

/// A deliberately obvious simulation. No GCash number, card number, CVV,
/// expiry or any other payment credential is requested or stored.
class PaymentSimulationScreen extends StatefulWidget {
  const PaymentSimulationScreen({
    super.key,
    required this.method,
    required this.amount,
  });

  final String method;
  final int amount;

  @override
  State<PaymentSimulationScreen> createState() =>
      _PaymentSimulationScreenState();
}

class _PaymentSimulationScreenState extends State<PaymentSimulationScreen> {
  bool _processing = false;
  bool _failed = false;

  Future<void> _complete({required bool success}) async {
    if (_processing) return;
    setState(() {
      _processing = true;
      _failed = !success;
    });
    await Future<void>.delayed(
      Duration(milliseconds: success ? 1300 : 900),
    );
    if (!mounted) return;
    Navigator.of(context).pop(success);
  }

  @override
  Widget build(BuildContext context) {
    final label = paymentMethodLabel(widget.method);
    return PopScope(
      canPop: !_processing,
      child: Scaffold(
        backgroundColor: AppColors.paper,
        appBar: AppBar(
          title: const Text('SIMULATED PAYMENT'),
          automaticallyImplyLeading: !_processing,
        ),
        body: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              color: AppColors.ink,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      AccentMark(size: 6),
                      SizedBox(width: 7),
                      Text(
                        'SIMULATION',
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.8,
                          color: Colors.white70,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        color: Colors.white,
                        child: const Text(
                          'DEMO',
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.6,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      const Text(
                        'NOT A REAL PAYMENT',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.4,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  const Text(
                    'No money will be charged.',
                    style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -1,
                      height: 0.98,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'This screen demonstrates the $label flow. The store never '
                    'asks for a GCash number, PIN, card number, CVV or expiry in '
                    'this app.',
                    style: TextStyle(
                      fontSize: 12,
                      height: 1.5,
                      color: Colors.white.withValues(alpha: 0.72),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: AppColors.surface,
                border: Border.all(color: AppColors.line),
              ),
              child: Column(
                children: [
                  const Text(
                    'SIMULATED AMOUNT',
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.6,
                      color: AppColors.muted,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    formatMoney(widget.amount),
                    style: const TextStyle(
                      fontSize: 34,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.8,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    label,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppColors.muted,
                    ),
                  ),
                  const SizedBox(height: 18),
                  const Divider(),
                  const SizedBox(height: 12),
                  const Text(
                    'Sending the request will not charge anything. The request '
                    'stays unpaid for the store to verify, and cash on '
                    'delivery remains the only real payment option.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 11.5,
                      height: 1.5,
                      color: AppColors.muted,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            if (_processing)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 18),
                child: Column(
                  children: [
                    const SizedBox(
                      width: 28,
                      height: 28,
                      child: CircularProgressIndicator(strokeWidth: 2.2),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      _failed
                          ? 'Recording a simulated failure…'
                          : 'Simulating payment…',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: AppColors.muted,
                      ),
                    ),
                  ],
                ),
              )
            else ...[
              ElevatedButton(
                onPressed: () => _complete(success: true),
                child: const Text('Complete simulated payment'),
              ),
              const SizedBox(height: 10),
              OutlinedButton(
                onPressed: () => _complete(success: false),
                child: const Text('Simulate a failed payment'),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Cancel and return to checkout'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
