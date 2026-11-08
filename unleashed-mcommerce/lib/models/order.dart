import 'package:cloud_firestore/cloud_firestore.dart';

import '../core/formatters.dart';
import 'user_profile.dart';

/// Lifecycle for a customer order request.
///
/// Customers only create `pending_confirmation` requests. The administrator
/// verifies prices and stock and then moves the request to `confirmed` (with an
/// official order number and deducted stock) or `rejected` (no stock change).
/// A customer may cancel only while the request is still pending.
class OrderStatuses {
  OrderStatuses._();

  static const String pendingConfirmation = 'pending_confirmation';
  static const String confirmed = 'confirmed';
  static const String processing = 'processing';
  static const String readyForShipment = 'ready_for_shipment';
  static const String shipped = 'shipped';
  static const String outForDelivery = 'out_for_delivery';
  static const String delivered = 'delivered';
  static const String rejected = 'rejected';
  static const String cancelled = 'cancelled';
  static const String refunded = 'refunded';
}

class OrderItem {
  const OrderItem({
    required this.productId,
    required this.name,
    required this.size,
    required this.price,
    required this.quantity,
    this.imageId,
    this.category,
  });

  final String productId;
  final String name;
  final String size;
  final int price;
  final int quantity;
  final String? imageId;
  final String? category;

  int get subtotal => price * quantity;

  String get priceLabel => formatMoney(price);

  factory OrderItem.fromMap(Map<String, dynamic> map) => OrderItem(
    productId: (map['productId'] ?? '').toString(),
    name: (map['name'] ?? 'Product').toString(),
    size: (map['size'] ?? 'One size').toString(),
    price: (map['price'] as num?)?.toInt() ?? 0,
    quantity: (map['quantity'] as num?)?.toInt() ?? 1,
    imageId: map['imageId']?.toString(),
    category: map['category']?.toString(),
  );

  Map<String, dynamic> toMap() => {
    'productId': productId,
    'name': name,
    'size': size,
    'price': price,
    'quantity': quantity,
    'subtotal': subtotal,
    if (imageId != null) 'imageId': imageId,
    if (category != null) 'category': category,
  };
}

class OrderTimelineEvent {
  const OrderTimelineEvent({
    required this.status,
    required this.title,
    required this.at,
    this.note,
  });

  final String status;
  final String title;
  final DateTime? at;
  final String? note;

  factory OrderTimelineEvent.fromMap(Map<String, dynamic> map) =>
      OrderTimelineEvent(
        status: (map['status'] ?? '').toString(),
        title: (map['title'] ?? '').toString(),
        at: asDate(map['at'] ?? map['createdAt']),
        note: map['note']?.toString(),
      );

  Map<String, dynamic> toMap() => {
    'status': status,
    'title': title,
    'note': note,
    'at': Timestamp.now(),
  };
}

class CustomerOrder {
  const CustomerOrder({
    required this.id,
    required this.customerId,
    required this.items,
    required this.total,
    required this.paymentMethod,
    required this.paymentStatus,
    required this.status,
    required this.createdAt,
    this.orderNumber,
    this.customerName,
    this.customerEmail,
    this.requestedItems,
    this.requestedSubtotal,
    this.requestedShippingFee,
    this.requestedTotal,
    this.subtotal,
    this.shippingFee = 0,
    this.totalsVerified = false,
    this.shippingAddress,
    this.fulfillmentStatus,
    this.courierName,
    this.trackingNumber,
    this.trackingUrl,
    this.paymentSimulated = false,
    this.transactionReference,
    this.requestReference,
    this.customerNote,
    this.cancelReason,
    this.rejectionReason,
    this.confirmedAt,
    this.confirmedBy,
    this.rejectedAt,
    this.rejectedBy,
    this.cancelledAt,
    this.cancelledBy,
    this.restockPending = false,
    this.restockedAt,
    this.customerTotalsApplied = false,
    this.updatedAt,
    this.timeline = const [],
  });

  final String id;
  final String? orderNumber;
  final String customerId;
  final String? customerName;
  final String? customerEmail;

  /// The current line items. For a pending request these mirror the requested
  /// prices. Once an administrator confirms the order they contain the
  /// verified prices that were actually deducted from stock.
  final List<OrderItem> items;

  /// The customer's original requested lines, kept for the admin review and
  /// for showing requested vs verified differences.
  final List<OrderItem>? requestedItems;

  final int total;
  final int? subtotal;
  final int shippingFee;
  final bool totalsVerified;
  final String paymentMethod;
  final String paymentStatus;
  final String status;
  final String? fulfillmentStatus;
  final String? shippingAddress;
  final String? courierName;
  final String? trackingNumber;
  final String? trackingUrl;
  final bool paymentSimulated;
  final String? transactionReference;

  /// Reference shown to the customer when they submit a provisional request.
  /// The official order number only exists after administrator confirmation.
  final String? requestReference;

  final String? customerNote;
  final String? cancelReason;
  final String? rejectionReason;
  final Timestamp? confirmedAt;
  final String? confirmedBy;
  final Timestamp? rejectedAt;
  final String? rejectedBy;
  final Timestamp? cancelledAt;
  final String? cancelledBy;
  final bool restockPending;
  final Timestamp? restockedAt;
  final bool customerTotalsApplied;
  final int? requestedSubtotal;
  final int? requestedShippingFee;
  final int? requestedTotal;
  final Timestamp? createdAt;
  final Timestamp? updatedAt;
  final List<OrderTimelineEvent> timeline;

  String get label => orderNumber?.isNotEmpty == true
      ? orderNumber!
      : '#${id.substring(0, 8).toUpperCase()}';

  bool get hasOrderNumber => orderNumber?.isNotEmpty == true;

  int get itemCount =>
      items.fold<int>(0, (total, item) => total + item.quantity);

  /// Customers may only withdraw a request that the administrator has not
  /// acted on yet. Confirmed cancellations are handled by the store because
  /// they must restore stock and reverse totals.
  bool get canCancel => status == OrderStatuses.pendingConfirmation;

  bool get isPendingRequest => status == OrderStatuses.pendingConfirmation;
  bool get isRejected => status == OrderStatuses.rejected;
  bool get isCancelled => status == OrderStatuses.cancelled;
  bool get isConfirmed => status == OrderStatuses.confirmed;

  bool get isCompleted =>
      status == OrderStatuses.delivered ||
      status == OrderStatuses.cancelled ||
      status == OrderStatuses.rejected ||
      status == OrderStatuses.refunded;

  bool get isSimulatedPayment =>
      paymentSimulated || paymentMethod == 'GCash' || paymentMethod == 'Card';

  List<OrderItem> get effectiveRequestedItems =>
      requestedItems ?? items;

  int get requestedSubtotalValue =>
      requestedSubtotal ??
      effectiveRequestedItems.fold<int>(0, (running, item) => running + item.subtotal);

  int get requestedTotalValue => requestedTotal ?? total;

  int get payableTotal => totalsVerified ? total : requestedTotalValue;

  factory CustomerOrder.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? <String, dynamic>{};
    final items = _itemsFrom(data['items']);
    final requestedItems = data['requestedItems'] == null
        ? null
        : _itemsFrom(data['requestedItems']);
    final timeline = <OrderTimelineEvent>[];
    final rawTimeline = data['timeline'];
    if (rawTimeline is List) {
      for (final entry in rawTimeline) {
        if (entry is Map) {
          timeline.add(
            OrderTimelineEvent.fromMap(Map<String, dynamic>.from(entry)),
          );
        }
      }
    }
    final rawAddress = data['shippingAddress'];
    final courier = data['courier'];
    String? courierName;
    String? trackingNumber;
    String? trackingUrl;
    if (courier is Map) {
      courierName =
          courier['name']?.toString() ?? courier['courierName']?.toString();
      trackingNumber = courier['trackingNumber']?.toString();
      trackingUrl = courier['trackingUrl']?.toString();
    }

    return CustomerOrder(
      id: doc.id,
      orderNumber: data['orderNumber']?.toString(),
      customerId: (data['customerId'] ?? '').toString(),
      customerName: data['customerName']?.toString(),
      customerEmail: data['customerEmail']?.toString(),
      items: List.unmodifiable(items),
      requestedItems: requestedItems == null
          ? null
          : List.unmodifiable(requestedItems),
      total: (data['total'] as num?)?.toInt() ?? 0,
      subtotal: (data['subtotal'] as num?)?.toInt(),
      shippingFee: (data['shippingFee'] as num?)?.toInt() ?? 0,
      totalsVerified: data['totalsVerified'] == true,
      paymentMethod: (data['paymentMethod'] ?? 'COD').toString(),
      paymentStatus: (data['paymentStatus'] ?? 'unpaid').toString(),
      status: (data['status'] ?? OrderStatuses.pendingConfirmation).toString(),
      fulfillmentStatus: data['fulfillmentStatus']?.toString(),
      shippingAddress: rawAddress is String
          ? rawAddress
          : rawAddress is Map
          ? PostalAddress.fromMap(
              Map<String, dynamic>.from(rawAddress),
            ).singleLine
          : null,
      courierName: courierName ?? data['courierName']?.toString(),
      trackingNumber: trackingNumber ?? data['trackingNumber']?.toString(),
      trackingUrl: trackingUrl ?? data['trackingUrl']?.toString(),
      paymentSimulated:
          data['paymentSimulated'] as bool? ??
          (data['paymentMethod'] == 'GCash' || data['paymentMethod'] == 'Card'),
      transactionReference: data['transactionReference']?.toString(),
      requestReference:
          data['requestReference']?.toString() ??
          data['transactionReference']?.toString(),
      customerNote: data['customerNote']?.toString(),
      cancelReason: data['cancelReason']?.toString(),
      rejectionReason:
          data['rejectionReason']?.toString() ?? data['cancelReason']?.toString(),
      confirmedAt: data['confirmedAt'] is Timestamp
          ? data['confirmedAt'] as Timestamp
          : null,
      confirmedBy: data['confirmedBy']?.toString(),
      rejectedAt: data['rejectedAt'] is Timestamp
          ? data['rejectedAt'] as Timestamp
          : null,
      rejectedBy: data['rejectedBy']?.toString(),
      cancelledAt: data['cancelledAt'] is Timestamp
          ? data['cancelledAt'] as Timestamp
          : null,
      cancelledBy: data['cancelledBy']?.toString(),
      restockPending: data['restockPending'] == true,
      restockedAt: data['restockedAt'] is Timestamp
          ? data['restockedAt'] as Timestamp
          : null,
      customerTotalsApplied: data['customerTotalsApplied'] == true,
      requestedSubtotal: (data['requestedSubtotal'] as num?)?.toInt(),
      requestedShippingFee:
          (data['requestedShippingFee'] as num?)?.toInt(),
      requestedTotal: (data['requestedTotal'] as num?)?.toInt(),
      createdAt: data['createdAt'] is Timestamp
          ? data['createdAt'] as Timestamp
          : null,
      updatedAt: data['updatedAt'] is Timestamp
          ? data['updatedAt'] as Timestamp
          : null,
      timeline: List.unmodifiable(timeline),
    );
  }

  static List<OrderItem> _itemsFrom(dynamic rawItems) {
    final items = <OrderItem>[];
    if (rawItems is List) {
      for (final entry in rawItems) {
        if (entry is Map) {
          items.add(OrderItem.fromMap(Map<String, dynamic>.from(entry)));
        }
      }
    }
    return items;
  }

  List<OrderTimelineEvent> get effectiveTimeline {
    if (timeline.isNotEmpty) return timeline;
    return [
      OrderTimelineEvent(
        status: OrderStatuses.pendingConfirmation,
        title: 'Request submitted',
        at: asDate(createdAt),
      ),
    ];
  }
}
