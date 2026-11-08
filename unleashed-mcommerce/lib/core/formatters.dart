import 'package:cloud_firestore/cloud_firestore.dart';

import '../config/app_config.dart';

/// Prices are stored as integer centavos everywhere in Firestore.
String formatMoney(num? centavos, {bool withSymbol = true}) {
  final value = ((centavos ?? 0) / 100).clamp(0, double.infinity);
  final fixed = value.toStringAsFixed(2);
  final parts = fixed.split('.');
  final digits = parts.first;
  final buffer = StringBuffer();
  for (var index = 0; index < digits.length; index++) {
    final remaining = digits.length - index;
    buffer.write(digits[index]);
    if (remaining > 1 && remaining % 3 == 1) {
      buffer.write(',');
    }
  }
  final formatted = '${buffer.toString()}.${parts.last}';
  return withSymbol ? '${AppConfig.currencySymbol}$formatted' : formatted;
}

String formatCompactMoney(num? centavos) {
  final pesos = (centavos ?? 0) / 100;
  if (pesos >= 1000000) {
    return '${AppConfig.currencySymbol}${(pesos / 1000000).toStringAsFixed(1)}M';
  }
  return formatMoney(centavos);
}

DateTime? asDate(dynamic value) {
  if (value is Timestamp) return value.toDate();
  if (value is DateTime) return value;
  if (value is int) return DateTime.fromMillisecondsSinceEpoch(value);
  return null;
}

const List<String> _months = [
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec',
];

String formatDate(dynamic value, {String fallback = '—'}) {
  final date = asDate(value);
  if (date == null) return fallback;
  return '${_months[date.month - 1]} ${date.day}, ${date.year}';
}

String formatDateTime(dynamic value, {String fallback = '—'}) {
  final date = asDate(value);
  if (date == null) return fallback;
  final hour = date.hour % 12 == 0 ? 12 : date.hour % 12;
  final minute = date.minute.toString().padLeft(2, '0');
  final suffix = date.hour >= 12 ? 'PM' : 'AM';
  return '${formatDate(date)} · $hour:$minute $suffix';
}

String formatShortDate(dynamic value) {
  final date = asDate(value);
  if (date == null) return '—';
  return '${_months[date.month - 1]} ${date.day}';
}

String timeAgo(dynamic value) {
  final date = asDate(value);
  if (date == null) return '';
  final difference = DateTime.now().difference(date);
  if (difference.inSeconds < 60) return 'Just now';
  if (difference.inMinutes < 60) return '${difference.inMinutes}m ago';
  if (difference.inHours < 24) return '${difference.inHours}h ago';
  if (difference.inDays < 7) return '${difference.inDays}d ago';
  return formatDate(date);
}

String titleCase(String? value) {
  if (value == null || value.isEmpty) return '';
  return value
      .replaceAllMapped(RegExp(r'[_-]+'), (_) => ' ')
      .split(' ')
      .where((part) => part.isNotEmpty)
      .map((part) => part[0].toUpperCase() + part.substring(1).toLowerCase())
      .join(' ');
}

/// Maps internal status values to customer-facing copy while keeping the
/// admin dashboard's status vocabulary unchanged.
String orderStatusLabel(String? status) {
  switch (status) {
    case 'pending_confirmation':
      return 'Awaiting confirmation';
    case 'confirmed':
      return 'Confirmed';
    case 'processing':
      return 'Preparing';
    case 'ready_for_shipment':
      return 'Ready for shipment';
    case 'shipped':
      return 'Shipped';
    case 'out_for_delivery':
      return 'Out for delivery';
    case 'delivered':
      return 'Delivered';
    case 'rejected':
      return 'Request rejected';
    case 'cancelled':
      return 'Cancelled';
    case 'refunded':
      return 'Refunded';
    // Legacy documents created before the order-request model.
    case 'placed':
      return 'Order placed';
    default:
      return titleCase(status).isEmpty ? 'Unknown' : titleCase(status);
  }
}

/// Short explanation shown under the status badge in tracking views.
String orderStatusNote(String? status) {
  switch (status) {
    case 'pending_confirmation':
      return 'The store is verifying prices and stock for your request.';
    case 'confirmed':
      return 'The store confirmed your order and verified the total.';
    case 'rejected':
      return 'The store could not confirm this request.';
    case 'cancelled':
      return 'This request was cancelled.';
    default:
      return '';
  }
}

String paymentStatusLabel(String? status) {
  switch (status) {
    case 'unpaid':
      return 'Unpaid';
    case 'pending':
      return 'Pending';
    case 'paid':
      return 'Paid';
    case 'refunded':
      return 'Refunded';
    case 'failed':
      return 'Failed';
    default:
      return titleCase(status).isEmpty ? 'Unpaid' : titleCase(status);
  }
}

String paymentMethodLabel(String? method) {
  switch (method) {
    case 'COD':
      return 'Cash on Delivery';
    case 'GCash':
      return 'GCash (simulated)';
    case 'Card':
      return 'Card (simulated)';
    default:
      return titleCase(method).isEmpty ? 'Not set' : titleCase(method);
  }
}

String initialsOf(String? name, {String fallback = 'UC'}) {
  if (name == null || name.trim().isEmpty) return fallback;
  final parts = name.trim().split(RegExp(r'\s+')).take(2);
  final value = parts.map((part) => part[0].toUpperCase()).join();
  return value.isEmpty ? fallback : value;
}
