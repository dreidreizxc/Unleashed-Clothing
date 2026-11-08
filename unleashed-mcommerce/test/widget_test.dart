import 'package:flutter_test/flutter_test.dart';

import 'package:unleashed_mcommerce/core/formatters.dart';
import 'package:unleashed_mcommerce/core/validators.dart';
import 'package:unleashed_mcommerce/models/cart_item.dart';
import 'package:unleashed_mcommerce/models/order.dart';
import 'package:unleashed_mcommerce/models/product_review.dart';
import 'package:unleashed_mcommerce/models/user_profile.dart';
import 'package:unleashed_mcommerce/services/cart_service.dart';

void main() {
  group('Money formatting', () {
    test('formats centavos as Philippine pesos', () {
      expect(formatMoney(94900), '₱949.00');
      expect(formatMoney(0), '₱0.00');
      expect(formatMoney(123456789), '₱1,234,567.89');
    });

    test('treats null and negative values as zero', () {
      expect(formatMoney(null), '₱0.00');
      expect(formatMoney(-500), '₱0.00');
    });
  });

  group('Form validation', () {
    test('requires non-empty values', () {
      expect(Validators.required('', 'First name'), 'First name is required.');
      expect(Validators.required('  ', 'First name'), 'First name is required.');
      expect(Validators.required('Andrei', 'First name'), isNull);
    });

    test('validates names', () {
      expect(Validators.name('A', 'First name'), isNotNull);
      expect(Validators.name('Andrei', 'First name'), isNull);
      expect(Validators.name('Andrei2', 'First name'), isNotNull);
      expect(Validators.middleName(''), isNull);
    });

    test('validates email addresses and Gmail restriction', () {
      expect(Validators.email('not-an-email'), isNotNull);
      expect(Validators.email('andrei@gmail.com'), isNull);
      expect(
        Validators.email('andrei@yahoo.com', requireGmail: true),
        isNotNull,
      );
      expect(
        Validators.email('andrei@gmail.com', requireGmail: true),
        isNull,
      );
    });

    test('validates Philippine mobile numbers', () {
      expect(Validators.phone('09171234567'), isNull);
      expect(Validators.phone('+639171234567'), isNull);
      expect(Validators.phone('0917 123 4567'), isNull);
      expect(Validators.phone('12345'), isNotNull);
      expect(
        Validators.normalisePhone('9171234567'),
        '09171234567',
      );
    });

    test('validates postal codes', () {
      expect(Validators.postalCode('1000'), isNull);
      expect(Validators.postalCode('100'), isNotNull);
      expect(Validators.postalCode('ABCD'), isNotNull);
    });

    test('validates passwords and confirmation', () {
      expect(Validators.password('short1'), isNotNull);
      expect(Validators.password('abcdefgh'), isNotNull);
      expect(Validators.password('abcd1234'), isNull);
      expect(Validators.confirmPassword('abcd1234', 'abcd1234'), isNull);
      expect(Validators.confirmPassword('abcd1235', 'abcd1234'), isNotNull);
    });

    test('rejects future birthdays and under-age birthdays', () {
      final now = DateTime.now();
      expect(Validators.birthday(null), isNotNull);
      expect(
        Validators.birthday(now.add(const Duration(days: 1))),
        isNotNull,
      );
      expect(
        Validators.birthday(DateTime(now.year - 5, 1, 1)),
        isNotNull,
      );
      expect(
        Validators.birthday(DateTime(now.year - 25, 1, 1)),
        isNull,
      );
    });
  });

  group('Address and cart models', () {
    test('joins a complete address in order', () {
      const address = PostalAddress(
        street: '12 Mabini Street',
        barangay: 'Poblacion',
        city: 'Makati',
        province: 'Metro Manila',
        postalCode: '1210',
      );
      expect(address.isComplete, isTrue);
      expect(
        address.singleLine,
        '12 Mabini Street, Poblacion, Makati, Metro Manila, 1210',
      );
    });

    test('detects incomplete addresses', () {
      const address = PostalAddress(
        street: '12 Mabini Street',
        barangay: '',
        city: 'Makati',
        province: 'Metro Manila',
        postalCode: '1210',
      );
      expect(address.isComplete, isFalse);
    });

    test('computes cart line subtotals and copies quantity', () {
      const item = CartItem(
        id: 'product_medium',
        productId: 'product',
        name: 'Oversized Tee',
        size: 'M',
        price: 94900,
        quantity: 2,
      );
      expect(item.subtotal, 189800);
      expect(item.priceLabel, '₱949.00');
      expect(item.copyWith(quantity: 3).quantity, 3);
      expect(item.copyWith(quantity: 3).subtotal, 284700);
    });

    test('uses a deterministic cart item id per product and size', () {
      expect(
        CartService.itemIdFor('abc123', 'M'),
        'abc123_M',
      );
      expect(
        CartService.itemIdFor('abc123', 'XL / Oversized'),
        'abc123_XLOversized',
      );
    });
  });

  group('Order and review helpers', () {
    test('computes order item subtotal and order item count', () {
      const item = OrderItem(
        productId: 'p1',
        name: 'Hoodie',
        size: 'L',
        price: 149900,
        quantity: 2,
      );
      expect(item.subtotal, 299800);

      const order = CustomerOrder(
        id: 'order-1',
        customerId: 'uid-1',
        items: [item],
        total: 299800,
        paymentMethod: 'COD',
        paymentStatus: 'unpaid',
        status: 'pending_confirmation',
        createdAt: null,
      );
      expect(order.itemCount, 2);
      expect(order.canCancel, isTrue);
      expect(order.isCompleted, isFalse);
      expect(order.isSimulatedPayment, isFalse);
    });

    test('uses a stable one-review-per-customer id', () {
      expect(
        ProductReview.idFor('product-1', 'uid-1'),
        'product-1_uid-1',
      );
    });

    test('maps internal statuses to customer-facing labels', () {
      expect(orderStatusLabel('pending_confirmation'), 'Awaiting confirmation');
      expect(orderStatusLabel('placed'), 'Order placed');
      expect(orderStatusLabel('rejected'), 'Request rejected');
      expect(orderStatusLabel('processing'), 'Preparing');
      expect(orderStatusLabel('delivered'), 'Delivered');
      expect(paymentMethodLabel('COD'), 'Cash on Delivery');
      expect(paymentMethodLabel('GCash'), 'GCash (simulated)');
      expect(paymentMethodLabel('Card'), 'Card (simulated)');
    });
  });
}
