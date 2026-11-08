import 'package:flutter_test/flutter_test.dart';
import 'package:unleashed_mcommerce/models/cart_item.dart';
import 'package:unleashed_mcommerce/models/user_profile.dart';
import 'package:unleashed_mcommerce/services/checkout_validation.dart';
import 'package:unleashed_mcommerce/services/order_service.dart';

void main() {
  const address = PostalAddress(
    street: '12 Mabini Street',
    barangay: 'Poblacion',
    city: 'Makati',
    province: 'Metro Manila',
    postalCode: '1210',
  );

  UserProfile profile({
    String uid = 'uid-1',
    String contactNumber = '09171234567',
    PostalAddress shippingAddress = address,
    bool isActive = true,
  }) {
    return UserProfile(
      uid: uid,
      firstName: 'Andrei',
      lastName: 'San Juan',
      middleName: null,
      contactNumber: contactNumber,
      email: 'andrei@gmail.com',
      birthday: DateTime(1998, 5, 12),
      address: shippingAddress,
      role: 'customer',
      totalOrders: 0,
      totalSpent: 0,
      isActive: isActive,
    );
  }

  const item = CartItem(
    id: 'tee-1_M',
    productId: 'tee-1',
    name: 'Unleashed Tee',
    size: 'M',
    price: 94900,
    quantity: 2,
  );

  String? validate({
    String? authUid = 'uid-1',
    UserProfile? buyer,
    List<CartItem> items = const [item],
    String paymentMethod = 'COD',
  }) {
    return CheckoutValidation.validate(
      authUid: authUid,
      profile: buyer ?? profile(),
      items: items,
      paymentMethod: paymentMethod,
    );
  }

  group('Checkout validation', () {
    test('accepts an authenticated, complete COD request', () {
      expect(validate(), isNull);
      expect(validate(paymentMethod: 'GCash'), isNull);
      expect(validate(paymentMethod: 'Card'), isNull);
    });

    test('rejects guests and stale sessions', () {
      expect(validate(authUid: null), contains('Sign in'));
      expect(validate(authUid: 'uid-2'), contains('session changed'));
    });

    test('rejects inactive accounts', () {
      expect(
        validate(buyer: profile(isActive: false)),
        contains('cannot place'),
      );
    });

    test('rejects empty carts and unsupported payment methods', () {
      expect(validate(items: const []), contains('cart is empty'));
      expect(
        validate(paymentMethod: 'BankTransfer'),
        contains('payment method'),
      );
    });

    test('rejects an incomplete delivery address', () {
      const incomplete = PostalAddress(
        street: '',
        barangay: 'Poblacion',
        city: 'Makati',
        province: 'Metro Manila',
        postalCode: '1210',
      );

      expect(
        validate(buyer: profile(shippingAddress: incomplete)),
        contains('delivery address'),
      );
    });

    test('rejects a missing contact number', () {
      expect(
        validate(buyer: profile(contactNumber: '   ')),
        contains('contact number'),
      );
    });

    test('rejects invalid line quantities and identities', () {
      const zeroQuantity = CartItem(
        id: 'tee-1_M',
        productId: 'tee-1',
        name: 'Unleashed Tee',
        size: 'M',
        price: 94900,
        quantity: 0,
      );
      const tooMany = CartItem(
        id: 'tee-1_M',
        productId: 'tee-1',
        name: 'Unleashed Tee',
        size: 'M',
        price: 94900,
        quantity: 21,
      );
      const noSize = CartItem(
        id: 'tee-1_',
        productId: 'tee-1',
        name: 'Unleashed Tee',
        size: '',
        price: 94900,
        quantity: 1,
      );

      expect(validate(items: const [zeroQuantity]), contains('quantity'));
      expect(validate(items: const [tooMany]), contains('maximum quantity'));
      expect(validate(items: const [noSize]), contains('invalid'));
    });
  });

  group('Checkout idempotency', () {
    test('client order ids are unique and match the backend format', () {
      final ids = List.generate(
        25,
        (_) => OrderService.instance.newClientOrderId('uid-1'),
      );

      expect(ids.toSet(), hasLength(ids.length));
      final pattern = RegExp(r'^[A-Za-z0-9_-]{8,160}$');
      for (final id in ids) {
        expect(pattern.hasMatch(id), isTrue, reason: id);
      }
    });
  });
}
