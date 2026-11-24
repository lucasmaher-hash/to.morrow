# to.morrow — iOS and macOS release audit

Release handoff updated 11 November 2026; initial audit 7 November. Native SwiftUI
apps share SwiftData models and a private CloudKit container. There is no custom
account backend or payment service. Lucas approved the current iOS/Mac design.

**Current state (24 November 2026):** iOS 1.4 (9) is uploaded and submitted;
App Store Connect shows "Waiting for Review". Lucas confirmed sync and tested
the build on his iPhone; 44 iOS tests passed. iOS Phase 0/1 items are done.
Mac 1.0 (1) is prepared on `mac/app-store-1.0`: shared bundle ID, App Sandbox,
release metadata and privacy manifest are present. Universal archive and App Store
export succeeded. Lucas reported all local checks passed and explicitly
authorized upload. Mac 1.0 (1) uploaded successfully; Apple reported processing.
The native Mac platform page is now saved with build 1.0 (1), six full-resolution screenshots
and copied metadata. Lucas selected automatic release after approval. Exact-build
TestFlight testing and Add for Review remain his next steps. See the dated Mac evidence below.

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
   select the tested builds and submit for review. For native Mac 1.0, Lucas
   selected automatic release after approval on 24 November. Leave the existing
   iOS release setting unchanged.

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
| Mac tests | 34 passed on 24 November, including two migration tests and real external-photo backup coverage |
| Shared model tests | 60 passed, 0 failures |
| Release iOS archive | Succeeded, signing disabled for audit |
| Mac builds | Universal Release 1.0 (1) uploaded; App Store Connect reports Validated and build is selected in macOS version 1.0 |
| Distribution signing / Apple upload validation | Native Mac archive/export/validation/upload verified 24 November; iOS was not re-audited in this Mac-only task |
| Public/Connect iOS version | 1.3, build 8, Ready for Distribution |
| Current source iOS/extension versions | Both still 1.3 (8) |
| Native macOS listing under existing app | macOS 1.0 Prepare for Submission; six 2880x1800 PNG screenshots, metadata, review notes and 1.0 (1) saved; automatic release after approval |
| Mac source identity | com.lucasmaher.shove95; 1.0 (1); “to.morrow”; minimum macOS 26.0 |
| Mac App Sandbox | Signature permissions verified; Lucas reported all requested local checks passed on 24 November; exact processed TestFlight build still pending |
| Mac category | public.app-category.productivity in archive/export; category warning absent |
| iOS packaged privacy manifest / icon / font license | Present |
| Mac packaged icon / font license | AppIcon.icns and W95FA-LICENSE.txt present |
| Mac privacy manifest | Packaged PrivacyInfo.xcprivacy; no tracking/collection; own UserDefaults reason CA92.1 |
| Privacy URL | Correct /to.morrow/privacy.html saved in the new 1.4 draft; takes effect with the next release. Previously published link returns 404 |
| Correct in-app privacy URL | /to.morrow/privacy.html returns HTTP 200 |
| CloudKit production schema | Missing Live fields deployed 7 November; no reset/removal |
| Physical iPhone ↔ Mac tasks | New Mac task appeared on physical iPhone; iPhone completion appeared on Mac after restart |
| Automatic in-place refresh / offline / photo round trips | Still not signed off |

Archives: `/private/tmp/tomorrow-release-audit-ios.xcarchive` and
`/private/tmp/tomorrow-release-audit-mac.xcarchive`. Audit logs use
`/private/tmp/tomorrow-release-*`. These are temporary engineering artifacts.

## Phase 0 — functional release gates

- [x] 🤖 **Check automatic sync without restarting** — estimate 1–3 hours to
  reproduce/diagnose; fixes may take longer. Test tasks created, renamed,
  completed, moved, reordered, and deleted on each physical device while both
  apps stay open. Test workspace creation/rename too. The completion verification
  today required a Mac restart, so instant in-place updates are unproven.
  > Verify and fix live CloudKit import refresh on Mac without restarting, preserving editing and existing data; reproduce before changing code.
  **You'll know it worked when:** both screens update from remote changes in the
  already-running apps, including the Mac menu-bar Live panel.

- [x] 🤖 **Check photos and offline recovery** — estimate 1–3 hours for testing,
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

- [x] 🤝 **Test the final distribution builds as a user** — estimate 1–2 hours.
  Cover iOS 18 minimum support, current iOS, small-screen portrait/landscape,
  Live Activity completion, Mac menu-bar popup, keyboard input, settings, archive,
  dragging, and no-iCloud local use. Upgrade an existing iOS installation, keeping
  its tasks/photos/workspaces. Development simulator tests are not a substitute.
  **You'll know it worked when:** the exact candidate builds pass this smoke test
  and preserve existing data. Record the actual devices/OS versions tested.

## Phase 1 — iOS release preparation

- [x] 🤖 **Bump version/build** — estimate 10 minutes. Recommend **1.4 (9)**,
  since 1.3 (8) is already published and 8 is the highest uploaded build observed.
  Set matching app and Live Activity extension values.
  > Prepare iOS version 1.4 build 9 for both the main app and ShoveWidgets, then verify the values in the archive. Do not upload yet.
  **You'll know it worked when:** the archive contains 1.4/9 for both bundles.

- [x] 🤖 **Repair privacy metadata and clarify policy** — estimate 20–40 minutes.
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

- [x] 🤝 **Prepare new-version store assets and notes** — estimate 30–90 minutes.
  Existing iPhone screenshots can be reused where still accurate; review them against
  the flat checkboxes, linked Today/Live behavior and updated controls. Write 1.4
  release notes and reviewer instructions using only verified features/tests.
  **You'll know it worked when:** version 1.4 draft has accurate screenshots,
  notes, privacy/support links, selected candidate build, and no missing fields.

## Phase 2 — macOS App Store preparation

- [x] 🧑 **Choose the store identity** — estimate 10 minutes. Recommended: add native
  macOS to the existing to.morrow listing so it is one product across devices.
  Apple's multi-platform listing requires the same bundle ID: `com.lucasmaher.shove95`.
  The current `.macdraft` ID would require a separate listing instead. Do not change
  the ID casually: settings/local storage/provisioning need migration planning.
  **You'll know it worked when:** the intended Mac platform/listing exists and the
  Xcode target uses the matching, deliberately chosen ID.

- [x] 🤖 **Enable and test App Sandbox** — estimate 2–4 hours including migration
  and CloudKit testing; more if issues arise. Sandboxing is required for Mac App
  Store apps. Add only needed network/file entitlements, preserve existing draft
  data and local-only edits, and test CloudKit/remote notifications in the sandbox.
  > Prepare Mac App Store sandboxing with the selected bundle ID, required entitlements and a safe migration path for current Mac draft data; keep a backup and test before replacing the installed app.
  **You'll know it worked when:** the signed app has `com.apple.security.app-sandbox`
  enabled, launches, retains data, and syncs under its real sandbox permissions.

- [x] 🤖 **Remove draft release metadata** — estimate 20–40 minutes. Set the
  intended public version (recommend Mac 1.0/build 1), remove “Mac Draft” from
  menu/window/bundle name, add `LSApplicationCategoryType` productivity, and confirm
  icon packaging. Current Mac minimum is macOS 26.0; deliberately keep or lower
  that supported OS floor, and test whatever is promised.
  > Prepare final native Mac naming/version/category/icon metadata, including the generator script so regeneration preserves it. Verify the archive and supported architectures.
  **You'll know it worked when:** no draft name appears, the category warning is
  gone, and the archive metadata matches the Mac listing.

- [x] 🤖 **Package Mac privacy manifest** — checked 24 November: native resource
  and preview packaging include `PrivacyInfo.xcprivacy`, matching iOS disclosures
  and naming actual Mac settings/migration use. Archive and exported app contain it.

- [x] 🤝 **Build the Mac store page** — estimate 1–2 hours. Add Mac screenshots,
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
  For native Mac 1.0, use Lucas's selected automatic release after approval.
  Leave the iOS release setting unchanged.
  **You'll know it worked when:** each platform reaches Waiting for Review, then
  approval. Native Mac 1.0 is configured to release automatically after approval;
  no separate manual Release action is planned for that version.

## Native Mac candidate evidence — 24 November 2026

Status vocabulary: **prepared** = implementation/assets available; **verified** =
observed by a stated check; **sent** = uploaded/submitted. Mac 1.0 (1) is sent;
no Mac review submission has been made.
The existing iOS target/version/listing were left untouched.

- [x] **verified — identity:** generator and regenerated project use
  `com.lucasmaher.shove95`, team `35875F7J33`. CloudKit container is unchanged:
  `iCloud.com.lucasmaher.shove95`. Regeneration is byte-identical.
  The native macOS platform now exists under App Store Connect app 6798337661.
- [x] **verified — backup before ID change:** dated, private offline backup with
  a SHA-256 manifest, 13 files / 7,498,298 bytes. Includes store/WAL/SHM,
  `.TomorrowMacDraft_SUPPORT`, CloudKit asset directory, previous pre-sync backup,
  original preference plist and exported preferences. No private data was committed.
- [x] **verified — migration algorithm:** two new regression tests use a
  disposable copy of the dated backup. Copy bytes match, rerunning leaves the
  destination unchanged, existing preferences win, original copy is unchanged,
  migrated SwiftData opens and photo payloads remain readable. Staging is atomic;
  cancellation/failure stops startup before an empty store can be created.
- [x] **verified — signed sandbox permissions:** exported app has App Sandbox,
  outgoing client networking and user-selected read-only file access, alongside
  production push and Production CloudKit. `get-task-allow` is absent. No broad
  Photos, Documents or home-directory exceptions were added.
- [x] **verified — Mac tests:** **34 passed, 0 failed**, 8 suites. Includes the
  existing 32 tests plus migration success/failure tests; strengthened the existing
  backup regression to cover the real `.TomorrowMacDraft_SUPPORT/_EXTERNAL_DATA`
  directory. Tests open copies with CloudKit disabled.
- [x] **verified — release metadata/resources:** archive/export contain
  to.morrow 1.0 (1), Productivity category, macOS **26.0** minimum, arm64/x86_64,
  AppIcon.icns (including 1024px image), font/license and privacy manifest.
- [x] **verified — distribution export:** Release archive and local
  `app-store-connect` export succeeded with `-allowProvisioningUpdates`.
  Installer uses the Mac App Store installer identity and app signature verifies
  strictly; production entitlements were inspected in the expanded package.
- [x] **verified — final candidate Apple validation:** validate-only succeeded
  for source commit `b60fe57` at 11:35 CET. Xcode recorded “Validation succeeded”,
  empty validation errors/warnings and `uploadEvent=(null)`. This action did not
  upload a build; the later authorized upload is recorded below.
- [x] **verified by Lucas — local sandbox checks:** Lucas reported “tested all”
  on 24 November, covering the requested local migration/persistence, Photos/Files,
  Live and sync checks. This is user-reported evidence, not a new automated visual
  pass. The exact processed TestFlight build has not yet been checked here.
- [x] **sent — upload:** Lucas explicitly approved “Go: upload and prepare the
  Mac listing”. Xcode uploaded native macOS 1.0 (1) successfully and returned
  `EXPORT SUCCEEDED`; Apple reported “Uploaded package is processing”. No new
  version/build was created and no iOS build was uploaded. Processing completion
  was subsequently verified: Binary State Validated, build 1.0 (1) selected.
- [x] **verified — native Mac listing:** macOS 1.0 exists under app 6798337661
  with state Prepare for Submission. Six 2880x1800 RGB/sRGB PNGs in
  `store/screenshots/macos/2026-11-24-refined/` replaced the earlier three JPGs
  at Lucas's request. Filenames 01–06 define order. The task-menu header is
  aligned by removing its measured 64px title-bar offset and traffic lights;
  the menu-bar popover retains its black status bar. All images have restrained
  sharpening, with original source screenshots preserved. The remote gallery
  shows 6 of 10 App Screenshots after reload. Description, keywords,
  support and marketing URLs match the current iOS listing exactly. Shared
  privacy URL is `https://lucasmaher-hash.github.io/to.morrow/privacy.html` and
  Data Not Collected remains unchanged. Reviewer notes cover no login, optional
  iCloud, first-launch migration choice, menu-bar Live and Cmd-Shift-L.
  Build 1.0 (1) is selected. Saved values were checked after reload.
- [x] **verified — Mac release mode:** Lucas changed his instruction to
  **Automatically release this version** after approval on 24 November. The
  selected radio was saved for Mac 1.0 and verified again after reload. This replaces the earlier manual-release
  instruction for this Mac version only. iOS release settings were not changed.
- [ ] **Lucas — exact-build TestFlight test and Add for Review:** TestFlight
  reports Ready to Submit and Binary State Validated; existing internal groups
  are attached. No tester groups/invitations were changed. Lucas still tests the
  processed build on his Mac and clicks Add for Review himself. The agent did not
  click Add for Review or accept any agreement.

## Upload follow-up — 24 November 2026

- [x] **sent — native Mac 1.0 (1):** uploaded candidate source `b60fe57`; original
  package hash and versions were verified before upload. No App Review action.
- [x] **verified — matching crash symbols recovered locally:** upload emitted
  “Upload Symbols Failed” because the original archive had no dSYM. Recovered
  full symbols from retained unstripped linker outputs, verified both uploaded
  binary UUIDs and 335 compile units, and added them to the local archive and a
  separate dSYM ZIP. The first attempt against the stripped archive executable
  contained no debug info and was discarded from deliverables.
- [x] **verified — future Release setting:** generator now resolves Release
  `DEBUG_INFORMATION_FORMAT=dwarf-with-dsym`; Debug remains `dwarf`. This setting
  does not alter or replace the already uploaded build.
- [ ] **prepared — upload recovered symbols:** matching symbols are local only;
  their presence in App Store Connect is not verified.
- [x] **verified — App Store Connect access resumed:** Lucas signed in himself
  and said continue. The authorized in-app browser was used because Chrome was
  unavailable to browser tooling. No agent-entered credentials.
- [x] **verified — processing/build selection:** Binary State Validated; native
  Mac version/build 1.0 (1), minimum macOS 26.0, x86_64 and arm64, production
  CloudKit/push and sandbox entitlements all visible in App Store Connect. The
  build was selected and saved in the Mac 1.0 version. TestFlight shows Ready to
  Submit with existing internal groups day ones and windows version.
- [ ] **prepared — crash symbols upload:** App Store Connect still reports
  Includes Symbols: No. Matching recovered dSYMs remain local; there is no
  symbol-upload control on the inspected build metadata page.

## Screenshot refinement and replacement — 24 November 2026

- [x] **verified — exact screenshot cleanup:** Lucas authorized pixel edits.
  Six captures were converted to 16:10 without generated UI/text. Refined assets
  are 2880x1800 lossless PNGs with sRGB profiles and restrained sharpening.
  The task-menu screenshot's measured 64px extra title-bar area and traffic lights
  were removed; its header and task spacing now align with the fullscreen shots.
  The Live menu-bar popover retains a native black menu bar to show its origin.
- [x] **sent and verified — Mac gallery replacement:** uploaded all six full-size
  PNGs, then removed the superseded three JPGs from the Mac version's gallery
  (retained in Asset Library and repo). Reload confirmed exactly six files in
  order, no unsaved changes, unchanged metadata and automatic release still set.
- [x] **verified — scope:** native macOS 1.0 only. No iOS screenshot/listing edits,
  no new binary upload, no Add for Review or agreement acceptance.

Warnings/errors recorded during preparation:

1. Initial test signing in the file-provider workspace failed with resource
   fork/Finder information. Rebuilt in `/private/tmp`; final 34 tests passed.
2. Archive warning: “Metadata extraction skipped, no AppIntents.framework
   dependency found”. No App Intents dependency is used by this Mac target.
3. First validate-only invocation rejected `destination=export`; Xcode requires
   its transport destination for `method=validation`. The validation-only action
   then succeeded without creating a build upload event.
4. Concurrent export/validation generated the same logging-bundle filename
   (Cocoa error 516). Xcode fell back to inline logging; both operations still
   succeeded, and the final validation event has empty errors/warnings.
5. Upload warning: missing dSYM for the uploaded arm64/x86_64 UUIDs. Matching
   full symbols were recovered locally; Apple has not received those symbols yet.
6. App Store Connect also displays existing shared notices about age-rating
   answers (15 January 2027) and China mainland compliance (31 January 2027).
   Those shared settings were not changed; no legal acceptance was performed.
7. Native automation `timeoutReached` is unresolved. It also occurs for Xcode;
   do not infer visual app behavior or a hang from that timeout. Only process
   startup, signatures, automated tests and packaging are established.

Release evidence is kept with the private local release outputs, including the
backup manifest, final test/archive/export/validation logs and package checksums.
Lucas reported the local device checks passed. Exact processed-build TestFlight
testing and Add for Review remain Lucas's release gates. Mac 1.0 is configured
for automatic release after approval. No store, photo or original app was
deleted or replaced.

## Authoritative references

- [App Store version currently live](https://apps.apple.com/de/app/to-morrow/id6798337661)
- [App Store Connect](https://appstoreconnect.apple.com/apps/6798337661/distribution)
- [Apple: adding platforms / matching bundle IDs](https://developer.apple.com/help/app-store-connect/create-an-app-record/add-platforms)
- [Apple: Mac App Sandbox](https://developer.apple.com/documentation/xcode/configuring-the-macos-app-sandbox)
- [Apple: review guidelines, including completeness and Mac sandboxing](https://developer.apple.com/app-store/review/guidelines/)
- [Apple: required-reason APIs](https://developer.apple.com/documentation/bundleresources/describing-use-of-required-reason-api)
- [Apple: SDK submission requirements](https://developer.apple.com/app-store/submitting/)
