# App Store Connect — metadata for to.morrow

Copy each block into the matching field. Character limits are Apple's; the
counts in brackets are what these drafts actually use.

**Updated 2026-09-03.** All copy below describes the current app: three
lists (Today / Tomorrow / Soon), the SkeuKit design system, and no Windows
95 references. It deliberately doesn't describe the visual design — copy is
function-only, per founder direction.

---

## Name  *(30 max)*

```
to.morrow
```
[9]

## Subtitle  *(30 max)*

```
Swipe tasks between days
```
[24]

## Category

- **Primary:** Productivity
- **Secondary:** Utilities

## Age rating

4+ — no objectionable content, no web access, no user-generated content shared
with anyone.

---

## Promotional text  *(170 max — editable without a new build)*

```
Swipe a task to tomorrow. Go Live pins it to your Lock Screen. Switch between Work and Personal. No account, no ads — just yours, synced through iCloud.
```
[152]

---

## Description  *(4000 max)*

```
to.morrow is a to-do list with three lists: Today, Tomorrow, and Soon.

SWIPE TO MOVE TASKS

Not going to get something done today? Swipe it right and it moves to tomorrow. Swipe left to bring it back.

GO LIVE

Pin whatever you're working on to your Lock Screen. Tap Go Live on a task and it stays there until you tick it off — no Home Screen widget, no extra app to check.

CHANGE WORKSPACES

Keep Personal and Work on separate lists, and switch between them whenever you need to.

PRIVATE

No account, no email, no password — nothing to sign up for. Turn on iCloud and your tasks and photos sync between your own devices, privately. No analytics, no ads, no third-party code, no server run by us.
```
[698]

---

## Keywords  *(100 max, comma-separated, no spaces after commas)*

```
todo,task,checklist,planner,productivity,swipe,reminders,lockscreen,workspace,offline
```
[85]

Notes on the choices:
- No "shove" or "95" — your own app name is already indexed, spending
  characters on it is waste.
- No plurals where the singular already matches ("task" also matches "tasks").
- No "retro"/"win95"/"pixel"/"90s" — the Windows 95 aesthetic was removed
  2026-08-22 in favour of the SkeuKit design system (see note below); those
  keywords would now attract the wrong audience and no longer describe the
  app.
- "offline" and "simple" are what people search when they're sick of
  subscription to-do apps, which is the audience for this.

---

## URLs

| Field | Value |
|---|---|
| Privacy Policy URL *(required)* | `https://lucasmaher-hash.github.io/to.morrow/privacy.html` |
| Support URL *(required)* | `https://github.com/lucasmaher-hash/to.morrow/issues` |
| Marketing URL *(optional)* | `https://lucasmaher-hash.github.io/to.morrow/` |

---

## App Privacy  *(the questionnaire, not the policy)*

Answer **"No, we do not collect data from this app."**

That is the honest answer and it is worth double-checking before you submit,
because it is the one claim Apple actively verifies. It holds because:

- there are no third-party SDKs of any kind in the project
- CloudKit writes to the user's own private database, which the developer
  cannot read — Apple does not count this as collection
- nothing is sent anywhere else

If you ever add analytics or a crash reporter, this answer changes and the
privacy policy needs updating with it.

---

## Screenshots

⚠️ `store/screenshots/` (`01-today.png` … `06-scheme.png`) shows the **Windows
95 app and must not be uploaded** — that interface no longer exists (removed
2026-08-22 in favour of SkeuKit) and Apple will reject on Guideline 2.3.3 for
showing software that isn't in the build.

`store/screenshots-new/` has three fresh SkeuKit captures (`01-today.png`,
`02-tomorrow.png`, `03-soon.png`) but isn't the final set.

The current working set is six composited frames in
`AppStore_screenshots_Shove.95/final_images/` (`Frame 1.png` … `Frame 6.png`),
fixed to 1320 × 2868 (6.9", iPhone 17 Pro Max) with the alpha channel
flattened — the only size App Store Connect requires; it scales down for
smaller devices itself. Upload the 6.9" Display tab, then use "Keep using
6.9" Display" so ASC reuses them for the other sizes instead of asking for
separately-sized ones.

---

## Build & review notes

- **Review notes field:** no demo account needed — the app has no login. Worth
  saying so explicitly, since a reviewer who expects one may reject for a
  missing account.
- **Export compliance:** the app uses no encryption beyond HTTPS/iCloud, so the
  answer to "does your app use encryption?" is the standard exempt path.
- **Copyright:** `2026 Lucas Maher`
