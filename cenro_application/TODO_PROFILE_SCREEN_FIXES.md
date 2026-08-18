# TODO - Profile screen fixes

## Steps
- [ ] Update `lib/models/user_model.dart` to include missing fields referenced by `profile_screen.dart` (notably `isVerified` and `businessPermitNumber`) and align Firestore parsing with the schema written by `register_screen.dart` (nested fields like `organizationDetails` and top-level `isVerified`).
- [ ] Update `lib/screens/profile/profile_screen.dart` to correctly use the updated model fields with safe null-handling.
- [ ] Search repo for remaining references to missing fields to ensure no more compile errors.
- [ ] Run `flutter analyze` to confirm build/compile success.

