/// Application-wide configuration for the Unleashed Clothing storefront.
///
/// Values that depend on the Firebase project are centralised here so that
/// screens never hard-code collection names or store copy.
class AppConfig {
  AppConfig._();

  static const String storeName = 'Unleashed Clothing';
  static const String storeShortName = 'UNLEASHED';
  static const String currencyCode = 'PHP';
  static const String currencySymbol = '\u20B1';

  /// Collections shared with the admin dashboard.
  static const String usersCollection = 'users';
  static const String productsCollection = 'products';
  static const String productImagesCollection = 'product_images';
  static const String cartsCollection = 'carts';
  static const String ordersCollection = 'orders';
  static const String transactionsCollection = 'transactions';
  static const String notificationsCollection = 'notifications';
  static const String chatsCollection = 'chats';
  static const String reviewsCollection = 'reviews';
  static const String announcementsCollection = 'announcements';
  static const String settingsCollection = 'settings';
  static const String countersCollection = 'counters';

  /// Store settings document used by the admin dashboard.
  static const String storeSettingsDoc = 'store';

  /// Security settings document used for security-related app configuration.
  static const String securitySettingsDoc = 'security';

  static const List<String> categories = ['T-Shirt', 'Cap', 'Hoodie'];

  /// Reasonable client-side limits mirrored by backend validation.
  static const int maxCartQuantity = 20;
  static const int maxOrderLines = 50;
  static const int maxReviewLength = 1000;
  static const int minPasswordLength = 8;

  /// Support chat copy.
  static const int maxChatMessageLength = 2000;
}
