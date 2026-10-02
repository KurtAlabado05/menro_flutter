/// Staff/citizen role identifiers stored on `users/{uid}.role` in Firestore.
///
/// Mirrors `USER_ROLES` in the menro_admin web app so role strings stay
/// consistent across both clients.
class UserRoles {
  UserRoles._();

  static const String admin = 'admin';
  static const String denrOfficer = 'denr_officer';
  static const String inspectionOfficer = 'inspection_officer';
  static const String receivingClerk = 'receiving_clerk';
  static const String organization = 'organization';
  static const String individual = 'individual';
  static const String citizen = 'citizen';

  /// Roles that get the staff shell instead of the citizen app shell.
  static const Set<String> staffRoles = {
    admin,
    denrOfficer,
    inspectionOfficer,
    receivingClerk,
  };

  static bool isStaff(String? role) =>
      role != null && staffRoles.contains(role);
}
