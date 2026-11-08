/// Client-side form validation. The same rules are enforced again by Cloud
/// Functions and Firestore Security Rules for anything security sensitive.
class Validators {
  Validators._();

  static final RegExp _email = RegExp(
    r'^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$',
  );
  static final RegExp _phonePh = RegExp(r'^(?:\+63|0)9\d{9}$');
  static final RegExp _postalPh = RegExp(r'^\d{4}$');
  static final RegExp _name = RegExp(r"^[A-Za-z\u00C0-\u024F .'-]+$");

  static String? required(String? value, [String label = 'This field']) {
    if (value == null || value.trim().isEmpty) return '$label is required.';
    return null;
  }

  static String? name(String? value, String label) {
    final empty = required(value, label);
    if (empty != null) return empty;
    final text = value!.trim();
    if (text.length < 2) return '$label must be at least 2 characters.';
    if (text.length > 60) return '$label is too long.';
    if (!_name.hasMatch(text)) return '$label contains invalid characters.';
    return null;
  }

  static String? middleName(String? value) {
    if (value == null || value.trim().isEmpty) return null;
    final text = value.trim();
    if (text.length > 60) return 'Middle name is too long.';
    if (!_name.hasMatch(text)) return 'Middle name contains invalid characters.';
    return null;
  }

  static String? email(String? value, {bool requireGmail = false}) {
    final empty = required(value, 'Email');
    if (empty != null) return empty;
    final text = value!.trim().toLowerCase();
    if (text.length > 254 || !_email.hasMatch(text)) {
      return 'Enter a valid email address.';
    }
    if (requireGmail && !text.endsWith('@gmail.com')) {
      return 'Use a Gmail address (e.g. name@gmail.com).';
    }
    return null;
  }

  static String? phone(String? value) {
    final empty = required(value, 'Contact number');
    if (empty != null) return empty;
    final compact = value!.replaceAll(RegExp(r'[\s-]'), '');
    if (!_phonePh.hasMatch(compact)) {
      return 'Use a valid PH mobile number, e.g. 09171234567.';
    }
    return null;
  }

  static String? postalCode(String? value) {
    final empty = required(value, 'Postal code');
    if (empty != null) return empty;
    if (!_postalPh.hasMatch(value!.trim())) {
      return 'Enter a 4-digit Philippine postal code.';
    }
    return null;
  }

  static String? password(String? value, {int minimumLength = 8}) {
    final empty = required(value, 'Password');
    if (empty != null) return empty;
    if (value!.length < minimumLength) {
      return 'Password must be at least $minimumLength characters.';
    }
    if (!RegExp(r'[A-Za-z]').hasMatch(value) ||
        !RegExp(r'\d').hasMatch(value)) {
      return 'Use at least one letter and one number.';
    }
    return null;
  }

  static String? confirmPassword(String? value, String password) {
    if (value == null || value.isEmpty) return 'Confirm your password.';
    if (value != password) return 'Passwords do not match.';
    return null;
  }

  static String? birthday(DateTime? value) {
    if (value == null) return 'Birthday is required.';
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    if (value.isAfter(today)) return 'Birthday cannot be in the future.';
    final age = _yearsBetween(value, today);
    if (age < 13) return 'You must be at least 13 years old.';
    if (age > 120) return 'Enter a valid birthday.';
    return null;
  }

  static int _yearsBetween(DateTime from, DateTime to) {
    var years = to.year - from.year;
    if (to.month < from.month ||
        (to.month == from.month && to.day < from.day)) {
      years -= 1;
    }
    return years;
  }

  static String? reviewText(String? value) {
    if (value == null) return null;
    if (value.trim().length > 1000) {
      return 'Review must be 1,000 characters or fewer.';
    }
    return null;
  }

  /// Normalises a Philippine mobile number for storage and customer-service
  /// use while preserving what the customer typed when it is already valid.
  static String normalisePhone(String value) {
    final compact = value.replaceAll(RegExp(r'[\s-]'), '');
    if (compact.startsWith('+63')) return compact;
    if (compact.startsWith('09')) return compact;
    if (compact.startsWith('9') && compact.length == 10) return '0$compact';
    return compact;
  }
}
