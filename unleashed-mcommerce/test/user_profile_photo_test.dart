import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:unleashed_mcommerce/models/user_profile.dart';
import 'package:unleashed_mcommerce/services/profile_photo_service.dart';

UserProfile _profile({String? photoUrl}) => UserProfile(
  uid: 'customer-1',
  firstName: 'Andrei',
  lastName: 'San Juan',
  middleName: null,
  contactNumber: '09171234567',
  email: 'customer@example.com',
  birthday: DateTime(2000, 1, 1),
  address: const PostalAddress(
    street: '1 Test Street',
    barangay: 'Barangay',
    city: 'Manila',
    province: 'Metro Manila',
    postalCode: '1000',
  ),
  role: 'customer',
  totalOrders: 3,
  totalSpent: 4500,
  photoUrl: photoUrl,
);

void main() {
  group('UserProfile photoUrl', () {
    test('is null for documents created before photos existed', () {
      final profile = _profile();

      expect(profile.photoUrl, isNull);
      expect(profile.toMap()['photoUrl'], isNull);
    });

    test('round-trips a photo value in the profile document', () {
      final profile = _profile(photoUrl: 'data:image/jpeg;base64,AAAA');

      expect(profile.toMap()['photoUrl'], 'data:image/jpeg;base64,AAAA');
    });

    test('withPhotoUrl changes only the photo fields', () {
      final original = _profile();
      final updated = original.withPhotoUrl('data:image/jpeg;base64,BBBB');

      expect(updated.photoUrl, 'data:image/jpeg;base64,BBBB');
      expect(updated.uid, original.uid);
      expect(updated.fullName, original.fullName);
      expect(updated.email, original.email);
      expect(updated.totalOrders, original.totalOrders);
      expect(updated.totalSpent, original.totalSpent);
      expect(updated.address.singleLine, original.address.singleLine);

      final cleared = updated.withPhotoUrl(null);
      expect(cleared.photoUrl, isNull);
      expect(cleared.fullName, original.fullName);
    });
  });

  group('ProfilePhotoService', () {
    test('compresses a large PNG into a square JPEG data URI', () async {
      final source = img.Image(width: 1600, height: 1000);
      for (var y = 0; y < source.height; y++) {
        for (var x = 0; x < source.width; x++) {
          source.setPixelRgb(x, y, x % 256, y % 256, (x + y) % 256);
        }
      }
      final png = Uint8List.fromList(img.encodePng(source));

      final prepared = await ProfilePhotoService.instance.prepareImage(png);
      final decoded = img.decodeJpg(prepared.bytes);

      expect(prepared.dataUri, startsWith('data:image/jpeg;base64,'));
      expect(
        prepared.bytes.length,
        lessThanOrEqualTo(ProfilePhotoService.maxStoredBytes),
      );
      expect(decoded, isNotNull);
      expect(decoded!.width, ProfilePhotoService.targetDimension);
      expect(decoded.height, ProfilePhotoService.targetDimension);
    });

    test('rejects bytes that are not JPG or PNG', () async {
      await expectLater(
        ProfilePhotoService.instance.prepareImage(
          Uint8List.fromList([1, 2, 3, 4]),
        ),
        throwsA(isA<ProfilePhotoException>()),
      );
    });
  });
}
