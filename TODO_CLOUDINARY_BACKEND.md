# Cloudinary + Firebase (Option A) – Implementation Checklist

## Backend (Firebase Cloud Functions)
- [ ] Create Firebase Functions project (node)
- [ ] Implement HTTPS endpoint: `POST /uploadEvidence`
- [ ] Parse multipart upload (image file)
- [ ] Upload image to Cloudinary with server-side credentials/preset
- [ ] Return JSON: `{ secure_url: string, public_id?: string }`
- [ ] (Recommended) Verify Firebase ID token from Authorization header
- [ ] Deploy functions

## Flutter changes
- [ ] Replace `_uploadImages()` in `lib/screens/report/report_screen.dart`
- [ ] Upload each selected image to backend endpoint
- [ ] Collect returned `secure_url`s
- [ ] Save URLs into Firestore via existing `ReportModel`

## Testing
- [ ] Manual test: attach photo evidence -> submit report -> verify stored URLs render images correctly
- [ ] Add error handling/logging for upload failures/timeouts

