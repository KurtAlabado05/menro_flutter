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


