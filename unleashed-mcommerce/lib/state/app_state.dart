import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../core/errors.dart';
import '../core/navigation.dart';
import '../models/cart_item.dart';
import '../models/product.dart';
import '../models/user_profile.dart';
import '../services/auth_service.dart';
import '../services/cart_service.dart';
import '../services/guest_cart_service.dart';
import '../services/notification_service.dart';

/// Global session state. A single instance is created in `main.dart` and
/// exposed to the widget tree through [AppStateScope].
///
/// The class deliberately keeps Firebase listeners in one place so that no
/// screen has to guess whether the profile, cart badge or notification badge
/// is current. Guests are represented by `user == null`; their cart lives in
/// [GuestCartService] and is merged into the account after authentication.
class AppState extends ChangeNotifier {
  AppState._();

  static final AppState instance = AppState._();

  User? _user;
  UserProfile? _profile;
  bool _initializing = true;
  bool _profileLoading = false;
  String? _profileError;

  int _cartCount = 0;
  int _unreadNotifications = 0;
  bool _initialized = false;
  int _generation = 0;

  bool _authPromptOpen = false;
  String? _authPromptMessage;
  List<CartItem>? _pendingCheckout;
  bool _mergingGuestCart = false;
  bool _registrationInProgress = false;
  String? _mergeMessage;
  Completer<void>? _mergeCompleter;

  StreamSubscription<User?>? _authSubscription;
  StreamSubscription? _cartSubscription;
  StreamSubscription? _notificationSubscription;

  User? get user => _user;
  UserProfile? get profile => _profile;
  bool get initializing => _initializing;
  bool get profileLoading => _profileLoading;
  String? get profileError => _profileError;

  int get cartCount => _cartCount;
  int get unreadNotifications => _unreadNotifications;
  bool get isSignedIn => _user != null;
  bool get isGuest => _user == null;
  bool get isReady =>
      _user != null && _profile != null && !needsProfileCompletion;

  bool get needsProfileCompletion =>
      _user != null && _profile != null && _profile!.needsCompletion;
  bool get isStaff => _profile?.role == 'admin';

  /// True while the temporary Firebase session created by registration is
  /// being cleaned up. The storefront must not mount during this window, or it
  /// could consume the pending checkout before the customer signs in.
  bool get registrationInProgress => _registrationInProgress;
  String get displayName =>
      _profile?.fullName ?? _user?.displayName ?? _user?.email ?? 'Guest';

  GuestCartService get guestCart => GuestCartService.instance;
  List<CartItem> get guestCartItems => GuestCartService.instance.items;
  int get guestCartCount => GuestCartService.instance.count;

  /// True while the guest checkout prompt should replace the storefront.
  bool get authPromptOpen => _authPromptOpen;
  String? get authPromptMessage => _authPromptMessage;

  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;

    await GuestCartService.instance.load();
    GuestCartService.instance.addListener(_handleGuestCartChanged);
    _cartCount = GuestCartService.instance.count;
    notifyListeners();

    _authSubscription = AuthService.instance.authStateChanges.listen(
      _handleAuthChange,
      onError: (Object error, StackTrace stack) {
        logTechnicalError('appState.authStream', error, stack);
        _initializing = false;
        notifyListeners();
      },
    );
  }

  void _handleGuestCartChanged() {
    if (_user != null) return;
    _cartCount = GuestCartService.instance.count;
    notifyListeners();
  }

  Future<void> _handleAuthChange(User? user) async {
    final generation = ++_generation;
    _resetSubscriptions();
    _user = user;

    if (user == null) {
      _profile = null;
      _profileError = null;
      _profileLoading = false;

      _cartCount = GuestCartService.instance.count;
      _unreadNotifications = 0;
      _initializing = false;
      notifyListeners();
      return;
    }

    if (generation != _generation) return;

    _profileLoading = true;
    _profileError = null;
    // Keep the splash screen up until the profile and the guest-cart merge are
    // finished. If the shell mounted earlier it could resume a pending guest
    // checkout before the selected lines reached the account cart.
    _initializing = true;
    notifyListeners();

    if (generation != _generation) return;

    try {
      _profile = await AuthService.instance.fetchProfile(user.uid);
    } catch (error, stack) {
      logTechnicalError('appState.profile', error, stack);
      _profileError = 'Your profile could not be loaded. Pull to refresh.';
    }
    if (generation != _generation) return;

    _profileLoading = false;
    _watchCounters(user.uid);

    // The short-lived session created during registration is skipped: the
    // customer is signed out immediately and the local cart is merged when
    // they sign in for the first time.
    if (!_registrationInProgress) {
      await _mergeGuestCart(user.uid);
      if (generation != _generation) return;
    }

    _initializing = false;
    notifyListeners();
  }

  void _watchCounters(String uid) {
    _cartSubscription?.cancel();
    _notificationSubscription?.cancel();
    _cartSubscription = CartService.instance
        .watchCart(uid)
        .listen(
          (items) {
            _cartCount = CartService.instance.cartCount(items);
            notifyListeners();
          },
          onError: (Object error, StackTrace stack) {
            logTechnicalError('appState.cartCount', error, stack);
          },
        );
    _notificationSubscription = NotificationService.instance
        .watchUnreadCount(uid)
        .listen(
          (count) {
            _unreadNotifications = count;
            notifyListeners();
          },
          onError: (Object error, StackTrace stack) {
            logTechnicalError('appState.notificationCount', error, stack);
          },
        );
  }

  void _resetSubscriptions() {
    _cartSubscription?.cancel();
    _notificationSubscription?.cancel();
    _cartSubscription = null;
    _notificationSubscription = null;
  }

  /// Completes when the current guest-cart merge (if any) has finished. The
  /// shell waits for this before resuming a pending checkout so it never opens
  /// the checkout with a half-merged cart.
  Future<void> get cartMergeFuture {
    if (!_mergingGuestCart) return Future<void>.value();
    return _mergeCompleter?.future ?? Future<void>.value();
  }

  Future<void> _mergeGuestCart(String uid) async {
    if (_mergingGuestCart || GuestCartService.instance.isEmpty) return;
    _mergingGuestCart = true;
    final completer = _mergeCompleter ??= Completer<void>();
    try {
      final result = await CartService.instance.mergeItems(
        uid: uid,
        items: GuestCartService.instance.items,
      );
      // Every line has either been copied or reported. Keeping merged lines
      // around would double-count them after the next sign-in.
      await GuestCartService.instance.clear();
      if (result.hasIssues) {
        final parts = <String>[];
        if (result.mergedLines > 0) {
          parts.add(
            '${result.mergedLines} saved cart '
            '${result.mergedLines == 1 ? 'line was' : 'lines were'} moved to '
            'your account',
          );
        }
        if (result.adjusted.isNotEmpty) {
          parts.add(
            '${result.adjusted.length} '
            '${result.adjusted.length == 1 ? 'line was' : 'lines were'} reduced '
            'to the available stock',
          );
        }
        if (result.skipped.isNotEmpty) {
          parts.add(
            '${result.skipped.length} unavailable '
            '${result.skipped.length == 1 ? 'item was' : 'items were'} not '
            'added',
          );
        }
        _mergeMessage = '${parts.join('. ')}.';
      } else if (result.mergedLines > 0) {
        _mergeMessage =
            'Your saved cart was added to your account '
            '(${result.mergedQuantity} '
            '${result.mergedQuantity == 1 ? 'item' : 'items'}).';
      }
    } catch (error, stack) {
      logTechnicalError('appState.mergeGuestCart', error, stack);
      _mergeMessage =
          'Your saved cart could not be merged right now. It is still stored '
          'on this device and will retry the next time you sign in.';
    } finally {
      _mergingGuestCart = false;
      if (!completer.isCompleted) completer.complete();
      if (identical(_mergeCompleter, completer)) _mergeCompleter = null;
      notifyListeners();
    }
  }

  /// Returns and clears a one-off message about the guest-cart merge.
  String? takeMergeMessage() {
    final message = _mergeMessage;
    _mergeMessage = null;
    return message;
  }

  /// Opens the auth screen from anywhere without pushing a route. [AuthGate]
  /// replaces the storefront, which keeps the navigation stack clean and lets
  /// the pending checkout resume after authentication.
  void requestSignIn({List<CartItem>? pendingCheckout, String? message}) {
    if (_user != null) return;
    _authPromptOpen = true;
    _authPromptMessage = message;
    if (pendingCheckout != null) {
      _pendingCheckout = List<CartItem>.unmodifiable(pendingCheckout);
    }
    notifyListeners();

    // The prompt lives in [AuthGate] at the root. Remove any pushed screens
    // (for example the cart opened from the catalog) so the prompt is visible
    // and the guest can finish signing in.
    unwindToRoot();
  }

  /// Returns to guest browsing without losing the local guest cart.
  void cancelAuthPrompt() {
    _authPromptOpen = false;
    _authPromptMessage = null;
    _pendingCheckout = null;
    notifyListeners();
  }

  /// Returns the checkout the guest was trying to reach, if any.
  List<CartItem>? consumePendingCheckout() {
    final items = _pendingCheckout;
    _pendingCheckout = null;
    return items;
  }

  List<CartItem>? peekPendingCheckout() => _pendingCheckout;

  Future<int> addGuestCartItem({
    required Product product,
    required String size,
    required int quantity,
  }) => GuestCartService.instance.addItem(
    product: product,
    size: size,
    quantity: quantity,
  );

  Future<void> setGuestCartQuantity({
    required CartItem item,
    required int quantity,
    Product? product,
  }) => GuestCartService.instance.setQuantity(
    item: item,
    quantity: quantity,
    product: product,
  );

  Future<void> signIn({required String email, required String password}) async {
    _registrationInProgress = false;
    await AuthService.instance.signIn(email: email, password: password);
  }

  /// Creates the account and profile, then signs the temporary Firebase
  /// session out so the customer returns to the login prompt.
  ///
  /// The guest cart and any checkout started before registration stay in local
  /// state. They are merged and resumed after the customer signs in.
  Future<void> register(RegistrationData data) async {
    _registrationInProgress = true;
    try {
      await AuthService.instance.register(data);
    } finally {
      // createUserWithEmailAndPassword signs the new account in. Signing out
      // here keeps the existing login screen visible instead of dropping the
      // customer into the storefront before they have signed in themselves.
      try {
        await AuthService.instance.signOut();
      } catch (error, stack) {
        logTechnicalError('appState.registerSignOut', error, stack);
      }
    }
    _registrationInProgress = false;
    _authPromptOpen = true;
    _authPromptMessage ??=
        'Your account is ready. Sign in to continue with your cart.';
    notifyListeners();
  }

  Future<void> signOut() async {
    _generation++;
    _resetSubscriptions();
    _authPromptOpen = false;
    _authPromptMessage = null;
    _pendingCheckout = null;
    await AuthService.instance.signOut();
  }

  Future<void> refreshProfile() async {
    final current = _user;
    if (current == null) return;
    _profileLoading = true;
    _profileError = null;
    notifyListeners();
    try {
      _profile = await AuthService.instance.fetchProfile(current.uid);
    } catch (error, stack) {
      logTechnicalError('appState.refreshProfile', error, stack);
      _profileError = 'Your profile could not be refreshed. Try again.';
    } finally {
      _profileLoading = false;
      notifyListeners();
    }
  }

  Future<void> saveProfile(UserProfile profile) async {
    await AuthService.instance.updateProfile(profile);
    _profile = profile;
    notifyListeners();
  }

  Future<void> sendVerificationEmail() =>
      AuthService.instance.sendEmailVerification();

  Future<bool> reloadEmailVerified() =>
      AuthService.instance.reloadEmailVerified();

  /// Persists a new photo (or clears it with `null`) and updates the in-memory
  /// profile only after Firestore accepts the write, so the UI never shows a
  /// photo that was not saved.
  Future<void> setProfilePhoto(String? photoUrl) async {
    final current = _profile;
    if (current == null) {
      throw const AuthFailure('Please sign in again to update your photo.');
    }
    await AuthService.instance.updatePhotoUrl(photoUrl);
    _profile = current.withPhotoUrl(photoUrl);
    notifyListeners();
  }

  @override
  void dispose() {
    GuestCartService.instance.removeListener(_handleGuestCartChanged);
    _resetSubscriptions();
    _authSubscription?.cancel();
    super.dispose();
  }
}
