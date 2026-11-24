# Mac iCloud sync

The native Mac app now uses the same TaskItem, TaskPhoto and Workspace model
and private CloudKit container as iOS: `iCloud.com.lucasmaher.shove95`.
No separate login or user database is involved. Every user signs into their own
Apple Account in system settings on both devices.

## Builds

- `scripts/build-icloud-app.sh` builds/signs the native Xcode target with the
  existing Developer team, provisions the Mac, and installs to
  `~/Applications/to.morrow.app`. Release explicitly uses **Production**, so it
  can sync with an App Store / TestFlight iPhone installation. Debug uses
  **Development**, which is a separate database.
- `scripts/package-app.sh` remains an **offline, ad-hoc-signed preview**.
  It cannot use iCloud. Settings says so; no CKContainer is constructed.
- Xcode: open `TomorrowMac.xcodeproj`, scheme TomorrowMac, destination My Mac.
  The project references the existing local Shove95Kit package.
- This development app currently retains the unsandboxed draft's original store
  path. A future Mac App Store release needs sandboxing and an explicit migration
  of that path; enabling sandboxing alone would show a different empty store.

## Preservation and behavior

Cloud-backed startup opens the original `TomorrowMacDraft` store in place,
preserving task UUIDs, workspace links and photos. Before the first cloud-backed
open, the store, SQLite sidecars and external asset directory are copied to
`Before-iCloud-TomorrowMacDraft` next to the existing store. Failure to back up or
open with CloudKit falls back to local storage. No seed/demo records are inserted
in cloud builds. Existing Mac records merge into the account; they are not replaced
with the phone's records.

Workspace readers follow the phone's oldest-record-wins deduplication for seeded
IDs and duplicate names. Unknown workspace IDs display in Personal without
rewriting remote records. Incoming Live replacement/completion refreshes the Mac
panel and menu-bar title. Core Data's iCloud event notifications are delivered to
the main run loop before interacting with MainActor state.

Settings reports the actual account availability and last successful import/export,
with errors distinct from an authenticated account. Visual preferences and custom
tab labels remain device preferences, as on the existing iPhone implementation.
Live data syncs; a Mac presentation does not create an iPhone ActivityKit activity.

## Deployment check, 2026-11-05

Apple Development provisioning and the Production-environment signed Mac build
succeeded. The app starts with the existing local data. CloudKit export reached
Apple but failed because Production schema lacks `CD_TaskItem.CD_isLiveNote`:
“Cannot create or modify field 'CD_isLiveNote' in record 'CD_TaskItem' in production schema”.
Deploy the existing additive Development schema changes to Production in CloudKit
Console, then relaunch the Mac app. Do not reset either environment or delete data.
This schema problem also affects current iPhone builds using that model.

Before declaring end-to-end sync verified: create/rename/reorder/complete a task
on each device, check workspace names and task assignments in both directions,
attach a photo on iPhone, and check offline edits after reconnection. A successful
Mac upload alone does not verify receipt by a physical iPhone.
