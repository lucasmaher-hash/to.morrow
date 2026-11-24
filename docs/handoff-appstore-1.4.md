# Handoff: App Store Connect form for iOS 1.4 (for Codex in Chrome)

Created 2026-11-24 by Claude Code. Task: complete the iOS 1.4 version page in
App Store Connect in Lucas's Chrome, where he is already signed in. Read the
whole file before starting.

## Hard limits

- Do NOT click **Add for Review** or **Submit for Review**. Lucas does that himself.
- Do NOT enter passwords, sign in, or accept agreements. If a login or
  agreement shows up, stop and tell Lucas.
- Do NOT change App Privacy answers, pricing, availability, or the 1.3 version.
- Only edit the **1.4 Prepare for Submission** page. Click **Save** after each section.
- Report back: done / skipped / blocked, field by field.

## Where

App Store Connect → Apps → to.morrow → Distribution → iOS App → **1.4 Prepare for Submission**
URL: https://appstoreconnect.apple.com/apps/6798337661/distribution

## Fields to fill

### 1. What's New in This Version (English U.S.)

Paste exactly:

```
- Go Live is easier to spot: the active Live control now pulses, and the Live glyphs match across the app and the Lock Screen.
- Ticking off the Live task from the Lock Screen now plays its completion and removes the card cleanly.
- If iOS ends the Lock Screen card after its time limit, opening the app brings it back.
- In landscape, tasks moved between Today, Tomorrow and Soon now glide across to their new list.
- Smoother reordering and fixes for task editing.
```

If other localizations exist (language menu next to "Product Page
Information"), report them. Do not translate without Lucas's OK.

### 2. Leave as they are (just check they're filled in)

- Description, Keywords, Support URL, Marketing URL, Copyright: already filled.
- Version: 1.4.

### 3. Screenshots

Leave the existing ones. Report how many there are per device size.
Do not upload or delete any.

### 4. Build

The build is **1.4 (9)**. Lucas uploads it from Xcode. Apple's processing
takes about 10 to 30 minutes.
- If the Build section shows "Add Build" / a + button: select **1.4 (9)**.
- If it is still empty: report "build not processed yet" and continue.
- If Export Compliance questions appear: the app uses no encryption apart
  from Apple's standard HTTPS/CloudKit. Answer "None of the algorithms
  mentioned above" / exempt. If the options don't match that, stop and ask.

### 5. App Review Information

- Sign-in required: **unchecked** (the app has no account).
- Contact: already filled, leave it.
- Notes, paste:

```
No account or login is needed. All data stays on the device; iCloud sync through the user's private CloudKit database is optional.
To test Go Live: long-press a task, choose Go Live. The task appears as a Live Activity on the Lock Screen and in the Dynamic Island, and can be completed there.
```

### 6. Version Release

Choose **Manually release this version** so Lucas decides when it goes live.

### 7. App Privacy (just check, don't edit)

Privacy Policy URL should be
`https://lucasmaher-hash.github.io/to.morrow/privacy.html`. Report whether it is.

## Report back

A short table: field · status · note. Then what is still missing before
Lucas can click "Add for Review" himself.
