# TODO: Map Location Picker UX fixes (Reports)

- [ ] Update `lib/screens/report/report_location_picker.dart`
  - [ ] Ensure returned `landmark` field is provided (landmark = _sitioController text, or keep null if empty)
  - [ ] Add address fallback so `address` is never null/empty on confirm (fallback = formatted lat,lng)
  - [ ] Add instruction UI near bottom panel for:
    - [ ] when `_selected == null` (tap map)
    - [ ] when barangay was selected but map not tapped yet
  - [ ] Implement confirmation modal after tapping “Confirm” showing:
    - lat, lng, address, barangay, sitio/landmark
    - buttons: Back / Yes (use)

- [ ] Update `lib/screens/report/report_screen.dart` (only if needed)
  - [ ] Verify handling of `result['landmark']` now matches picker return
  - [ ] Ensure location text concatenation logic doesn’t overwrite address unexpectedly

- [ ] Static check: ensure code compiles (no flutter commands yet)

