import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:unleashed_mcommerce/config/app_config.dart';
import 'package:unleashed_mcommerce/models/announcement.dart';
import 'package:unleashed_mcommerce/models/cart_item.dart';
import 'package:unleashed_mcommerce/models/cart_selection.dart';
import 'package:unleashed_mcommerce/models/product.dart';
import 'package:unleashed_mcommerce/models/user_profile.dart';
import 'package:unleashed_mcommerce/services/cart_service.dart';
import 'package:unleashed_mcommerce/services/guest_cart_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  group('Guest cart persistence', () {
    test('round-trips a cart line through the local storage map', () {
      final addedAt = Timestamp.fromMillisecondsSinceEpoch(1730000000000);
      final item = CartItem(
        id: CartService.itemIdFor('tee-1', 'M'),
        productId: 'tee-1',
        name: 'Unleashed Classic Tee',
        size: 'M',
        price: 94900,
        quantity: 3,
        imageId: 'tee-1',
        category: 'T-Shirt',
        addedAt: addedAt,
      );

      final restored = CartItem.fromLocalMap(item.toLocalMap());

      expect(restored, isNotNull);
      expect(restored!.id, 'tee-1_M');
      expect(restored.productId, 'tee-1');
      expect(restored.name, 'Unleashed Classic Tee');
      expect(restored.size, 'M');
      expect(restored.price, 94900);
      expect(restored.quantity, 3);
      expect(restored.imageId, 'tee-1');
      expect(restored.category, 'T-Shirt');
      expect(restored.addedAt?.millisecondsSinceEpoch, 1730000000000);
      expect(restored.subtotal, 284700);
    });

    test('drops malformed stored lines instead of throwing', () {
      expect(CartItem.fromLocalMap(const {}), isNull);
      expect(
        CartItem.fromLocalMap(const {
          'id': 'tee-1_M',
          'productId': 'tee-1',
          'size': '',
        }),
        isNull,
      );
      expect(
        CartItem.fromLocalMap(const {'productId': 'tee-1', 'size': 'M'}),
        isNull,
      );
    });

    test('clamps invalid stored quantities and defaults prices', () {
      final restored = CartItem.fromLocalMap(const {
        'id': 'tee-1_M',
        'productId': 'tee-1',
        'size': 'M',
        'quantity': 0,
      });

      expect(restored, isNotNull);
      expect(restored!.quantity, 1);
      expect(restored.price, 0);
      expect(restored.name, 'Product');
    });

    test('totals guest lines with the shared cart helpers', () {
      const items = [
        CartItem(
          id: 'tee-1_M',
          productId: 'tee-1',
          name: 'Tee',
          size: 'M',
          price: 94900,
          quantity: 2,
        ),
        CartItem(
          id: 'tee-1_L',
          productId: 'tee-1',
          name: 'Tee',
          size: 'L',
          price: 94900,
          quantity: 1,
        ),
      ];

      expect(CartService.instance.cartCount(items), 3);
      expect(CartService.instance.cartTotal(items), 284700);
    });
  });

  group('Cart selection', () {
    const teeM = CartItem(
      id: 'tee-1_M',
      productId: 'tee-1',
      name: 'Tee',
      size: 'M',
      price: 94900,
      quantity: 2,
    );
    const teeL = CartItem(
      id: 'tee-1_L',
      productId: 'tee-1',
      name: 'Tee',
      size: 'L',
      price: 94900,
      quantity: 1,
    );
    const items = [teeM, teeL];

    test('selects every line by default', () {
      final selection = CartSelection();

      expect(selection.selected(items).map((item) => item.id), [
        'tee-1_M',
        'tee-1_L',
      ]);
      expect(selection.quantity(items), 3);
      expect(selection.subtotal(items), 284700);
    });

    test('supports partial selection, select all, and clear all', () {
      final selection = CartSelection()..setSelected(teeM, false);

      expect(selection.selected(items).map((item) => item.id), ['tee-1_L']);
      expect(selection.quantity(items), 1);
      expect(selection.subtotal(items), 94900);

      selection.selectAll(items);
      expect(selection.selected(items).map((item) => item.id), [
        'tee-1_M',
        'tee-1_L',
      ]);

      selection.clearAll(items);
      expect(selection.selected(items), isEmpty);
      expect(selection.subtotal(items), 0);
    });

    test('new lines are selected and forgotten lines are restored', () {
      const hoodie = CartItem(
        id: 'hoodie-1_M',
        productId: 'hoodie-1',
        name: 'Hoodie',
        size: 'M',
        price: 149900,
        quantity: 1,
      );
      final selection = CartSelection()..setSelected(teeM, false);

      expect(selection.selected([...items, hoodie]).map((item) => item.id), [
        'tee-1_L',
        'hoodie-1_M',
      ]);

      selection.forget(teeM.id);
      expect(selection.isSelected(teeM), isTrue);
    });
  });

  group('Guest cart device storage', () {
    Product tee({
      String id = 'tee-persist',
      int price = 100000,
      int stock = 5,
      String status = 'active',
    }) {
      return Product(
        id: id,
        name: 'Persisted Tee',
        description: 'A T-shirt used by the guest cart tests.',
        price: price,
        category: 'T-Shirt',
        sizes: const ['M'],
        stock: {'M': stock},
        totalStock: stock,
        status: status,
      );
    }

    setUpAll(() async {
      SharedPreferences.setMockInitialValues({});
      await GuestCartService.instance.load();
    });

    setUp(() async {
      await GuestCartService.instance.clear();
    });

    test('adds a line and writes it to local storage', () async {
      final quantity = await GuestCartService.instance.addItem(
        product: tee(),
        size: 'M',
        quantity: 2,
      );

      expect(quantity, 2);
      expect(GuestCartService.instance.items, hasLength(1));
      expect(GuestCartService.instance.count, 2);
      expect(GuestCartService.instance.total, 200000);
      expect(GuestCartService.instance.find('tee-persist', 'M')?.quantity, 2);

      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(GuestCartService.storageKey);
      expect(raw, isNotNull);
      expect(raw, contains('tee-persist'));
      expect(raw, contains('"quantity":2'));
    });

    test('merges repeated adds and refuses to exceed stock', () async {
      await GuestCartService.instance.addItem(
        product: tee(),
        size: 'M',
        quantity: 2,
      );
      await GuestCartService.instance.addItem(
        product: tee(),
        size: 'M',
        quantity: 1,
      );

      expect(GuestCartService.instance.items, hasLength(1));
      expect(GuestCartService.instance.find('tee-persist', 'M')?.quantity, 3);

      await expectLater(
        GuestCartService.instance.addItem(
          product: tee(),
          size: 'M',
          quantity: 3,
        ),
        throwsA(isA<CartFailure>()),
      );
    });

    test('rejects inactive and out-of-stock products', () async {
      await expectLater(
        GuestCartService.instance.addItem(
          product: tee(status: 'inactive'),
          size: 'M',
          quantity: 1,
        ),
        throwsA(isA<CartFailure>()),
      );
      await expectLater(
        GuestCartService.instance.addItem(
          product: tee(stock: 0),
          size: 'M',
          quantity: 1,
        ),
        throwsA(isA<CartFailure>()),
      );
    });

    test('updates quantities, removes lines, and clears storage', () async {
      await GuestCartService.instance.addItem(
        product: tee(),
        size: 'M',
        quantity: 1,
      );
      final item = GuestCartService.instance.items.single;
      await GuestCartService.instance.setQuantity(
        item: item,
        quantity: 4,
        product: tee(),
      );
      expect(GuestCartService.instance.find('tee-persist', 'M')?.quantity, 4);

      await GuestCartService.instance.removeItem(item.id);
      expect(GuestCartService.instance.isEmpty, isTrue);

      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(GuestCartService.storageKey);
      expect(raw, '[]');
    });

    test('syncs stored prices from the live catalog', () async {
      await GuestCartService.instance.addItem(
        product: tee(),
        size: 'M',
        quantity: 1,
      );

      final updated = await GuestCartService.instance.syncPrices({
        'tee-persist': tee(price: 120000),
      });

      expect(updated, 1);
      expect(GuestCartService.instance.find('tee-persist', 'M')?.price, 120000);
    });

    test('removes only the selected lines in one storage write', () async {
      await GuestCartService.instance.addItem(
        product: tee(id: 'tee-a'),
        size: 'M',
        quantity: 1,
      );
      await GuestCartService.instance.addItem(
        product: tee(id: 'tee-b'),
        size: 'M',
        quantity: 2,
      );

      final keep = CartService.itemIdFor('tee-b', 'M');
      await GuestCartService.instance.removeItems([
        CartService.itemIdFor('tee-a', 'M'),
      ]);

      expect(GuestCartService.instance.items.map((item) => item.id), [keep]);
      expect(GuestCartService.instance.count, 2);

      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(GuestCartService.storageKey);
      expect(raw, isNot(contains('tee-a')));
      expect(raw, contains('tee-b'));
    });
  });

  group('Cart merge reporting', () {
    test('reports a clean merge', () {
      const result = CartMergeResult(
        mergedLines: 2,
        mergedQuantity: 3,
        skipped: [],
        adjusted: [],
      );

      expect(result.mergedLines, 2);
      expect(result.mergedQuantity, 3);
      expect(result.hasIssues, isFalse);
    });

    test('flags skipped and adjusted lines', () {
      const skipped = CartMergeResult(
        mergedLines: 1,
        mergedQuantity: 1,
        skipped: ['Sold Out Tee (M)'],
        adjusted: [],
      );
      const adjusted = CartMergeResult(
        mergedLines: 1,
        mergedQuantity: 1,
        skipped: [],
        adjusted: ['Oversized Tee (L)'],
      );

      expect(skipped.hasIssues, isTrue);
      expect(adjusted.hasIssues, isTrue);
    });
  });

  group('Public announcements', () {
    test('reads announcement fields and defaults', () {
      final announcement = Announcement.fromMap({
        'title': '  Holiday schedule  ',
        'body': '  Orders ship in January.  ',
      }, id: 'a1');

      expect(announcement.id, 'a1');
      expect(announcement.title, 'Holiday schedule');
      expect(announcement.body, 'Orders ship in January.');
      expect(announcement.active, isTrue);
      expect(announcement.pinned, isFalse);
    });

    test('accepts the legacy message field and respects flags', () {
      final announcement = Announcement.fromMap({
        'title': 'Restock',
        'message': 'New tees are live.',
        'active': false,
        'pinned': true,
      }, id: 'a2');

      expect(announcement.body, 'New tees are live.');
      expect(announcement.active, isFalse);
      expect(announcement.pinned, isTrue);
    });

    test('serializes admin edits with trimmed text and flags', () {
      const announcement = Announcement(
        id: 'a3',
        title: '  New drop  ',
        body: '  Friday 8pm.  ',
        active: true,
        pinned: true,
      );

      final map = announcement.toMap();

      expect(map['title'], 'New drop');
      expect(map['body'], 'Friday 8pm.');
      expect(map['active'], isTrue);
      expect(map['pinned'], isTrue);
      expect(map.containsKey('updatedAt'), isTrue);
    });
  });

  group('Profile completion', () {
    UserProfile profile({
      String firstName = 'Andrei',
      String lastName = 'San Juan',
      String contactNumber = '09171234567',
      DateTime? birthday,
      bool hasBirthday = true,
      PostalAddress? address,
    }) {
      return UserProfile(
        uid: 'uid-1',
        firstName: firstName,
        lastName: lastName,
        middleName: null,
        contactNumber: contactNumber,
        email: 'andrei@gmail.com',
        birthday: hasBirthday ? (birthday ?? DateTime(1998, 5, 12)) : null,
        address:
            address ??
            const PostalAddress(
              street: '12 Mabini Street',
              barangay: 'Poblacion',
              city: 'Makati',
              province: 'Metro Manila',
              postalCode: '1210',
            ),
        role: 'customer',
        totalOrders: 0,
        totalSpent: 0,
      );
    }

    test('flags an account with missing delivery details', () {
      expect(profile(firstName: '', contactNumber: '').needsCompletion, isTrue);
      expect(profile(hasBirthday: false).needsCompletion, isTrue);
      expect(
        profile(
          address: const PostalAddress(
            street: '',
            barangay: '',
            city: '',
            province: '',
            postalCode: '',
          ),
        ).needsCompletion,
        isTrue,
      );
    });

    test('accepts a fully completed profile', () {
      expect(profile().needsCompletion, isFalse);
    });
  });

  group('Catalog scope', () {
    test('the customer catalog supports T-shirts, caps and hoodies', () {
      expect(AppConfig.categories, ['T-Shirt', 'Cap', 'Hoodie']);
      expect(AppConfig.announcementsCollection, 'announcements');
    });
  });
}
