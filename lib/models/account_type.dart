enum AccountType {
  citizen,
  organization;

  static AccountType? fromStoredValue(Object? value) {
    switch (value?.toString().toLowerCase()) {
      case 'organization':
        return AccountType.organization;
      case 'citizen':
      case 'individual':
        return AccountType.citizen;
      default:
        return null;
    }
  }

  String get label => switch (this) {
    AccountType.citizen => 'Citizen',
    AccountType.organization => 'Organization',
  };
}
