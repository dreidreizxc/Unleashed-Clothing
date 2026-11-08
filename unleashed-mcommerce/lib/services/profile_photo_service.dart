import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';

/// Raised for problems that should be shown to the customer as-is.
class ProfilePhotoException implements Exception {
  const ProfilePhotoException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// A photo that is ready to be written to the customer's profile document.
class PreparedProfilePhoto {
  const PreparedProfilePhoto({required this.bytes, required this.dataUri});

  /// The compressed JPEG bytes, used for the on-screen preview.
  final Uint8List bytes;

  /// `data:image/jpeg;base64,...` value stored in the `photoUrl` field.
  final String dataUri;
}

/// Picks a gallery image and turns it into a small square JPEG.
///
/// The project runs on the Firebase Spark plan, which cannot create a Cloud
/// Storage bucket. The compressed result therefore travels to Firestore as a
/// data URI. Keeping this logic in one service means a future Storage
/// migration only needs to replace the upload call in [AuthService].
class ProfilePhotoService {
  ProfilePhotoService._();

  static final ProfilePhotoService instance = ProfilePhotoService._();

  /// Largest original file accepted from the gallery.
  static const int maxSourceBytes = 15 * 1024 * 1024;

  /// Largest compressed JPEG accepted for Firestore.
  static const int maxStoredBytes = 300 * 1024;

  /// Avatars are displayed at 62-96 px; 512 px keeps them sharp on all
  /// densities without wasting document space.
  static const int targetDimension = 512;

  /// Picks an image from the device gallery. Returns `null` when the customer
  /// cancels the picker.
  Future<PreparedProfilePhoto?> pickFromGallery({
    void Function(double progress, String label)? onProgress,
  }) async {
    onProgress?.call(0.05, 'Opening gallery');

    final XFile? file;
    try {
      file = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        maxWidth: 2048,
        maxHeight: 2048,
        imageQuality: 92,
      );
    } catch (error, stack) {
      debugPrint('[ProfilePhoto] picker failed: $error');
      debugPrintStack(stackTrace: stack, maxFrames: 6);
      throw const ProfilePhotoException(
        'Your gallery could not be opened. Please try again.',
      );
    }

    if (file == null) return null;

    final Uint8List original;
    try {
      original = await file.readAsBytes();
    } catch (error, stack) {
      debugPrint('[ProfilePhoto] read failed: $error');
      debugPrintStack(stackTrace: stack, maxFrames: 6);
      throw const ProfilePhotoException(
        'That image could not be read. Please choose another photo.',
      );
    }

    if (original.isEmpty) {
      throw const ProfilePhotoException(
        'That image is empty. Please choose another photo.',
      );
    }

    return prepareImage(original, onProgress: onProgress);
  }

  /// Validates and compresses gallery bytes. Exposed separately so the
  /// compression path can be tested without opening a platform picker.
  Future<PreparedProfilePhoto> prepareImage(
    Uint8List original, {
    void Function(double progress, String label)? onProgress,
  }) async {
    if (original.isEmpty) {
      throw const ProfilePhotoException(
        'That image is empty. Please choose another photo.',
      );
    }
    if (original.length > maxSourceBytes) {
      throw const ProfilePhotoException(
        'That image is too large. Please choose a photo under 15 MB.',
      );
    }
    if (!_looksLikeJpeg(original) && !_looksLikePng(original)) {
      throw const ProfilePhotoException(
        'Please choose a JPG, JPEG, or PNG image.',
      );
    }

    onProgress?.call(0.3, 'Optimising photo');

    final Uint8List? compressed;
    try {
      compressed = await compute(_prepareInIsolate, original);
    } catch (error, stack) {
      debugPrint('[ProfilePhoto] compression failed: $error');
      debugPrintStack(stackTrace: stack, maxFrames: 6);
      throw const ProfilePhotoException(
        'That image could not be processed. Please choose another photo.',
      );
    }

    if (compressed == null || compressed.isEmpty) {
      throw const ProfilePhotoException(
        'That image could not be processed. Please choose another photo.',
      );
    }
    if (compressed.length > maxStoredBytes) {
      throw const ProfilePhotoException(
        'That photo is still too large after resizing. Please choose a '
        'smaller image.',
      );
    }

    onProgress?.call(0.85, 'Preparing preview');

    return PreparedProfilePhoto(
      bytes: compressed,
      dataUri: 'data:image/jpeg;base64,${base64Encode(compressed)}',
    );
  }

  static bool _looksLikeJpeg(Uint8List bytes) =>
      bytes.length >= 3 &&
      bytes[0] == 0xFF &&
      bytes[1] == 0xD8 &&
      bytes[2] == 0xFF;

  static bool _looksLikePng(Uint8List bytes) =>
      bytes.length >= 8 &&
      bytes[0] == 0x89 &&
      bytes[1] == 0x50 &&
      bytes[2] == 0x4E &&
      bytes[3] == 0x47 &&
      bytes[4] == 0x0D &&
      bytes[5] == 0x0A &&
      bytes[6] == 0x1A &&
      bytes[7] == 0x0A;
}

/// Runs off the UI isolate. Centre-crops the image square, scales it down and
/// lowers JPEG quality until the result fits comfortably in a Firestore
/// document.
Uint8List? _prepareInIsolate(Uint8List source) {
  final decoded = img.decodeImage(source);
  if (decoded == null) return null;

  var image = img.bakeOrientation(decoded);
  final side = math.min(image.width, image.height);
  if (side <= 0) return null;

  image = img.copyCrop(
    image,
    x: (image.width - side) ~/ 2,
    y: (image.height - side) ~/ 2,
    width: side,
    height: side,
  );

  if (image.width > ProfilePhotoService.targetDimension) {
    image = img.copyResize(
      image,
      width: ProfilePhotoService.targetDimension,
      height: ProfilePhotoService.targetDimension,
      interpolation: img.Interpolation.average,
    );
  }

  for (var quality = 78; quality >= 40; quality -= 8) {
    final encoded = Uint8List.fromList(img.encodeJpg(image, quality: quality));
    if (encoded.length <= ProfilePhotoService.maxStoredBytes) {
      return encoded;
    }
  }

  // Very detailed images can still be large at the lowest quality. A final
  // downscale guarantees the Firestore document stays far below 1 MiB.
  image = img.copyResize(
    image,
    width: 320,
    height: 320,
    interpolation: img.Interpolation.average,
  );

  final fallback = Uint8List.fromList(img.encodeJpg(image, quality: 55));
  return fallback.length <= ProfilePhotoService.maxStoredBytes
      ? fallback
      : null;
}
