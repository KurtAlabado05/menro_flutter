# Cloudflare Worker APIs

This Worker hosts the existing evidence/species endpoints and the organization review API used by `menro_admin`. Organization review continues to use Firebase Auth and Firestore; it does not require deploying Firebase Cloud Functions.

## Endpoints
- `POST /uploadEvidence`
  - multipart form-data field: `file`
  - returns: `{ "secure_url": string, "public_id": string }`
- `POST /identifySpecies`
  - JSON body:
    - `imageUrls: string[]` (1..5)
    - `organs?: string[]`
  - returns: `{ suggestions, bestMatch, evidencePhotoUrls, identifiedAt, bestMatchName }`
- `POST /validateTreePhotos`
  - requires a Firebase bearer ID token
  - JSON body: `{ imageUrls: string[] }`; nonempty, request body limited to 32 KB
  - accepts only HTTPS, versioned image uploads in `CLOUDINARY_CLOUD_NAME`
  - analyzes **every image separately** with Pl@ntNet (`auto` organ), requiring a
    scientific-name match and confidence >= 0.5; one good photo cannot mask a bad one
  - returns `{ validationId, evidencePhotoUrls, expiresAt }` only after every photo
    succeeds and a server-only `treePhotoValidations` receipt is written to Firestore
  - receipts bind the authenticated UID and exact ordered URL list, expire after
    24 hours, and cannot be created or edited by clients
  - typed errors: `{ code, message, photoIndex? }`. `no_match`/`low_confidence` use
    422, rate limiting uses 429, and outages fail closed with 503. Raw upstream
    payloads are not sent to the UI.
  - optional on-site fallback for leafless/dead trees: body may add
    `onSiteCaptures: [{ url, latitude, longitude, accuracyMeters, capturedAt }]`
    and `treeLocation: { latitude, longitude }`. A photo with a matching capture
    that gets `no_match`/`low_confidence` is accepted as unverified only when GPS
    accuracy <= 50 m, the capture is < 24 h old (5 min clock skew allowed) and it
    is <= 100 m from the pinned tree; otherwise `onsite_gps_unreliable` or
    `onsite_too_far` (422). Outages and rate limits never fall back. The response
    adds `speciesVerification` (`verified` | `unverified_onsite`) and
    `unverifiedPhotoIndexes`; the receipt stores `speciesVerification`, plus
    `unverifiedPhotoUrls`, `treeLatitude` and `treeLongitude` when unverified.
- `POST /organization-admin/submit-application`
  - authenticated Firebase users can submit/resume an organization application
  - body: `{ legalName, permitIssuer, permitNumber, permitDocumentUrl, contactPerson, phoneNumber?, addressDetails: { city, province } }`
  - optionally accepts `action: "requestRepresentative"` for permit lookup requests
- `POST /organization-admin/update-permit`
  - authenticated pending primary representatives can replace the permit on their application
  - body: `{ organizationId, permitDocumentUrl }`
  - updates the private verification record used by reviewers and the user profile summary
- `POST /organization-admin/list`
  - returns pending organization applications, representative requests, and unmatched permit requests
- `POST /organization-admin/review`
  - body: `{ organizationId, decision: "verified" | "rejected", representativeUid? }`
- `POST /organization-admin/reject-lookup`
  - body: `{ requestId }`

All organization-admin routes require `Authorization: Bearer <Firebase ID token>`. The Worker verifies the token against this Firebase project, then requires both `users/{uid}.role == "admin"` and `organizationReviewers/{uid}.enabled == true`. Approval also requires a verified representative email and a valid configured Cloudinary permit. Firestore writes are server-side and guarded with document update-time preconditions.

The `submit-application` route requires any valid signed-in Firebase user, not an admin. It creates a pending organization, private permit record, primary-representative membership, HMAC permit registry entry, and user summary in one Firestore commit. If a Firebase Auth account exists from a failed earlier signup but has no Firestore profile, sign in and use Profile → Apply for an organization account to resume.

## Environment variables
Set these non-secret Worker variables in `wrangler.toml`:
- `FIREBASE_PROJECT_ID` (must match the service account project)
- `CLOUDINARY_CLOUD_NAME`
- `ADMIN_ORIGINS` (comma-separated exact origins, e.g. `http://localhost:3000,https://admin.example.gov`)
- `BARK_CLASSIFIER_URL` (optional — see
  [`../bark_classifier_service/README.md`](../bark_classifier_service/README.md)).
  Fuses a self-hosted bark/trunk species classifier with Pl@ntNet for both
  `identifySpecies` and `validateTreePhotos`. Leave unset to disable fusion
  with zero behavior change.
- `BARK_CLASSIFIER_TIMEOUT_MS` (optional, default `8000`)

Set Worker secrets (never commit these):
- `PLANTNET_API_KEY`
- `CLOUDINARY_API_KEY`
- `CLOUDINARY_API_SECRET`
- `FIREBASE_SERVICE_ACCOUNT_JSON` (JSON for a dedicated service account in `FIREBASE_PROJECT_ID`; grant only the Firestore and Firebase Auth permissions needed for organization review)
- `ORG_REGISTRY_HMAC_KEY` (must exactly match the key used to create any existing `organizationRegistry` or `legacyOrganizationRegistry` fingerprints)

## Setup and deploy

1. Create a dedicated Google Cloud service account in the Firebase project with the least privilege required to read/write the organization review documents and look up Firebase Auth users. Create a JSON key and keep it out of source control.
2. Configure `FIREBASE_PROJECT_ID`, `CLOUDINARY_CLOUD_NAME`, and `ADMIN_ORIGINS` in `wrangler.toml`. Replace the local-only origin with the exact deployed admin origin (or include both local and production origins).
3. Install dependencies with `npm install`.
4. From this directory, set secrets interactively:

   ```powershell
   npx wrangler secret put FIREBASE_SERVICE_ACCOUNT_JSON
  npx wrangler secret put ORG_REGISTRY_HMAC_KEY
   npx wrangler secret put CLOUDINARY_API_KEY
   npx wrangler secret put CLOUDINARY_API_SECRET
   npx wrangler secret put PLANTNET_API_KEY
   ```

   Paste each secret only into the Wrangler prompt. Do not paste credentials into chat, source files, or committed `.env` files.

  If no HMAC key or organization registry has ever been created, generate one locally and pipe it directly to Wrangler (do not display or commit it):

  ```powershell
  $bytes = New-Object byte[] 32
  [System.Security.Cryptography.RandomNumberGenerator]::Create().GetBytes($bytes)
  $env:ORG_REGISTRY_HMAC_KEY = [Convert]::ToBase64String($bytes)
  $env:ORG_REGISTRY_HMAC_KEY | .\node_modules\.bin\wrangler.cmd secret put ORG_REGISTRY_HMAC_KEY
  Remove-Item Env:ORG_REGISTRY_HMAC_KEY
  ```

  If a registry already exists, recover and use its original HMAC key instead; replacing it makes old permit fingerprints impossible to match. Pipe the existing value to Wrangler without echoing it.
5. Run checks and deploy:

   ```powershell
   npm test
   npx wrangler deploy
   ```

6. Set `REACT_APP_ORGANIZATION_ADMIN_API_URL` to the deployed Worker base URL when building `menro_admin`, if it differs from the default Worker URL.

Worker deployment is separate from Firebase Cloud Functions and does not enable or deploy any Firebase Functions. Firestore access still depends on the project’s IAM and deployed Firestore rules; do not weaken client rules to make this API work.

## Strict tree-permit photo gate and rollout

The Flutter application validates tree-photo attachments before adding them, then
revalidates the exact final list immediately before submission. Manual species
selection does not bypass this check. Unrecognized/uncertain photos and analysis
outages block submission; the current in-memory draft remains available for retry.
The species-identification sheet recommends a leaf close-up; leaf-only
identification is supported. Bark is optional, but if selected it must pass the
same per-photo confidence gate. Users may remove uncertain optional bark and
reanalyze the leaf alone; rejected bark is not retained as validated evidence.
Surroundings/context photos are not plant-gated because they may legitimately show
buildings or utility lines. Documents are still reviewed by staff.

The Firestore create rule for non-admin tree permits requires a matching unexpired
server receipt in `treePhotoValidationId`. Existing permit reads and staff workflow
updates are unchanged; admin-created records retain their existing trusted exemption.
Species recognition is a screening measure, **not** proof of tree growth habit,
photo ownership, location, document authenticity, or legal grounds to cut.
MENRO/DENR inspection remains necessary.

### Leafless or dead trees (on-site fallback)

Bark-only and leafless photos are often uncertain. When a tree photo fails with
`no_match`/`low_confidence`, the app offers **Take on-site photo**: a live in-app
camera capture (no gallery), tagged with a fresh GPS fix that must be within 50 m
accuracy and 100 m of the pinned tree. The server re-checks these limits. Such
photos are accepted as `unverified_onsite`; the permit must carry
`speciesVerification: "unverified_onsite"`, `inspectionRequired: true`, the
receipt's `unverifiedTreePhotoUrls` and the same `treeLatitude`/`treeLongitude`
(enforced by `hasMatchingSpeciesVerification` in `firestore.rules`). Inspection
officers see a "Species unverified" banner. Moving the pin discards the receipt.
Client GPS can be spoofed, so this fallback only narrows abuse (live capture,
location match, mandatory flag); staff must confirm the species on site.
Permits that omit these fields default to `verified` and still need a verified
receipt, so older clients keep working.
Images must be uploaded before the recognition API can read them. Rejected or
abandoned uploads are not attached to the permit, but unsigned Cloudinary clients
cannot delete them; storage cleanup still requires a server-side retention policy.

Deploy the Worker **first**, release the updated Flutter app, then deploy
`firestore.rules`. Old clients without receipts intentionally cannot create new
permits after the rules change. Before releasing the app, test recognition,
receipt creation and submission in a staging environment with real uploaded tree
photos. `VALIDATE_TREE_PHOTOS_URL` may override the validation endpoint; otherwise
it is derived from `IDENTIFY_SPECIES_URL`. The service-account secret needs access
to create `treePhotoValidations` documents as well as the existing organization
collections. Configure Firestore TTL on `expiresAt` for receipt cleanup if desired;
expiration is enforced by rules regardless of cleanup timing.

### Diagnosing HTTP 503

Worker logging is enabled in `wrangler.toml` under `[observability.logs]`.
Deploy the configuration before retrying; enabling log persistence alone in the
dashboard does not enable logging. Logs are collected for new requests, not
retroactively for earlier failures.

A successful OPTIONS preflight proves the route exists, not that recognition or
receipt creation works. Worker logs emit only
`{ event: "photo_validation_failed", stage, code, status, photoIndex? }` (no photo URLs,
tokens, upstream bodies or credentials). Low-confidence failures additionally log
`confidence` (0..1, or null for an invalid score) and `requiredConfidence` (0.5).
These scores measure model certainty, not photo sharpness or proof that an image
contains a tree. Reproduce one upload and check Worker
Observability logs:

- `authentication`: check the Firebase project configuration and current sign-in.
- `recognition`: check photo download, Pl@ntNet availability, key validity and quota.
  The Worker downloads photos with `redirect: 'manual'` and rejects redirects;
  `redirect: 'error'` throws a runtime `TypeError` under this compatibility date.
- `receipt`: check that `FIREBASE_SERVICE_ACCOUNT_JSON` is valid, matches
  `FIREBASE_PROJECT_ID`, and its service account can create Firestore documents.
  Receipt failures use `validation_storage_unavailable` with HTTP 503, including
  OAuth/IAM permission errors; they must not be mistaken for the user's expired
  session or a bad photo.

Secret names existing in Cloudflare do not prove their contents or IAM permissions
are correct. Never paste secret values or full upstream errors into chat. Flutter
logs HTTP status and the typed failure; redeploy the Worker and restart the updated
app to get the more specific diagnostics. A missing endpoint (404) is shown as a
backend setup issue rather than a phone connection problem.

Local tests: `npm test` here and
`node --test functions/tree_photo_validation.test.mjs` from the repository root.
`functions/tree_photo_rules.test.mjs` runs against a Firestore emulator via
`firebase emulators:exec --only firestore --project demo-tree-photo-validation
"node --test functions/tree_photo_rules.test.mjs"`. The emulator tests reject
missing, forged, expired, wrong-user and modified-photo receipts.
