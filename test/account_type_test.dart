import 'package:cenro_application/models/account_type.dart';
import 'package:cenro_application/models/user_model.dart';
import 'package:cenro_application/screens/auth/register_screen.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';

void main() {
  testWidgets('switching account types preserves entered account details', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const MaterialApp(home: RegisterScreen()));

    await tester.enterText(find.byType(TextFormField).first, 'Avery');
    await tester.tap(find.text('Organization'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextFormField).first, 'Green Valley');
    await tester.tap(find.text('Citizen'));
    await tester.pumpAndSettle();

    expect(
      tester
          .widget<TextFormField>(find.byType(TextFormField).first)
          .controller!
          .text,
      'Avery',
    );

    await tester.tap(find.text('Organization'));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<TextFormField>(find.byType(TextFormField).first)
          .controller!
          .text,
      'Green Valley',
    );
    expect(find.text('Step 1 of 2'), findsOneWidget);
  });

  test('citizen registration data resolves account type and full name', () {
    final user = UserModel.fromFirestore({
      'role': 'citizen',
      'accountType': 'citizen',
      'nameDetails': {
        'firstName': 'Alex',
        'middleName': 'Morgan',
        'lastName': 'Rivera',
      },
      'citizenNationalIdUrl': 'https://example.test/id.png',
    }, 'citizen-uid');

    expect(user.accountType, AccountType.citizen);
    expect(user.name, 'Alex Morgan Rivera');
    expect(user.citizenNationalIdUrl, 'https://example.test/id.png');
  });

  test('organization registration data resolves name and permit URL', () {
    final user = UserModel.fromFirestore({
      'role': 'organization',
      'nameDetails': {'organizationName': 'Green Valley Cooperative'},
      'organizationDetails': {
        'contactPerson': 'Jordan Lee',
        'businessPermitNumber': 'BP-123',
      },
      'organizationPermitUrl': 'https://example.test/permit.pdf',
    }, 'organization-uid');

    expect(user.accountType, AccountType.organization);
    expect(user.name, 'Green Valley Cooperative');
    expect(user.contactPerson, 'Jordan Lee');
    expect(user.businessPermitNumber, 'BP-123');
    expect(user.businessPermitUrl, 'https://example.test/permit.pdf');
  });

  test('legacy individual role is interpreted as citizen', () {
    final user = UserModel.fromFirestore({'role': 'individual'}, 'legacy-uid');

    expect(user.accountType, AccountType.citizen);
  });

  test('staff roles are not classified as public account types', () {
    final user = UserModel.fromFirestore({'role': 'admin'}, 'admin-uid');

    expect(user.role, 'admin');
    expect(user.accountType, isNull);
  });

  test('explicit account type stays separate from staff role', () {
    final user = UserModel.fromFirestore({
      'role': 'staff',
      'accountType': 'organization',
    }, 'staff-uid');

    expect(user.role, 'staff');
    expect(user.accountType, AccountType.organization);
  });

  test('unknown account types are not treated as citizen or organization', () {
    expect(AccountType.fromStoredValue('admin'), isNull);
    expect(AccountType.fromStoredValue('unknown'), isNull);
    expect(AccountType.fromStoredValue(null), isNull);
  });

  test('missing profile fields use safe defaults', () {
    final user = UserModel.fromFirestore({}, 'empty-uid');

    expect(user.role, 'citizen');
    expect(user.accountType, AccountType.citizen);
    expect(user.name, 'User');
    expect(user.email, isEmpty);
  });

  test('saved notification and profile visibility preferences round-trip', () {
    final user = UserModel.fromFirestore({
      'role': 'citizen',
      'allowNotifications': false,
      'isProfilePublic': false,
    }, 'citizen-uid');

    expect(user.allowNotifications, isFalse);
    expect(user.isProfilePublic, isFalse);
    expect(user.toJson()['allowNotifications'], isFalse);
    expect(user.toJson()['isProfilePublic'], isFalse);
    expect(user.toFirestore()['allowNotifications'], isFalse);
    expect(user.toFirestore()['isProfilePublic'], isFalse);
  });

  test('malformed name details fall back to the stored display name', () {
    final user = UserModel.fromFirestore({
      'role': 'citizen',
      'nameDetails': 'invalid',
      'name': 'Taylor Citizen',
    }, 'citizen-uid');

    expect(user.accountType, AccountType.citizen);
    expect(user.name, 'Taylor Citizen');
  });

  test('legacy organization permit URL is still loaded', () {
    final user = UserModel.fromFirestore({
      'role': 'organization',
      'name': 'Legacy Organization',
      'businessPermitUrl': 'https://example.test/legacy-permit.pdf',
    }, 'legacy-org-uid');

    expect(user.name, 'Legacy Organization');
    expect(user.businessPermitUrl, 'https://example.test/legacy-permit.pdf');
  });

  test('Firestore serialization preserves account type and permit URL', () {
    final user = UserModel(
      id: 'organization-uid',
      name: 'Green Valley Cooperative',
      email: 'contact@example.test',
      role: 'organization',
      accountType: AccountType.organization,
      businessPermitUrl: 'https://example.test/permit.pdf',
      joinedAt: DateTime.utc(2026),
    );

    final data = user.toFirestore();

    expect(data['role'], 'organization');
    expect(data['accountType'], 'organization');
    expect(data['organizationPermitUrl'], 'https://example.test/permit.pdf');
  });

  test('pending organization review does not grant organization access', () {
    final user = UserModel.fromFirestore({
      'role': 'organization',
      'accountType': 'organization',
      'organizationStatus': 'pending',
      'organizationMembershipStatus': 'pending',
      'activeOrganizationName': 'Green Valley Cooperative',
    }, 'pending-org-uid');

    expect(user.hasApprovedOrganizationAccess, isFalse);
    expect(user.contextualName, 'User');
  });

  test('approved organization membership enables organization context', () {
    final user = UserModel.fromFirestore({
      'role': 'citizen',
      'accountType': 'citizen',
      'organizationId': 'org-1',
      'organizationMemberships': [
        {
          'organizationId': 'org-1',
          'organizationName': 'Green Valley Cooperative',
          'organizationStatus': 'verified',
          'status': 'approved',
        },
      ],
      'activeOrganizationName': 'Green Valley Cooperative',
    }, 'representative-uid');

    expect(user.hasApprovedOrganizationAccess, isTrue);
    expect(user.contextualName, 'Green Valley Cooperative');
  });
}
