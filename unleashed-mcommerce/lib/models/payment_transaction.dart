import 'package:cloud_firestore/cloud_firestore.dart';

import '../core/formatters.dart';
import 'order.dart';

/// A payment record linked to exactly one order. GCash and card entries are
/// always simulations; COD entries remain pending until cash is collected.
class PaymentTransaction {
  const PaymentTransaction({
    required this.id,
    required this.orderId,
    required this.customerId,
    required this.amount,
    required this.paymentMethod,
    required this.paymentStatus,
    required this.status,
    required this.simulated,
    required this.reference,
    this.orderNumber,
    this.currency = 'PHP',
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String orderId;
  final String? orderNumber;
  final String customerId;
  final int amount;
  final String currency;
  final String paymentMethod;
  final String paymentStatus;

  /// `pending`, `simulated_success`, `simulated_failed`, `cod_pending`,
  /// `paid`, or `refunded`.
  final String status;
  final bool simulated;
  final String reference;
  final Timestamp? createdAt;
  final Timestamp? updatedAt;

  String get label => reference.isNotEmpty
      ? reference
      : 'TXN-${id.substring(0, id.length > 8 ? 8 : id.length).toUpperCase()}';

  String get statusLabel {
    switch (status) {
      case 'simulated_success':
        return 'Simulated payment successful';
      case 'simulated_failed':
        return 'Simulated payment failed';
      case 'cod_pending':
        return 'Cash on delivery · unpaid';
      case 'paid':
        return 'Paid';
      case 'refunded':
        return 'Refunded';
      default:
        return titleCase(status);
    }
  }

  factory PaymentTransaction.fromOrder(CustomerOrder order) {
  String transactionStatus;

  if (order.paymentStatus == 'paid') {
    transactionStatus = 'paid';
  } else if (order.paymentStatus == 'refunded') {
    transactionStatus = 'refunded';
  } else if (order.paymentStatus == 'failed') {
    transactionStatus = order.isSimulatedPayment
        ? 'simulated_failed'
        : 'failed';
  } else if (order.status == 'cancelled') {
    transactionStatus = 'cancelled';
  } else if (order.status == 'rejected') {
    transactionStatus = 'rejected';
  } else if (order.paymentMethod == 'COD') {
    transactionStatus = 'cod_pending';
  } else {
    transactionStatus = 'pending';
  }

  return PaymentTransaction(
    id: order.id,
    orderId: order.id,
    orderNumber: order.orderNumber,
    customerId: order.customerId,
    amount: order.payableTotal,
    paymentMethod: order.paymentMethod,
    paymentStatus: order.paymentStatus,
    status: transactionStatus,
    simulated: order.isSimulatedPayment,
    reference: order.requestReference ?? order.orderNumber ?? order.id,
    createdAt: order.createdAt,
    updatedAt: order.updatedAt,
  );
}
}
