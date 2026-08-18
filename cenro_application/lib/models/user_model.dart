import 'package:cloud_firestore/cloud_firestore.dart';

class UserModel {
  final String id;
  final String name;
  final String email;
  final String role;

  final String? avatarUrl;
  final String? contactPerson;
  final String? businessPermitNumber;
  final bool? isVerified;
  final String? phoneNumber;
  final String? completeAddress;

  // --- NEW VERIFICATION FIELDS ---
  final String? citizenNationalIdUrl;
  final String? businessPermitUrl;

  final int impactScore;
  final List<String> badges;
  final DateTime joinedAt;

  final bool isProfilePublic;
  final bool allowNotifications;

  UserModel({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
    this.avatarUrl,
    this.contactPerson,
    this.businessPermitNumber,
    this.isVerified,
    this.phoneNumber,
    this.completeAddress,
    this.citizenNationalIdUrl,
    this.businessPermitUrl,
    this.isProfilePublic = true,
    this.allowNotifications = true,
    this.impactScore = 0,
    this.badges = const [],
    required this.joinedAt,
  });

  factory UserModel.fromFirestore(Map<String, dynamic> json, String docId) {
    final role = (json['role'] ?? 'individual').toString();
    final orgDetails = json['organizationDetails'];

    final contactPerson =
        json['contactPerson'] as String? ??
        (orgDetails is Map<String, dynamic>
            ? orgDetails['contactPerson'] as String?
            : null);

    final businessPermitNumber =
        json['businessPermitNumber'] as String? ??
        (orgDetails is Map<String, dynamic>
            ? orgDetails['businessPermitNumber'] as String?
            : null);

    final isVerifiedValue = json['isVerified'];
    final bool? isVerified = isVerifiedValue is bool
        ? isVerifiedValue
        : isVerifiedValue != null
        ? bool.tryParse(isVerifiedValue.toString())
        : null;

    final addressDetails = json['addressDetails'];
    String? completeAddress = json['completeAddress'] as String?;

    if (completeAddress == null && addressDetails is Map<String, dynamic>) {
      final parts =
          [
                addressDetails['houseNumber'],
                addressDetails['sitioOrSubdivision'],
                addressDetails['barangay'],
                addressDetails['city'],
                addressDetails['province'],
              ]
              .where(
                (part) => part != null && part.toString().trim().isNotEmpty,
              )
              .map((part) => part.toString().trim())
              .toList();
      completeAddress = parts.isNotEmpty ? parts.join(', ') : null;
    }

    String parsedName = 'User';
    if (json['nameDetails'] is Map<String, dynamic>) {
      final first = (json['nameDetails']['firstName'] as String?)?.trim() ?? '';
      final last = (json['nameDetails']['lastName'] as String?)?.trim() ?? '';
      final full = '$first $last'.trim();
      if (full.isNotEmpty) parsedName = full;
    } else if (json['fullName'] != null &&
        json['fullName'].toString().trim().isNotEmpty) {
      parsedName = json['fullName'].toString().replaceAll('"', '').trim();
    } else if (json['name'] != null &&
        json['name'].toString().trim().isNotEmpty) {
      parsedName = json['name'].toString().trim();
    }

    return UserModel(
      id: docId,
      name: parsedName,
      email: json['email'] ?? '',
      role: role,
      avatarUrl: json['avatarUrl'],
      contactPerson: contactPerson,
      businessPermitNumber: businessPermitNumber,
      isVerified: isVerified,
      phoneNumber: json['phoneNumber'],
      completeAddress: completeAddress,
      citizenNationalIdUrl: json['citizenNationalIdUrl'] as String?,
      businessPermitUrl: json['businessPermitUrl'] as String?,
      impactScore: json['impactScore'] ?? 0,
      badges: List<String>.from(json['badges'] ?? []),
      joinedAt: json['joinedAt'] is Timestamp
          ? (json['joinedAt'] as Timestamp).toDate()
          : json['joinedAt'] != null
          ? DateTime.tryParse(json['joinedAt'].toString()) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'] ?? '',
      name: json['name'] ?? 'User',
      email: json['email'] ?? '',
      role: json['role'] ?? 'individual',
      avatarUrl: json['avatarUrl'],
      contactPerson: json['contactPerson'],
      phoneNumber: json['phoneNumber'],
      completeAddress: json['completeAddress'],
      citizenNationalIdUrl: json['citizenNationalIdUrl'],
      businessPermitUrl: json['businessPermitUrl'],
      impactScore: json['impactScore'] ?? 0,
      badges: List<String>.from(json['badges'] ?? []),
      joinedAt: json['joinedAt'] != null
          ? DateTime.tryParse(json['joinedAt'].toString()) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'email': email,
    'role': role,
    'avatarUrl': avatarUrl,
    'contactPerson': contactPerson,
    'phoneNumber': phoneNumber,
    'completeAddress': completeAddress,
    'citizenNationalIdUrl': citizenNationalIdUrl,
    'businessPermitUrl': businessPermitUrl,
    'impactScore': impactScore,
    'badges': badges,
    'joinedAt': joinedAt.toIso8601String(),
  };

  Map<String, dynamic> toFirestore() => {
    'name': name,
    'email': email,
    'role': role,
    'avatarUrl': avatarUrl,
    'contactPerson': contactPerson,
    'phoneNumber': phoneNumber,
    'completeAddress': completeAddress,
    'citizenNationalIdUrl': citizenNationalIdUrl,
    'businessPermitUrl': businessPermitUrl,
    'impactScore': impactScore,
    'badges': badges,
    'joinedAt': FieldValue.serverTimestamp(),
  };
}
