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

## Tree photo validation

The app defaults to the Cloudflare Worker; deploying Firebase Functions alone does
not update that backend. Both backends implement `validateTreePhotos`.
See [the Worker API and strict-gate rollout](../cloudflare-worker/README.md).

For Firebase Functions, configure `PLANTNET_API_KEY` and `CLOUDINARY_CLOUD_NAME`,
deploy `validateTreePhotos`, and set `VALIDATE_TREE_PHOTOS_URL` to its HTTPS
endpoint when building Flutter. Authentication is mandatory. Every submitted tree
photo is individually recognized at >= 50% confidence before issuing a UID-bound,
24-hour Firestore receipt. Validation errors block submission; they do not fall
back to manual species selection. The only exception is the GPS-matched on-site
fallback for leafless/dead trees, which flags the permit for inspection (see the
Worker README). Deploy the updated Firestore rules after the
new backend and app are available.

Run `node --test tree_photo_validation.test.mjs` for shared policy tests.

## Optional: bark/trunk classifier fusion

Pl@ntNet's bark/trunk recognition is markedly weaker than its leaf
recognition. You can optionally deploy a small, self-hosted classifier
trained only on this app's known permit species (see
[`../bark_classifier_service/README.md`](../bark_classifier_service/README.md))
and have both `identifySpecies` and `validateTreePhotos` fuse its result
with Pl@ntNet's — agreement raises Pl@ntNet's confidence, and a confident
bark classification can rescue a photo Pl@ntNet failed to recognize at all.
It never overrides a confident, disagreeing Pl@ntNet result.

Configure:
- `BARK_CLASSIFIER_URL` — the deployed classifier's base URL (e.g. a Cloud
  Run service). Leaving this unset disables fusion entirely with zero
  behavior change.
- `BARK_CLASSIFIER_TIMEOUT_MS` (optional, default `8000`) — request timeout;
  a timeout or any other failure is treated as "no opinion" and never
  blocks or fails photo analysis.

Run `node --test bark_species_classifier.test.mjs` for fusion-logic tests.
The same fusion module is also used by the Cloudflare Worker backend (see
`cloudflare-worker/src/index.js`) — update `BARK_CLASSIFIER_URL` there too
if that is your deployed backend (see `../cloudflare-worker/README.md`).

