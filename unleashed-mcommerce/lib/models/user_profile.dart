import 'package:cloud_firestore/cloud_firestore.dart';

import '../core/formatters.dart';

class PostalAddress {
  const PostalAddress({
    required this.street,
    required this.barangay,
    required this.city,
    required this.province,
    required this.postalCode,
  });

  final String street;
  final String barangay;
  final String city;
  final String province;
  final String postalCode;

  String get singleLine {
    final parts = [
      street,
      barangay,
      city,
      province,
      postalCode,
    ].where((part) => part.trim().isNotEmpty).toList();
    return parts.join(', ');
  }

  Map<String, dynamic> toMap() => {
    'street': street,
    'barangay': barangay,
    'city': city,
    'province': province,
    'postalCode': postalCode,
  };

  factory PostalAddress.fromMap(Map<String, dynamic>? map) {
    map ??= <String, dynamic>{};
    return PostalAddress(
      street: (map['street'] ?? '').toString(),
      barangay: (map['barangay'] ?? '').toString(),
      city: (map['city'] ?? map['cityOrMunicipality'] ?? '').toString(),
      province: (map['province'] ?? '').toString(),
      postalCode: (map['postalCode'] ?? '').toString(),
    );
  }

  factory PostalAddress.fromString(String? value) {
    final parts = (value ?? '')
        .split(',')
        .map((part) => part.trim())
        .where((part) => part.isNotEmpty)
        .toList();
    return PostalAddress(
      street: parts.isNotEmpty ? parts[0] : '',
      barangay: parts.length > 1 ? parts[1] : '',
      city: parts.length > 2 ? parts[2] : '',
      province: parts.length > 3 ? parts[3] : '',
      postalCode: parts.length > 4 ? parts[4] : '',
    );
  }

  bool get isComplete =>
      street.trim().isNotEmpty &&
      barangay.trim().isNotEmpty &&
      city.trim().isNotEmpty &&
      province.trim().isNotEmpty &&
      postalCode.trim().isNotEmpty;
}

String? _asPhotoUrl(Object? value) {
  final raw = value?.toString().trim() ?? '';
  return raw.isEmpty ? null : raw;
}

class UserProfile {
  const UserProfile({
    required this.uid,
    required this.firstName,
    required this.lastName,
    required this.middleName,
    required this.contactNumber,
    required this.email,
    required this.birthday,
    required this.address,
    required this.role,
    required this.totalOrders,
    required this.totalSpent,
    this.photoUrl,
    this.createdAt,
    this.updatedAt,
    this.isActive = true,
  });

  final String uid;
  final String firstName;
  final String lastName;
  final String? middleName;
  final String contactNumber;
  final String email;
  final DateTime? birthday;
  final PostalAddress address;
  final String role;
  final int totalOrders;
  final int totalSpent;

  /// Customer profile photo. The current Spark deployment cannot create a
  /// Cloud Storage bucket, so the app stores a compressed JPEG as a `data:`
  /// URI in this field. A future Storage migration can reuse the same field
  /// with an HTTPS download URL.
  final String? photoUrl;
  final Timestamp? createdAt;
  final Timestamp? updatedAt;
  final bool isActive;

  String get fullName {
    final parts = [firstName, middleName, lastName]
        .where((part) => part != null && part.trim().isNotEmpty)
        .map((part) => part!.trim())
        .toList();
    return parts.isEmpty ? 'Customer' : parts.join(' ');
  }

  String get shortName =>
      firstName.trim().isEmpty ? fullName : firstName.trim();

  String get initials => initialsOf(fullName);

  /// Returns the same profile with a new photo. Kept explicit instead of a
  /// full `copyWith` so existing constructor callers stay unchanged.
  UserProfile withPhotoUrl(String? value) => UserProfile(
    uid: uid,
    firstName: firstName,
    lastName: lastName,
    middleName: middleName,
    contactNumber: contactNumber,
    email: email,
    birthday: birthday,
    address: address,
    role: role,
    totalOrders: totalOrders,
    totalSpent: totalSpent,
    photoUrl: value,
    createdAt: createdAt,
    updatedAt: updatedAt,
    isActive: isActive,
  );

  /// Legacy or partially created accounts can exist before the customer
  /// supplies their delivery details. Those accounts are sent through profile
  /// completion before they can browse as a fully configured customer.
  bool get needsCompletion =>
      firstName.trim().isEmpty ||
      lastName.trim().isEmpty ||
      contactNumber.trim().isEmpty ||
      birthday == null ||
      !address.isComplete;

  factory UserProfile.fromDoc(
    DocumentSnapshot<Map<String, dynamic>> doc, {
    String fallbackEmail = '',
  }) {
    final data = doc.data() ?? <String, dynamic>{};
    final rawAddress = data['address'];
    return UserProfile(
      uid: doc.id,
      firstName: (data['firstName'] ?? '').toString(),
      lastName: (data['lastName'] ?? '').toString(),
      middleName: data['middleName']?.toString(),
      contactNumber: (data['contactNumber'] ?? data['phone'] ?? '').toString(),
      email: (data['email'] ?? fallbackEmail).toString(),
      birthday: asDate(data['birthday']),
      address: PostalAddress.fromMap(
        rawAddress is Map ? Map<String, dynamic>.from(rawAddress) : null,
      ),
      role: (data['role'] ?? 'customer').toString(),
      totalOrders: (data['totalOrders'] as num?)?.toInt() ?? 0,
      totalSpent: (data['totalSpent'] as num?)?.toInt() ?? 0,
      photoUrl: _asPhotoUrl(data['photoUrl']),
      createdAt: data['createdAt'] is Timestamp
          ? data['createdAt'] as Timestamp
          : null,
      updatedAt: data['updatedAt'] is Timestamp
          ? data['updatedAt'] as Timestamp
          : null,
      isActive: data['isActive'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toMap({bool includeServerTimestamp = false}) => {
    'firstName': firstName,
    'lastName': lastName,
    'middleName': (middleName ?? '').trim().isEmpty ? null : middleName,
    'contactNumber': contactNumber,
    'phone': contactNumber,
    'displayName': fullName,
    'email': email,
    'birthday': birthday == null ? null : Timestamp.fromDate(birthday!),
    'address': address.toMap(),
    'photoUrl': photoUrl,
    'role': role,
    'updatedAt': includeServerTimestamp
        ? FieldValue.serverTimestamp()
        : Timestamp.now(),
  };
}
