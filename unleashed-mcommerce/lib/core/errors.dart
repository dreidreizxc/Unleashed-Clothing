import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../config/app_config.dart';

/// Converts Firebase exceptions into short, customer-safe messages. Raw codes
/// remain available to `debugPrint` during development only.
String readableAuthError(Object error) {
  if (error is FirebaseAuthException) {
    switch (error.code) {
      case 'invalid-email':
        return 'That email address is not valid.';
      case 'user-disabled':
        return 'This account has been disabled. Please contact support.';
      case 'user-not-found':
      case 'wrong-password':
      case 'invalid-credential':
        return 'Email or password is incorrect.';
      case 'email-already-in-use':
        return 'An account already exists for this email. Try signing in instead.';
      case 'weak-password':
        return 'Choose a stronger password (at least ${AppConfig.minPasswordLength} characters).';
      case 'too-many-requests':
        return 'Too many attempts. Please wait a moment and try again.';
      case 'network-request-failed':
        return 'No internet connection. Check your network and try again.';
      case 'requires-recent-login':
        return 'Please sign in again before making this change.';
      case 'operation-not-allowed':
        return 'Email/password sign-in is not enabled for this project.';
      default:
        return error.message ?? 'Authentication failed. Please try again.';
    }
  }
  return 'Something went wrong. Please try again.';
}

void logTechnicalError(String scope, Object error, [StackTrace? stack]) {
  if (kDebugMode) {
    debugPrint('[Unleashed] $scope: $error');
    if (stack != null) debugPrintStack(stackTrace: stack, maxFrames: 12);
  }
}
