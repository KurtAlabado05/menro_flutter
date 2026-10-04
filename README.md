# CENRO Connect

CENRO Connect is a Flutter application for environmental reporting and related
local government services. This summary describes the environmental report
submission and case-correspondence workflow currently present in the app.

## EcoMap Branding

The supplied EcoMap logo is stored in `assets/images/ui/ecomap_logo.png`.
Login, registration, onboarding, startup, and the citizen and inspection-officer headers display it
beside the existing Baliwag seal used for MENRO partnership branding.
The shared logo widget uses square display variants with excess transparent
margins removed, so both marks remain legible at header sizes. Original files
are preserved. Both marks have transparent backgrounds without a white
container. Header marks use 44-pixel image boxes with no inner padding; login
marks use 112-pixel boxes.

Regenerate the display variants after replacing either source:

```sh
dart run tool/prepare_brand_logos.dart
```

Launcher icons for Android, iOS, web, Windows, and macOS are generated from the
same source. After changing the logo, run:

```sh
flutter pub get
dart run flutter_launcher_icons
```

Native icon changes require rebuilding/reinstalling the app. Browser favicons
and installed web-app icons may require a cache refresh or web-app reinstall.
After adding assets, stop and relaunch `flutter run` so the development server
rebuilds its asset bundle. Hot reload alone can leave new image URLs returning
404.

Onboarding opens automatically on devices that have not completed a successful
login. Returning users can replay it through **View app introduction** on the
login screen without resetting their login preference. Closing or completing
the replay returns to the existing login screen.

## Environmental Reporting

### Environmental Map

The map loads reports and community projects independently, so a failed layer
does not hide records from the other layer. Citizens and organizations see their
own reports, while staff with workflow access can see all reports; project
visibility remains available to signed-in accounts. Existing Firestore access
rules are unchanged.

Use Refresh (or Retry after an error) to reload map records. Records without
usable latitude and longitude are counted in the map header but are not placed
at invented locations. The Baliwag boundary remains highlighted, but it is not
a hard viewport restriction: zoom controls and panning can show nearby projects
outside the boundary. Zoom controls disable at the supported zoom limits.

Report, permit, and project tabs share rounded selection, hover, and ripple
shapes.

### Reporter Workflow

1. A signed-in citizen creates a report by selecting a category and entering a
	title, description, and location. Available categories include illegal
	dumping, waterway pollution, improper wastewater disposal, open burning,
	public smoking violations, and littering or public vandalism. The form can
	use device location and address lookup to prefill coordinates and address
	details. The reporter can add barangay, street or sitio, landmark, and photo
	evidence.
2. Before saving, the app looks for an active report with the same category
	within 35 metres. Resolved, closed, archived, and reports older than 48 hours
	are excluded. When a nearby report is found, the reporter can support it
	instead of submitting another report.
3. A new report is saved to Firestore's `reports` collection with an initial
	`pending` status and a status-history entry confirming submission.
4. The reporter can find their submissions, open report details, review the
	status history, and follow case correspondence. Report details also include
	location and submitted evidence.

The report model records the category, description, location coordinates and
address details, evidence URLs, submitter identity and contact, creation time,
status, and status history. The form assigns an initial severity value from the
selected category; this is a fixed category mapping, not an inspection result
or staff assessment. The current report form submits authenticated reports;
anonymous submission is not enabled there.

### Report Status Lifecycle

The configured main path is:

```text
Pending -> Under Inspection -> For DENR Review -> DENR Approved -> Resolved
```

| Status | Meaning in the configured workflow |
| --- | --- |
| `pending` | The report has been submitted and is waiting for initial clerk review. This is the initial status written by the report form. |
| `inspection_in_progress` | An inspector is reviewing or investigating the reported issue. The UI also maps names such as `under inspection` and `inspecting` here. |
| `forwarded_to_denr` | The report has been referred to DENR and is awaiting its review or decision. |
| `approved_by_denr` | DENR approval has been recorded. Approval is a decision milestone; it does not by itself mean the reported environmental issue has been resolved. |
| `resolved` | The issue or case has reached its resolution state. This is the final step in the configured main path. |

`on_hold` is a pause while processing is waiting on an external action or more
information. `rejected` (also displayed for values such as `denied`) is an
alternate outcome, not a step toward approval. These values do not have detailed
reason or resumption rules in the current report workflow.

Status labels are normalized for display, so several strings can produce the
same badge. For example, `approved` is also treated as `DENR Approved`, and
`forwarded_to_inspection_officer` is displayed as `Under Inspection`. Use the
canonical status keys above when writing report data; avoid generic values such
as `approved` when the approving authority matters.

`verified` is also recognized by the shared status helper, but its position is
unclear: it is assigned an order after DENR approval, treated as completed by
one helper, and omitted from the configured main-path list. Decide whether
verification means an initial intake check or a post-processing check before
using it as a report status.

The report details activity feed combines these status-history entries with
correspondence. Each status entry can carry a status key, explanation, time,
and updater. Status history records events; the report's current `status` field
is separately used for badges, filters, and active-report checks.

Important current behavior: the Flutter report form writes only the initial
`pending` event. The app displays later status entries but does not currently
provide a staff report-status transition workflow or enforce this sequence.
The lifecycle above describes the configured statuses, not an automated state
machine.

### Case Activity and Correspondence

Report details present status-history entries and correspondence in one
chronological activity feed. Official status changes are labeled separately
from submitter updates and staff responses. Correspondence is stored in a
`messages` subcollection under its report document:

```text
reports/{reportId}/messages/{messageId}
```

Messages include the sender UID and display name, sender role, message type,
text, optional image URL, and server timestamp. Submitter messages also include
a topic. The reporter can choose a reason such as asking a case question,
providing information, or responding to a staff request. Text is limited to
1,000 characters and image attachments to 5 MB in the client. The feed combines
status history with the most recent 50 messages, ordered by timestamp.

Older messages without role/type metadata remain displayable; the UI identifies
the submitter by matching the message UID with the report owner.

## Staff Workflow

The correspondence component allows the report owner and users whose profile
role is one of `admin`, `staff`, `menro`, `denr`, `menro_staff`, or `denr_staff`
to reply. Submitters receive a topic selector and send case updates; staff can
send official case responses. Both are shown in the same activity feed with
different labels.

Public registration currently offers `citizen` and `organization` roles, not
staff roles. Staff access therefore depends on staff roles being assigned to
user records through a separate trusted process. The dashboard displays
reporter status updates and admin-scoped pending counts, but the Flutter app
currently has no staff report queue or report-status editing workflow.

## Current Boundaries

- Status history is rendered from the report document's `statusHistory` field.
  The Flutter report flow writes the initial pending event; no in-app staff
  action currently appends later environmental-report status events.
- Automated messages triggered by status changes are not implemented.
- The correspondence role check controls what the client displays. It is not a
  security boundary. Firestore rules or trusted backend authorization must
  enforce who can read and write report messages; client-side character and
  attachment limits must also be validated server-side.
- Do not put internal staff notes in this public-to-case-participants message
  stream. Internal notes require a separate staff-only data path and access
  policy.

## Recommended Next Staff Capabilities

Before adding automated messages, add a staff workflow to assign and process
reports. A status action should update the report's current status and append
an attributable, timestamped status-history event together. Notifications
should be generated from that committed event so retries do not send duplicate
messages. Add server-enforced access controls, message throttling, and audit
retention before treating correspondence as private or abuse-resistant.

## Run Locally

Install Flutter dependencies and launch the app with:

```sh
flutter pub get
flutter run
```
