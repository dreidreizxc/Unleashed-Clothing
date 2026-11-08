import '../config/app_config.dart';
import '../models/cart_item.dart';
import '../models/user_profile.dart';

/// Pure checkout input checks shared by the UI and [OrderService].
///
/// Keeping these separate from Firebase makes the rules easy to unit test and
/// ensures the same rejection messages are used before the callable function or
/// the Firestore transaction is attempted. The backend repeats every check
/// because client-side validation is only a convenience, never enforcement.
class CheckoutValidation {
  CheckoutValidation._();

  static const List<String> paymentMethods = ['COD', 'GCash', 'Card'];

  /// Returns a customer-facing error, or `null` when the request is safe to
  /// send to the backend.
  static String? validate({
    required String? authUid,
    required UserProfile profile,
    required List<CartItem> items,
    required String paymentMethod,
  }) {
    if (authUid == null) {
      return 'Sign in to place an order.';
    }
    if (authUid != profile.uid) {
      return 'Your session changed. Please sign in again.';
    }
    if (!profile.isActive) {
      return 'This account cannot place orders. Please contact the store.';
    }
    if (items.isEmpty) {
      return 'Your cart is empty.';
    }
    if (items.length > AppConfig.maxOrderLines) {
      return 'This order has too many items. Remove a few and try again.';
    }
    if (!paymentMethods.contains(paymentMethod)) {
      return 'Choose a valid payment method.';
    }
    if (!profile.address.isComplete) {
      return 'Complete your delivery address before placing an order.';
    }
    if (profile.contactNumber.trim().isEmpty) {
      return 'Add a contact number before placing an order.';
    }
    for (final item in items) {
      if (item.productId.trim().isEmpty || item.size.trim().isEmpty) {
        return 'An item in your cart is invalid. Remove it and try again.';
      }
      if (item.quantity < 1) {
        return 'Choose a valid quantity for every item.';
      }
      if (item.quantity > AppConfig.maxCartQuantity) {
        return 'You have reached the maximum quantity for an item.';
      }
    }
    return null;
  }
}
