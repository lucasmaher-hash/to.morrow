# Accessibility & pre-submission QA — shove.95

Run 2026-09-01 against commit `d58ae17`, on iPhone 17 Pro Max (iOS 26.5,
simulator) and iPhone 12 Pro (iOS 26.6, device install).

This is the record TASK-058 asks for. It states what was checked, how, and
what remains for the founder — the last part matters, because two of the
items below cannot be driven from a script and were not faked.

---

## Result summary

| Area | Result |
|---|---|
| Unit tests (Shove95Kit) | **56 tests / 14 suites, all pass** |
| Release archive | **Succeeds**, no warnings |
| Dynamic Type at AX5 | **Pass** — no clipping on any screen |
| Reduce Motion | **Pass** — zero pixel change over 7.5s |
| Dark mode | **Pass** |
| VoiceOver labels (static) | **Pass** — see caveat |
| Core flow (add → swipe → land) | **Pass** |
| Full VoiceOver walkthrough | **NOT DONE** — founder task |

---

## What was checked

### Dynamic Type — largest accessibility size (AX5)

Set with `xcrun simctl ui <udid> content_size accessibility-extra-extra-extra-large`,
then walked the list, Settings, and How to use.

- Home list: tab bar abbreviates and shrinks, nothing clipped, the workspace
  pill and gear stay on screen.
- Settings: headings and controls scale, no overlap, everything reachable.
- How to use: all three blocks lay out correctly, including the two live
  control demos and the swipe rows.

**One false alarm worth recording**, because it would otherwise be re-found:
the Swiping block looked *empty* at AX5 on two consecutive screenshots. It is
not a layout failure — the swipe demo has a phase where both rows have left
the frame, and two samples happened to land in it. Six frames at 1.2s
intervals showed ink in that band varying from 2.6% to 37.7%, and the fullest
frame shows both rows laid out correctly. **Sample an animated block across a
full cycle before calling it broken.**

### Reduce Motion

Enabled via `defaults write com.apple.Accessibility ReduceMotionEnabled -bool
true`, app relaunched, then four screenshots at 2.5s intervals on How to use —
the screen with all three looping demos.

**Zero pixels changed across all three intervals.** The Live switch, the
workspace pill and the swipe sequence all hold still, which is §8.5's rule:
Reduce Motion turns decoration off rather than slowing it down.

### VoiceOver labels — static audit

Every interactive element was checked for a label or self-labelling text:

- Row menu items and dialog buttons carry `.isButton` and their own `Text`,
  which VoiceOver reads — no separate label needed.
- The confirmation dialog sets `.isModal`, so content behind it is hidden.
- The task row exposes edit, reorder and photos as custom actions (added
  2026-08-31 — the row collapses to one element, so without them those three
  were unreachable).
- The three How to use demos are `.accessibilityHidden(true)`: they are
  pictures of controls, not controls, and the block's own words carry the
  meaning. The bin is also hidden while disabled.

### Contrast

Documented in the palette rather than re-measured here:

- `inkMuted` — 6.4:1 on material, used for body text
- `inkFaint` — 3.4:1, **decorative labels only**
- `critical` — lifted to 5.2:1 in the dark palette
- The day chip and the reorder grip both take `inkFaint` at full strength —
  **3.4:1** — matching the "add" placeholder (founder direction 2026-09-01).

  This is a deliberate trade recorded rather than hidden. The grip is fine:
  3.4:1 clears the 3:1 WCAG 1.4.11 asks of a control's affordance. The **day
  chip is now below the 4.5:1 text floor** — it was `ink` at 0.72 precisely to
  hold that, since the chip is the only place the list says when a task is
  due. It was changed for visual consistency across the three quiet elements
  on a row, with the contrast cost known.

  Never DIM `inkFaint` further: measured at 1.90:1 in review 2026-08-26,
  roughly half the floor and invisible in daylight.

### Touch targets

`SkeuControl.minTouch` (44pt) is applied to the checkbox, the grip, the sheet
✕, the gear, the workspace pill and the Live controls. The glass pills in
About are 38pt tall with a 44pt target frame around them.

### Core flow

Add a task → swipe it right → confirm it lands in Tomorrow. Passed on a wiped
install.

---

## Still to do — founder only

1. **Full VoiceOver walkthrough on the device.** VoiceOver cannot be driven
   from a script, so this was NOT done and must not be recorded as passing.
   Turn it on (Settings → Accessibility → VoiceOver) and swipe through: add,
   edit, complete, move via custom actions, undo, archive, settings, and the
   photo viewer — the viewer in particular needs its close button reachable.

2. **Accessibility Inspector audit.** Xcode → Open Developer Tool →
   Accessibility Inspector, point it at the running app, run the audit on each
   screen.

3. **The 3-day soak** (TASK-065). A lot of behaviour changed on 2026-09-01;
   use the build as the only to-do list before submitting.

---

## Known cosmetic issue

`hasOnboarded` was removed with the walkthrough, but its stored
`settings.onboarded` key is not cleaned up on upgrade. Harmless — an orphaned
boolean in UserDefaults — recorded so it is not re-discovered as a mystery.
