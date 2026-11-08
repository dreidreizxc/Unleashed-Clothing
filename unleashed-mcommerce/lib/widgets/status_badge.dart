import 'package:flutter/material.dart';

import '../core/app_theme.dart';
import '../core/formatters.dart';

enum BadgeTone { neutral, positive, warning, negative, dark }

class StatusBadge extends StatelessWidget {
  const StatusBadge({super.key, required this.label, this.tone = BadgeTone.neutral});

  factory StatusBadge.order(String? status) {
    return StatusBadge(
      label: orderStatusLabel(status).toUpperCase(),
      tone: toneForOrder(status),
    );
  }

  factory StatusBadge.payment(String? status) {
    return StatusBadge(
      label: paymentStatusLabel(status).toUpperCase(),
      tone: toneForPayment(status),
    );
  }

  factory StatusBadge.transaction(String? status) {
    switch (status) {
      case 'simulated_success':
      case 'paid':
        return StatusBadge(
          label: status == 'paid' ? 'PAID' : 'SIMULATED · SUCCESS',
          tone: BadgeTone.positive,
        );
      case 'simulated_failed':
      case 'failed':
        return const StatusBadge(label: 'FAILED', tone: BadgeTone.negative);
      case 'refunded':
        return const StatusBadge(label: 'REFUNDED', tone: BadgeTone.warning);
      case 'cod_pending':
        return const StatusBadge(label: 'COD · UNPAID', tone: BadgeTone.warning);
      case 'cancelled':
        return const StatusBadge(label: 'CANCELLED', tone: BadgeTone.negative);
      default:
        return StatusBadge(
          label: titleCase(status).toUpperCase(),
          tone: BadgeTone.neutral,
        );
    }
  }

  final String label;
  final BadgeTone tone;

  static BadgeTone toneForOrder(String? status) {
    switch (status) {
      case 'delivered':
        return BadgeTone.positive;
      case 'rejected':
      case 'cancelled':
      case 'refunded':
        return BadgeTone.negative;
      case 'pending_confirmation':
      case 'placed':
      case 'confirmed':
      case 'processing':
        return BadgeTone.warning;
      case 'shipped':
      case 'out_for_delivery':
      case 'ready_for_shipment':
        return BadgeTone.dark;
      default:
        return BadgeTone.neutral;
    }
  }

  static BadgeTone toneForPayment(String? status) {
    switch (status) {
      case 'paid':
        return BadgeTone.positive;
      case 'failed':
        return BadgeTone.negative;
      case 'refunded':
        return BadgeTone.warning;
      case 'pending':
        return BadgeTone.warning;
      default:
        return BadgeTone.neutral;
    }
  }

  @override
  Widget build(BuildContext context) {
    final (background, foreground) = switch (tone) {
      BadgeTone.positive => (const Color(0xFFE7F1EA), AppColors.success),
      BadgeTone.warning => (const Color(0xFFF8EFDF), AppColors.warning),
      BadgeTone.negative => (const Color(0xFFFBE7E4), AppColors.accent),
      BadgeTone.dark => (AppColors.ink, Colors.white),
      BadgeTone.neutral => (AppColors.subtle, AppColors.muted),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 8,
          fontWeight: FontWeight.w900,
          letterSpacing: 1.1,
          color: foreground,
        ),
      ),
    );
  }
}
