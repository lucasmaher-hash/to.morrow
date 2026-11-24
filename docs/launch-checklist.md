# to.morrow — iOS and macOS release audit

Release handoff updated 11 November 2026; initial audit 7 November. Native SwiftUI
apps share SwiftData models and a private CloudKit container. There is no custom
account backend or payment service. Lucas approved the current iOS/Mac design.

**Current state:** UI work is ready for release preparation. Neither binary is
ready to upload as-is: iOS still uses the already-published 1.3 (8), and Mac still
has a draft identity, no App Sandbox and no app category. No review submission or
App Store release was performed in this session.

## Recommended next order

1. Prepare iOS 1.4 with a new build number (recommend 9 only if App Store Connect
   still has no newer uploaded build). Keep the widget extension version matched.
2. Add native macOS to the existing to.morrow listing, using the same bundle ID
   `com.lucasmaher.shove95` for a single multi-platform product. Before changing
   the Mac draft's ID, plan migration of its local tasks, photos and preferences.
3. Enable and test Mac App Sandbox, including CloudKit, network and user-selected
   image file access. Remove Mac Draft naming; set public version/category.
4. Archive and validate distribution builds, upload, then test the exact processed
   builds through TestFlight on the physical iPhone and Mac. Verify photo sync,
   in-place changes and offline recovery without resetting stores.
5. Complete each platform's screenshots, release notes and review information,
   select the tested builds and submit for review. Manual release can retain a
   final publication decision after Apple approves.

These are preparation steps, not changes already applied. The guide below marks
who does each step and what counts as verification.

Engineering work needs several focused sessions; exact time depends on the sync
and photo findings. Apple review time is separate and not guaranteed. Estimates
below are planning estimates, not promises. No new recurring backend service is
required for this release; existing Apple Developer membership is already in use.

Legend: 🤖 agent can prepare/verify; 🧑 Lucas makes the product/account decision;
🤝 agent prepares, Lucas checks the final result.

## Evidence checked

| Check | Result |
|---|---|
| iOS regression tests | 43 passed, 0 failures |
| Mac tests | 32 passed on 11 November after the Live control fixes |
| Shared model tests | 60 passed, 0 failures |
| Release iOS archive | Succeeded, signing disabled for audit |
| Mac builds | Unsigned audit archive succeeded 7 November; current development-signed universal Release build succeeds |
| Distribution signing / Apple upload validation | Not performed; archives above are not upload-ready signed packages |
| Public/Connect iOS version | 1.3, build 8, Ready for Distribution |
| Current source iOS/extension versions | Both still 1.3 (8) |
| Native macOS listing under existing app | Absent; Distribution/TestFlight show iOS only |
| Mac source identity | com.lucasmaher.tomorrow.macdraft; 0.1 (1); “to.morrow Mac Draft” |
| Mac App Sandbox | Not present in entitlements |
| Mac category | Missing; archive emits No App Category warning |
| iOS packaged privacy manifest / icon / font license | Present |
| Mac packaged icon / font license | AppIcon.icns and W95FA-LICENSE.txt present |
| Mac privacy manifest | Absent. Review disclosures; do not treat iOS-only required-reason rules as an automatic Mac rejection |
| Privacy URL | Correct /to.morrow/privacy.html saved in the new 1.4 draft; takes effect with the next release. Previously published link returns 404 |
| Correct in-app privacy URL | /to.morrow/privacy.html returns HTTP 200 |
| CloudKit production schema | Missing Live fields deployed 7 November; no reset/removal |
| Physical iPhone ↔ Mac tasks | New Mac task appeared on physical iPhone; iPhone completion appeared on Mac after restart |
| Automatic in-place refresh / offline / photo round trips | Still not signed off |

Archives: `/private/tmp/tomorrow-release-audit-ios.xcarchive` and
`/private/tmp/tomorrow-release-audit-mac.xcarchive`. Audit logs use
`/private/tmp/tomorrow-release-*`. These are temporary engineering artifacts.

## Phase 0 — functional release gates

- [ ] 🤖 **Check automatic sync without restarting** — estimate 1–3 hours to
  reproduce/diagnose; fixes may take longer. Test tasks created, renamed,
  completed, moved, reordered, and deleted on each physical device while both
  apps stay open. Test workspace creation/rename too. The completion verification
  today required a Mac restart, so instant in-place updates are unproven.
  > Verify and fix live CloudKit import refresh on Mac without restarting, preserving editing and existing data; reproduce before changing code.
  **You'll know it worked when:** both screens update from remote changes in the
  already-running apps, including the Mac menu-bar Live panel.

- [ ] 🤖 **Check photos and offline recovery** — estimate 1–3 hours for testing,
  excluding any fixes. Initial bulk import logged missing `.interim` external-data
  file clone errors. These are not proof of permanent photo loss, but need checking.
  Add a new photo on iPhone, verify its stored asset and actual display; disconnect,
  edit tasks, reconnect, and confirm convergence without duplicates or lost edits.
  > Test production photo/asset and offline round trips on physical devices. Investigate the recorded external-data clone errors without deleting any store or photos.
  **You'll know it worked when:** photos remain accessible after relaunch and all
  offline changes arrive safely on the other device.

- [x] 🤖 **Include Mac photo attachments** — editing replaces the drag grip with a
  paperclip. Photos and Files source pickers, ordered thumbnails, full preview and
  photo deletion now use shared TaskPhoto records. Files import/preview and system
  Photos chooser opening verified in the signed Mac app; 29 Mac tests passed.
  Production cross-device photo/offline round trips remain a separate gate above.

- [ ] 🤝 **Test the final distribution builds as a user** — estimate 1–2 hours.
  Cover iOS 18 minimum support, current iOS, small-screen portrait/landscape,
  Live Activity completion, Mac menu-bar popup, keyboard input, settings, archive,
  dragging, and no-iCloud local use. Upgrade an existing iOS installation, keeping
  its tasks/photos/workspaces. Development simulator tests are not a substitute.
  **You'll know it worked when:** the exact candidate builds pass this smoke test
  and preserve existing data. Record the actual devices/OS versions tested.

## Phase 1 — iOS release preparation

- [ ] 🤖 **Bump version/build** — estimate 10 minutes. Recommend **1.4 (9)**,
  since 1.3 (8) is already published and 8 is the highest uploaded build observed.
  Set matching app and Live Activity extension values.
  > Prepare iOS version 1.4 build 9 for both the main app and ShoveWidgets, then verify the values in the archive. Do not upload yet.
  **You'll know it worked when:** the archive contains 1.4/9 for both bundles.

- [ ] 🤖 **Repair privacy metadata and clarify policy** — estimate 20–40 minutes.
  Created the iOS 1.4 draft and saved
  `https://lucasmaher-hash.github.io/to.morrow/privacy.html` in App Privacy.
  Apple marks the change Edited and says it applies with the next version. The
  draft is not submitted and no new build was selected/uploaded. Review policy wording:
  it currently suggests theme/tab settings mirror, but those remain device-local;
  include accurate native Mac/menu-bar behavior. Marketing page still describes
  an old beige design and four lists including Week/General; update that copy.
  > Prepare corrected App Store privacy URL, accurate iOS/Mac policy wording and marketing copy. Keep the existing no-tracking/no-developer-data-collection behavior and verify all links.
  **You'll know it worked when:** store links open the correct page and its claims
  match what actually syncs. This is a content accuracy review, not legal advice.

- [ ] 🤝 **Prepare new-version store assets and notes** — estimate 30–90 minutes.
  Existing iPhone screenshots can be reused where still accurate; review them against
  the flat checkboxes, linked Today/Live behavior and updated controls. Write 1.4
  release notes and reviewer instructions using only verified features/tests.
  **You'll know it worked when:** version 1.4 draft has accurate screenshots,
  notes, privacy/support links, selected candidate build, and no missing fields.

## Phase 2 — macOS App Store preparation

- [ ] 🧑 **Choose the store identity** — estimate 10 minutes. Recommended: add native
  macOS to the existing to.morrow listing so it is one product across devices.
  Apple's multi-platform listing requires the same bundle ID: `com.lucasmaher.shove95`.
  The current `.macdraft` ID would require a separate listing instead. Do not change
  the ID casually: settings/local storage/provisioning need migration planning.
  **You'll know it worked when:** the intended Mac platform/listing exists and the
  Xcode target uses the matching, deliberately chosen ID.

- [ ] 🤖 **Enable and test App Sandbox** — estimate 2–4 hours including migration
  and CloudKit testing; more if issues arise. Sandboxing is required for Mac App
  Store apps. Add only needed network/file entitlements, preserve existing draft
  data and local-only edits, and test CloudKit/remote notifications in the sandbox.
  > Prepare Mac App Store sandboxing with the selected bundle ID, required entitlements and a safe migration path for current Mac draft data; keep a backup and test before replacing the installed app.
  **You'll know it worked when:** the signed app has `com.apple.security.app-sandbox`
  enabled, launches, retains data, and syncs under its real sandbox permissions.

- [ ] 🤖 **Remove draft release metadata** — estimate 20–40 minutes. Set the
  intended public version (recommend Mac 1.0/build 1), remove “Mac Draft” from
  menu/window/bundle name, add `LSApplicationCategoryType` productivity, and confirm
  icon packaging. Current Mac minimum is macOS 26.0; deliberately keep or lower
  that supported OS floor, and test whatever is promised.
  > Prepare final native Mac naming/version/category/icon metadata, including the generator script so regeneration preserves it. Verify the archive and supported architectures.
  **You'll know it worked when:** no draft name appears, the category warning is
  gone, and the archive metadata matches the Mac listing.

- [ ] 🤝 **Build the Mac store page** — estimate 1–2 hours. Add Mac screenshots,
  platform description/keywords, privacy/support URLs, release/reviewer notes,
  age-rating/privacy answers and availability. Recheck any existing iOS-app-on-Mac
  availability: the public iOS listing already offers that Apple Silicon version;
  it is separate from proving this native Mac binary is ready.
  **You'll know it worked when:** native macOS has its own complete platform page
  and the tested candidate build can be selected.

## Phase 3 — sign, validate, submit

- [ ] 🤖 **Create distribution-signed archives and validate** — estimate 30–60
  minutes excluding fixes. The audit archives were unsigned intentionally. The
  installed Mac app is development-signed; a final App Store distribution export
  must be prepared/validated. Organizer may re-sign during distribution: its
  development identity alone is not proof that App Store signing is impossible.
  > Archive both final candidates, prepare App Store distribution signing, run Apple's validation, inspect entitlements/versions/icons, and report all validation issues. Do not submit for review yet.
  **You'll know it worked when:** Apple accepts the candidate packages and both
  builds finish processing without blocking warnings/errors.

- [ ] 🤝 **TestFlight, then submit for review** — estimate 1–2 hours of candidate
  testing plus Apple's variable processing/review time. Test the processed builds
  on the real devices and confirm production CloudKit works. Check account
  agreements/tax/compliance status if Apple prompts; Lucas handles legal acceptance.
  Keep manual release selected if Lucas wants a final release decision.
  **You'll know it worked when:** each platform reaches Waiting for Review, then
  approval; manual approval still needs the separate Release action.

## Authoritative references

- [App Store version currently live](https://apps.apple.com/de/app/to-morrow/id6798337661)
- [App Store Connect](https://appstoreconnect.apple.com/apps/6798337661/distribution)
- [Apple: adding platforms / matching bundle IDs](https://developer.apple.com/help/app-store-connect/create-an-app-record/add-platforms)
- [Apple: Mac App Sandbox](https://developer.apple.com/documentation/xcode/configuring-the-macos-app-sandbox)
- [Apple: review guidelines, including completeness and Mac sandboxing](https://developer.apple.com/app-store/review/guidelines/)
- [Apple: required-reason APIs](https://developer.apple.com/documentation/bundleresources/describing-use-of-required-reason-api)
- [Apple: SDK submission requirements](https://developer.apple.com/app-store/submitting/)
