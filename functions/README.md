# Firebase Cloud Functions - Cloudinary Upload

This folder contains starter files to upload evidence images to Cloudinary and return `secure_url` to the Flutter app.

## 1) Prerequisites
- Create a Firebase project and enable **Cloud Functions**
- Install Firebase CLI: `npm i -g firebase-tools`

## 2) Install dependencies
From this project root:
- `cd functions`
- `npm install`

## 3) Configure environment variables
Set in your Firebase Functions config / environment:
- `CLOUDINARY_CLOUD_NAME`
- `CLOUDINARY_API_KEY`
- `CLOUDINARY_API_SECRET`
- `CLOUDINARY_FOLDER` (optional, default: reports/evidence)

## 4) Deploy
- `firebase deploy --only functions`

## 5) Endpoint contract (what Flutter expects)
Flutter will call your function with multipart form-data:
- field name: `file`

Response:
- `{ "secure_url": "...", "public_id": "..." }`

## IMPORTANT
The `index.js` file in this starter template still needs the final Cloudinary upload implementation.
After you confirm endpoint URL + how you will verify Firebase auth (optional), I will complete the backend code and then wire Flutter `_uploadImages()` to call it.

