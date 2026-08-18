# TODO - Phone Number & Complete Address Prefill

## Phase 1: User data model + Firestore
- [ ] Update `lib/models/user_model.dart` to add `phoneNumber` and `completeAddress`
- [ ] Update `lib/providers/auth_provider.dart` (load/save via `UserModel`)

## Phase 2: Register screen inputs (required)
- [ ] Update `lib/screens/auth/register_screen.dart` UI: add required Phone Number and Complete Address
- [ ] Store `phoneNumber` and `completeAddress` into Firestore `users/{uid}`

## Phase 3: Prefill screens
- [ ] Update `lib/screens/tree_cutting_application_screen.dart` to prefill applicant address + contact number from `auth.user`
- [ ] Update `lib/screens/report/report_screen.dart` to prefill reporter name/contact from `auth.user`

## Phase 4: Report address field end-to-end (only if required)
- [ ] Inspect `lib/models/report_model.dart` and `lib/providers/report_provider.dart` for existing reporter address support
- [ ] If supported: add UI field + save + show in report details
- [ ] If not supported: add `reporterAddress` to model/provider/UI end-to-end

## Phase 5: Verification
- [ ] Run `flutter analyze`
- [ ] Smoke test registration + both prefill screens

