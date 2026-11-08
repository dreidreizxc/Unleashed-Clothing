import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../config/app_config.dart';
import '../core/errors.dart';
import '../core/formatters.dart';
import '../core/validators.dart';
import '../models/user_profile.dart';

class RegistrationData {
  const RegistrationData({
    required this.firstName,
    required this.lastName,
    required this.middleName,
    required this.contactNumber,
    required this.email,
    required this.birthday,
    required this.address,
    required this.password,
  });

  final String firstName;
  final String lastName;
  final String? middleName;
  final String contactNumber;
  final String email;
  final DateTime birthday;
  final PostalAddress address;
  final String password;

  UserProfile toProfile(String uid) => UserProfile(
    uid: uid,
    firstName: firstName.trim(),
    lastName: lastName.trim(),
    middleName: (middleName ?? '').trim().isEmpty ? null : middleName!.trim(),
    contactNumber: Validators.normalisePhone(contactNumber),
    email: email.trim().toLowerCase(),
    birthday: birthday,
    address: address,
    role: 'customer',
    totalOrders: 0,
    totalSpent: 0,
  );
}

class AuthService {
  AuthService._();

  static final AuthService instance = AuthService._();

  FirebaseAuth get _auth => FirebaseAuth.instance;
  FirebaseFirestore get _db => FirebaseFirestore.instance;

  User? get currentUser => _auth.currentUser;

  Stream<User?> get authStateChanges => _auth.authStateChanges();

  Future<UserCredential> signIn({
    required String email,
    required String password,
  }) async {
    try {
      return await _auth.signInWithEmailAndPassword(
        email: email.trim().toLowerCase(),
        password: password,
      );
    } on FirebaseAuthException catch (error, stack) {
      logTechnicalError('signIn', error, stack);
      throw AuthFailure(readableAuthError(error));
    } catch (error, stack) {
      logTechnicalError('signIn', error, stack);
      if (error is AuthFailure) rethrow;
      throw const AuthFailure('Could not sign in. Please try again.');
    }
  }

  Future<UserCredential> register(RegistrationData data) async {
    User? created;
    try {
      final credential = await _auth.createUserWithEmailAndPassword(
        email: data.email.trim().toLowerCase(),
        password: data.password,
      );
      created = credential.user;
      if (created == null) {
        throw const AuthFailure('Your account could not be created.');
      }

      final profile = data.toProfile(created.uid);
      await created.updateDisplayName(profile.fullName);

      await _db.collection(AppConfig.usersCollection).doc(created.uid).set({
        ...profile.toMap(),
        'uid': created.uid,
        'role': 'customer',
        'isActive': true,
        'totalOrders': 0,
        'totalSpent': 0,
        'fcmTokens': <String>[],
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      return credential;
    } on FirebaseAuthException catch (error, stack) {
      logTechnicalError('register', error, stack);
      if (created != null) {
        try {
          await created.delete();
        } catch (cleanupError, cleanupStack) {
          logTechnicalError('register.cleanup', cleanupError, cleanupStack);
        }
      }
      throw AuthFailure(readableAuthError(error));
    } catch (error, stack) {
      logTechnicalError('register', error, stack);
      if (created != null) {
        try {
          await created.delete();
        } catch (cleanupError, cleanupStack) {
          logTechnicalError('register.cleanup', cleanupError, cleanupStack);
        }
      }
      if (error is AuthFailure) rethrow;
      throw const AuthFailure(
        'We could not finish creating your account. Please try again.',
      );
    }
  }

  Future<void> sendPasswordReset(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email.trim().toLowerCase());
    } catch (error, stack) {
      logTechnicalError('sendPasswordReset', error, stack);
      throw AuthFailure(readableAuthError(error));
    }
  }

  /// Sends Firebase's built-in verification email to the signed-in customer.
  /// This is optional and is never called during registration, login, or
  /// checkout.
  Future<void> sendEmailVerification() async {
    final user = currentUser;
    if (user == null) {
      throw const AuthFailure('Please sign in again to verify your email.');
    }
    if (user.emailVerified) {
      throw const AuthFailure('Your email address is already verified.');
    }
    try {
      await user.sendEmailVerification();
    } on FirebaseAuthException catch (error, stack) {
      logTechnicalError('sendEmailVerification', error, stack);
      if (error.code == 'email-already-verified') {
        throw const AuthFailure('Your email address is already verified.');
      }
      throw AuthFailure(readableAuthError(error));
    } catch (error, stack) {
      logTechnicalError('sendEmailVerification', error, stack);
      throw const AuthFailure(
        'The verification email could not be sent. Please try again.',
      );
    }
  }

  /// Reloads the Firebase user so `emailVerified` reflects the latest click on
  /// the verification link. Returns the refreshed value.
  Future<bool> reloadEmailVerified() async {
    final user = currentUser;
    if (user == null) {
      throw const AuthFailure('Please sign in again to check your email.');
    }
    try {
      await user.reload();
      return _auth.currentUser?.emailVerified ?? false;
    } catch (error, stack) {
      logTechnicalError('reloadEmailVerified', error, stack);
      throw const AuthFailure(
        'Your verification status could not be refreshed. Check your '
        'connection and try again.',
      );
    }
  }

  /// Saves or clears the profile photo on the customer's own profile document.
  /// The update touches only `photoUrl` and `updatedAt`, so the rest of the
  /// profile cannot be overwritten by a photo change.
  Future<void> updatePhotoUrl(String? photoUrl) async {
    final user = currentUser;
    if (user == null) {
      throw const AuthFailure('Please sign in again to update your photo.');
    }
    final value = photoUrl?.trim();
    if (value != null) {
      if (!value.startsWith('data:image/') || !value.contains(';base64,')) {
        throw const AuthFailure('That photo could not be processed.');
      }
      // Firestore documents are capped at 1 MiB. The picker compresses well
      // below this, and the limit is a final guard against oversized writes.
      if (value.length > 480000) {
        throw const AuthFailure(
          'That photo is too large. Please choose a smaller image.',
        );
      }
    }
    try {
      await _db.collection(AppConfig.usersCollection).doc(user.uid).update({
        'photoUrl': value ?? FieldValue.delete(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (error, stack) {
      logTechnicalError('updatePhotoUrl', error, stack);
      throw const AuthFailure(
        'Your profile photo could not be saved. Check your connection and try '
        'again.',
      );
    }
  }

  Future<void> signOut() async {
    try {
      await _auth.signOut();
    } catch (error, stack) {
      logTechnicalError('signOut', error, stack);
      throw const AuthFailure('Could not sign out. Please try again.');
    }
  }

  Future<UserProfile?> fetchProfile(String uid) async {
    final doc = await _db.collection(AppConfig.usersCollection).doc(uid).get();
    if (!doc.exists) return null;
    return UserProfile.fromDoc(doc, fallbackEmail: currentUser?.email ?? '');
  }

  Future<void> updateProfile(UserProfile profile) async {
    final current = currentUser;
    if (current == null || current.uid != profile.uid) {
      throw const AuthFailure('Please sign in again to update your profile.');
    }
    final existing = await _db
        .collection(AppConfig.usersCollection)
        .doc(profile.uid)
        .get();
    final existingData = existing.data() ?? <String, dynamic>{};

    // Preserve system-managed fields so Firestore rules remain satisfied.
    await _db.collection(AppConfig.usersCollection).doc(profile.uid).update({
      ...profile.toMap(),
      'role': existingData['role'] ?? 'customer',
      'totalOrders': existingData['totalOrders'] ?? 0,
      'totalSpent': existingData['totalSpent'] ?? 0,
      'updatedAt': FieldValue.serverTimestamp(),
    });

    if (current.displayName != profile.fullName) {
      try {
        await current.updateDisplayName(profile.fullName);
      } catch (error, stack) {
        logTechnicalError('updateDisplayName', error, stack);
      }
    }
  }

  /// Used by the profile screen to show when the account was created.
  String get formattedCreatedAt {
    final metadata = currentUser?.metadata.creationTime;
    return metadata == null ? 'â€”' : formatDate(metadata);
  }
}

class AuthFailure implements Exception {
  const AuthFailure(this.message);

  final String message;

  @override
  String toString() => message;
}
