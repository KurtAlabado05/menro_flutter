# TODO - Profile Screen Cloudinary Upload (File Picker)

- [ ] Replace Firebase Storage avatar upload in `lib/screens/profile/profile_screen.dart` with Cloudinary upload using existing `CloudinaryImageService`.
- [ ] Use `file_picker` to select an image file (not `image_picker`).
- [ ] Update Firestore `users/{uid}.avatarUrl` to Cloudinary `secure_url`.
- [ ] Ensure UI loading state and error snackbar work.
- [ ] Run `flutter analyze` and quick manual test on Profile screen.

