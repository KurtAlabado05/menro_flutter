# Organization Registration and Review

## Data model

- `organizations/{organizationId}` stores the legal name and `verificationStatus` (`pending`, `verified`, or `rejected`).
- `organizations/{organizationId}/private/verification` stores the permit issuer, number, jurisdiction, and uploaded permit URL.
- `organizations/{organizationId}/members/{uid}` stores each representative and membership status (`pending`, `approved`, or `rejected`).
- `organizationRegistry/{fingerprint}` reserves new jurisdiction-scoped permit identities. Fingerprints are HMAC-SHA256 values; raw permit numbers are not used as document IDs.
- `legacyOrganizationRegistry/{fingerprint}` maps backfilled records whose original permit issuer was not stored. Those records remain pending review.
- `users/{uid}` keeps a summary of memberships so existing Flutter modules can select only approved organization access.

Organization names are normalized and checked for possible duplicates, but names are not unique identifiers. Name matches are review flags, not proof. Permit matches create pending representative membership requests; they do not grant access automatically.

Applicants may submit while their Firebase Auth email verification is pending, but reviewers cannot approve organization or representative access until the representative verifies that email.

## Provision the HMAC secret

Use one random value for both Firebase Secret Manager and the migration process. Keep it in a password manager; losing it prevents the registry from calculating matching fingerprints.

In PowerShell, generate a value and set the function secret:

```powershell
$bytes = New-Object byte[] 32
[System.Security.Cryptography.RandomNumberGenerator]::Create().GetBytes($bytes)
$env:ORG_REGISTRY_HMAC_KEY = [Convert]::ToBase64String($bytes)
firebase functions:secrets:set ORG_REGISTRY_HMAC_KEY
```

Paste the generated value into the Firebase CLI prompt. Do not commit it or put it in Flutter configuration.

## Backfill existing organization accounts

The migration script is read-only by default. Authenticate the local Admin SDK with Application Default Credentials, set the same `ORG_REGISTRY_HMAC_KEY` value in the current shell, and inspect the dry run:

```powershell
npm run migrate:organizations --prefix functions
```

The report masks permit numbers and groups old organization user records by permit plus jurisdiction. Multiple existing accounts for the same group are imported as pending representative memberships, and legacy organizations are marked for review. Investigate incomplete records and suspicious groups before applying:

```powershell
npm run migrate:organizations --prefix functions -- --apply
```

The script is designed to be idempotent. It does not approve old organizations or representatives.

## Reviewer access and admin review deployment

Create `organizationReviewers/{uid}` using a trusted Firebase Admin process or the Firebase Console with `{ "enabled": true }`. The matching `users/{uid}` document must have `role: "admin"`. Do not let clients create or update reviewer records.

The `menro_admin` approval queue uses the authenticated Cloudflare Worker API in `cloudflare-worker`; it does not require Firebase Cloud Functions or the Blaze plan for listing and reviewing existing organization records. Follow the Worker setup in `cloudflare-worker/README.md`, including the Firebase service-account secret and exact admin-origin allowlist, then deploy the Worker with Wrangler.

The Worker verifies Firebase ID tokens, requires both admin role and reviewer enablement, and performs conditional Firestore writes. Organization approval requires a valid permit and verified representative email.

The Worker also accepts organization application submissions and representative lookup requests. An existing Auth account without a Firestore user document can sign in and resume from Flutter Profile → **Apply for an organization account**. This applicant endpoint requires the Worker `ORG_REGISTRY_HMAC_KEY` secret to match the key used for any existing registry fingerprints; do not replace a key after registry entries have been created.

**Remaining scope:** Flutter Profile permit replacement still calls Firebase Cloud Functions. That specific path still requires deployed Functions or a separate Worker migration.

The review UI can approve/reject new organization applications and matched representative requests. An unmatched permit request is shown for investigation and can be rejected; it cannot be approved until the organization is registered or an administrator links it after verification.

## Firestore rules prerequisite

This repository's `firebase.json` currently configures only Functions; it does not contain the deployed Firestore rules. Before production use, merge rules into the project's existing rules that:

- deny client writes to `organizations`, both registry collections, membership subcollections, `organizationMembershipRequests`, and `organizationReviewers`;
- allow organization/member reads only to the applicant, approved members, or authorized reviewers;
- prevent clients from changing organization verification status, membership status, organization IDs, or membership summaries in `users/{uid}`;
- retain the existing access needed for reports, projects, profiles, and the other current app features.

Do not point `firebase.json` at a new partial rules file and deploy it as-is; unspecified existing collections would be denied. Until the current deployed rules are reviewed and these restrictions are merged, client-side status fields must not be treated as a security boundary.