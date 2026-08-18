# TODO: Populate Map Screen (Firestore replacing mock)

- [ ] Update `lib/models/project_model.dart` to include `latitude`/`longitude` (root-level numbers) and parse them from Firestore.
- [ ] Update `lib/screens/map/map_screen.dart` to load pins from Firestore using `ReportProvider` and `ProjectProvider`.
- [ ] Replace `_pins` mock data with Firestore-driven list, only pinning items that have valid lat/lng.
- [ ] Ensure filter chips (All/Reports/Projects) work with the loaded pins.
- [ ] Ensure tapping a pin navigates to `ReportDetailsScreen` / `ProjectDetailsScreen` with correct ids.
- [ ] Run `flutter analyze` and `flutter run` to verify markers render and no null/latlng issues.

