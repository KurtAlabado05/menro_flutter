# Cloudflare Worker replacement for Firebase Functions

This folder contains a Cloudflare Worker equivalent of `functions/index.js`.

## Endpoints
- `POST /uploadEvidence`
  - multipart form-data field: `file`
  - returns: `{ "secure_url": string, "public_id": string }`
- `POST /identifySpecies`
  - JSON body:
    - `imageUrls: string[]` (1..5)
    - `organs?: string[]`
  - returns: `{ suggestions, bestMatch, evidencePhotoUrls, identifiedAt, bestMatchName }`

## Environment variables
Set the following Worker secrets/vars:
- `PLANTNET_API_KEY`
- `PLANTNET_PROJECT` (optional, default `all`)
- `CLOUDINARY_CLOUD_NAME`
- `CLOUDINARY_API_KEY`
- `CLOUDINARY_API_SECRET`
- `CLOUDINARY_FOLDER` (optional, default `reports/evidence`)

## Auth
The Firebase version validates an ID token (Firebase Auth). For Cloudflare Worker, you must decide how to verify auth:
- easiest: remove auth check (NOT recommended for production)
- recommended: verify a Firebase ID token using the Firebase Admin SDK (would require bundling/admin creds)

This template keeps behavior compatible but leaves auth as a stub.

## Setup
1. Install dependencies (if you use `wrangler`):
   - `npm i -D wrangler`
2. Configure `wrangler.toml`
3. Deploy: `npx wrangler deploy`


