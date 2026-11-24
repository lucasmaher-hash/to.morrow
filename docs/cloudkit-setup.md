# Turning on iCloud sync (TASK-050)

> **Current state, 7 November 2026:** Production schema additions for Live were
> deployed. The signed Mac app and existing physical iPhone app exchanged tasks
> successfully, including a completion from iPhone back to Mac. Initial return
> verification required restarting Mac; continuous in-place refresh, photo and
> offline round trips remain to be checked. See `MacDraft/HANDOFF-2026-11-05.md`.
> The setup instructions below describe the original provisioning process.

Everything in the code is ready. What's left needs your Apple Account, so it
has to happen in Xcode on your machine — it's about two minutes.

## Why it isn't already on

With `cloudKitDatabase: .private(…)` and no iCloud entitlement, CoreData's
mirroring layer constructs a `CKContainer` the app isn't entitled to. That
raises an **Objective-C exception on a background queue**, which Swift's
`try/catch` cannot intercept — the app dies on launch with no usable error.
Verified 2026-08-04 by doing exactly that.

So the CloudKit path is behind a flag (`ShoveCloudKitEnabled` in Info.plist),
and until it's set the app runs on a local store. Nothing is lost either way —
same schema, same data, only the mirroring is absent.

## Steps

1. **Open the project** in Xcode → select the `shove95` target → **Signing &
   Capabilities**.
2. **Team:** pick your Apple Developer team. Leave *Automatically manage
   signing* ticked.
   *It must NOT say "(Personal Team)" — that is the free tier, which cannot use
   CloudKit, and while it is selected Xcode omits iCloud from the capability
   list entirely. The paid membership appears as a separate entry without the
   "(Personal Team)" suffix. If it isn't in the dropdown: Xcode → Settings →
   Accounts → select the Apple ID → refresh (or sign out and back in), since
   Xcode caches team membership; confirm the membership reads Active at
   developer.apple.com/account; and check it is the same Apple ID you enrolled
   with. Enrolment can take a few hours to activate after payment.*
3. **+ Capability → iCloud.** **Double-click** it in the library — single
   clicking only previews the description, and there is nothing to tick in that
   window. The picker closes and an iCloud section appears in the editor; the
   checkboxes are there. Tick **CloudKit**.
   *The capability list is alphabetical and long — iCloud sits between HomeKit
   and In-App Purchase, well below the visible first screen. If it is genuinely
   absent: you are on PROJECT rather than the shove95 TARGET (capabilities are
   per-target), or no Team is selected yet — iCloud is paid-membership-only and
   Xcode hides it until a paid team is picked, which is why step 2 comes first.* Under Containers press **+**
   and enter:
   ```
   iCloud.com.lucasmaher.shove95
   ```
   Xcode creates the container in the developer portal and points the
   entitlements file at it.
4. **+ Capability → Background Modes.** Tick **Remote notifications** (this is
   how a change on one device wakes the other).
5. **Set the flag.** In `shove95/Info.plist` add:
   ```xml
   <key>ShoveCloudKitEnabled</key>
   <true/>
   ```
6. **Run on a device.** The simulator can sync, but two simulators signed into
   the same account is a poor test — use your iPhone.

**Xcode writes its own entitlements file** at `shove95/shove95/shove95.entitlements`
and points `CODE_SIGN_ENTITLEMENTS` at it — it does NOT adopt a pre-existing one
elsewhere. On 2026-08-04 it created that file containing empty arrays and an
unwanted `icloud-extended-share-access` key: capability added, nothing actually
enabled. The prepared duplicate was deleted and the real file filled in. If the
iCloud section shows no container, check that file rather than the UI.

## Verifying (TASK-051)

1. Install on two devices signed into the same Apple Account.
2. Add a task on device A. It should appear on B within a few seconds — with
   the app foregrounded on B, since that's when it processes changes.
3. Attach a photo on A; confirm the image (not just the row) arrives on B.
   Photos are separate records with CKAsset payloads, so they travel
   independently of the task and may land a moment later.
4. Turn off Wi-Fi on A, add a task, turn Wi-Fi back on. It should sync when the
   connection returns, with no prompt and no error.
5. Sign out of iCloud on A. The app must keep working, showing
   `iCloud: not signed in` in Settings and nothing else. **No alert is
   acceptable here** (FR-013).

## Things that will bite

- **First sync is slow.** CloudKit provisions the schema on first write; give
  it a minute before deciding it's broken.
- **The schema must be promoted to production** before any TestFlight or App
  Store build, in the CloudKit Console → Schema → *Deploy Schema Changes*.
  Development and production schemas are separate, and a build against
  production with an unpromoted schema silently syncs nothing.
- **Model changes after promotion are additive only.** You can add optional
  fields; you cannot rename or retype an existing one. This is why photos moved
  to their own entity now rather than later.


## What syncs, and what doesn't

**Synced** (SwiftData → CloudKit private database): tasks, photos, and
workspaces. Workspaces became records on 2026-08-04 — as device preferences
with random ids they broke the moment a second device appeared, since tasks
reference a workspace BY id and every task arriving from elsewhere carried an
id the receiving device had never seen.

Two consequences of that design worth knowing:

- The seeded pair use FIXED ids (`default`, `work`), so two devices that both
  seed on first launch converge on one pair instead of four. CloudKit forbids
  unique constraints, so readers dedupe by id and the oldest record wins.
- A workspace this device doesn't recognise shows its tasks in the DEFAULT
  workspace, and the record is never rewritten. Silent display fallback beats
  mutating a record that another device is authoritative for.

**Not synced, deliberately:** the colour scheme, the tab names, and which
workspace you are currently looking at. All three are device preferences, like
text size — the last one is closer to a scroll position than to data.
