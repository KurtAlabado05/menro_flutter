import 'package:cloud_firestore/cloud_firestore.dart';
import '../core/constants/user_roles.dart';
import 'account_type.dart';

class UserModel {
  final String id;
  final String name;
  final String email;
  final String role;
  final AccountType? accountType;

  final String? avatarUrl;
  final String? contactPerson;
  final String? businessPermitNumber;
  final bool? isVerified;
  final String? phoneNumber;
  final String? completeAddress;
  final String? organizationId;
  final String? organizationStatus;
  final String? organizationMembershipStatus;
  final String? organizationRequestStatus;
  final String? organizationRequestName;
  final String? activeOrganizationName;
  final List<Map<String, dynamic>> organizationMemberships;

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
    AccountType? accountType,
    this.avatarUrl,
    this.contactPerson,
    this.businessPermitNumber,
    this.isVerified,
    this.phoneNumber,
    this.completeAddress,
    this.organizationId,
    this.organizationStatus,
    this.organizationMembershipStatus,
    this.organizationRequestStatus,
    this.organizationRequestName,
    this.activeOrganizationName,
    this.organizationMemberships = const [],
    this.citizenNationalIdUrl,
    this.businessPermitUrl,
    this.isProfilePublic = true,
    this.allowNotifications = true,
    this.impactScore = 0,
    this.badges = const [],
    required this.joinedAt,
  }) : accountType = accountType ?? AccountType.fromStoredValue(role);
  bool get isStaff => UserRoles.isStaff(role);

  bool get isInspectionOfficer => role == UserRoles.inspectionOfficer;
  bool get hasApprovedOrganizationAccess {
    if (organizationId != null) {
      for (final membership in organizationMemberships) {
        if (membership['organizationId'] == organizationId) {
          return membership['organizationStatus'] == 'verified' &&
              membership['status'] == 'approved';
        }
      }
      return organizationStatus == 'verified' &&
          organizationMembershipStatus == 'approved';
    }

    return (organizationStatus == 'verified' &&
            organizationMembershipStatus == 'approved') ||
        (organizationMemberships.length == 1 &&
            organizationMemberships.single['organizationStatus'] ==
                'verified' &&
            organizationMemberships.single['status'] == 'approved');
  }

  String get contextualName {
    if (hasApprovedOrganizationAccess &&
        activeOrganizationName != null &&
        activeOrganizationName!.trim().isNotEmpty) {
      return activeOrganizationName!.trim();
    }
    if (accountType == AccountType.organization &&
        !hasApprovedOrganizationAccess &&
        contactPerson != null &&
        contactPerson!.trim().isNotEmpty) {
      return contactPerson!.trim();
    }
    return name;
  }

  factory UserModel.fromFirestore(Map<String, dynamic> json, String docId) {
    final role = (json['role'] ?? json['accountType'] ?? 'citizen').toString();
    final accountType = AccountType.fromStoredValue(
      json['accountType'] ?? role,
    );
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

    String parsedName = '';
    final nameDetails = json['nameDetails'];
    if (nameDetails is Map) {
      final organizationName =
          (nameDetails['organizationName'] ?? json['organizationName'])
              ?.toString()
              .trim() ??
          '';
      if (organizationName.isNotEmpty) {
        parsedName = organizationName;
      } else {
        parsedName =
            [
                  nameDetails['firstName'],
                  nameDetails['middleName'],
                  nameDetails['lastName'],
                ]
                .where(
                  (part) => part != null && part.toString().trim().isNotEmpty,
                )
                .map((part) => part.toString().trim())
                .join(' ');
      }
    }
    if (parsedName.isEmpty) {
      for (final value in [
        json['organizationName'],
        json['fullName'],
        json['name'],
      ]) {
        final candidate = value?.toString().replaceAll('"', '').trim() ?? '';
        if (candidate.isNotEmpty) {
          parsedName = candidate;
          break;
        }
      }
    }
    if (parsedName.isEmpty) parsedName = 'User';

    return UserModel(
      id: docId,
      name: parsedName,
      email: json['email'] ?? '',
      role: role,
      accountType: accountType,
      avatarUrl: json['avatarUrl'],
      contactPerson: contactPerson,
      businessPermitNumber: businessPermitNumber,
      isVerified: isVerified,
      phoneNumber: json['phoneNumber'],
      completeAddress: completeAddress,
      organizationId: json['organizationId'] as String?,
      organizationStatus: json['organizationStatus'] as String?,
      organizationMembershipStatus:
          json['organizationMembershipStatus'] as String?,
      organizationRequestStatus: json['organizationRequestStatus'] as String?,
      organizationRequestName: json['organizationRequestName'] as String?,
      activeOrganizationName: json['activeOrganizationName'] as String?,
      organizationMemberships: _parseOrganizationMemberships(
        json['organizationMemberships'],
      ),
      citizenNationalIdUrl: json['citizenNationalIdUrl'] as String?,
      businessPermitUrl:
          json['organizationPermitUrl'] as String? ??
          json['businessPermitUrl'] as String?,
      isProfilePublic: json['isProfilePublic'] is bool
          ? json['isProfilePublic'] as bool
          : true,
      allowNotifications: json['allowNotifications'] is bool
          ? json['allowNotifications'] as bool
          : true,
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
      role: json['role'] ?? json['accountType'] ?? 'citizen',
      accountType: AccountType.fromStoredValue(
        json['accountType'] ?? json['role'],
      ),
      avatarUrl: json['avatarUrl'],
      contactPerson: json['contactPerson'],
      phoneNumber: json['phoneNumber'],
      completeAddress: json['completeAddress'],
      organizationId: json['organizationId'],
      organizationStatus: json['organizationStatus'],
      organizationMembershipStatus: json['organizationMembershipStatus'],
      organizationRequestStatus: json['organizationRequestStatus'],
      organizationRequestName: json['organizationRequestName'],
      activeOrganizationName: json['activeOrganizationName'],
      organizationMemberships: _parseOrganizationMemberships(
        json['organizationMemberships'],
      ),
      citizenNationalIdUrl: json['citizenNationalIdUrl'],
      businessPermitUrl:
          json['organizationPermitUrl'] ?? json['businessPermitUrl'],
      isProfilePublic: json['isProfilePublic'] is bool
          ? json['isProfilePublic']
          : true,
      allowNotifications: json['allowNotifications'] is bool
          ? json['allowNotifications']
          : true,
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
    if (accountType != null) 'accountType': accountType!.name,
    'avatarUrl': avatarUrl,
    'contactPerson': contactPerson,
    'phoneNumber': phoneNumber,
    'completeAddress': completeAddress,
    'organizationId': organizationId,
    'organizationStatus': organizationStatus,
    'organizationMembershipStatus': organizationMembershipStatus,
    'organizationRequestStatus': organizationRequestStatus,
    'organizationRequestName': organizationRequestName,
    'activeOrganizationName': activeOrganizationName,
    'organizationMemberships': organizationMemberships,
    'citizenNationalIdUrl': citizenNationalIdUrl,
    'businessPermitUrl': businessPermitUrl,
    'organizationPermitUrl': businessPermitUrl,
    'isProfilePublic': isProfilePublic,
    'allowNotifications': allowNotifications,
    'impactScore': impactScore,
    'badges': badges,
    'joinedAt': joinedAt.toIso8601String(),
  };

  Map<String, dynamic> toFirestore() => {
    'name': name,
    'email': email,
    'role': role,
    if (accountType != null) 'accountType': accountType!.name,
    'avatarUrl': avatarUrl,
    'contactPerson': contactPerson,
    'phoneNumber': phoneNumber,
    'completeAddress': completeAddress,
    'organizationId': organizationId,
    'organizationStatus': organizationStatus,
    'organizationMembershipStatus': organizationMembershipStatus,
    'organizationRequestStatus': organizationRequestStatus,
    'organizationRequestName': organizationRequestName,
    'activeOrganizationName': activeOrganizationName,
    'organizationMemberships': organizationMemberships,
    'citizenNationalIdUrl': citizenNationalIdUrl,
    'businessPermitUrl': businessPermitUrl,
    'organizationPermitUrl': businessPermitUrl,
    'isProfilePublic': isProfilePublic,
    'allowNotifications': allowNotifications,
    'impactScore': impactScore,
    'badges': badges,
    'joinedAt': FieldValue.serverTimestamp(),
  };

  static List<Map<String, dynamic>> _parseOrganizationMemberships(
    Object? value,
  ) {
    if (value is! List) return const [];
    return value
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
  }
}
