# Design System — shove.95

> Windows 95, derived from the original specification and rebuilt at 2× pixel scale.
> Every value in this document is arithmetic, not taste. When something looks wrong,
> check the derivation before changing the number.

**Created:** 2026-08-03

-----

## 1. The Pixel Unit

The entire system is expressed in a single token.

```
pixel = 2pt   (default, "2×")
```

Windows 95 was designed for 1:1 physical pixels. On a retina iPhone, a true 1px bevel is a near-invisible hairline. Everything is therefore rendered at **2× scale**: one 1995 pixel becomes 2 points. Every dimension below is written as `Npx` (the original spec value) with its point value derived.

The pixel unit is **variable** — it is the mechanism for accessibility scaling (§7). Nothing in the app may hard-code a point value; everything multiplies `pixel`.

| Scale | `pixel` | Trigger |
|---|---|---|
| 2× | 2pt | default |
| 3× | 3pt | system text size ≥ large |
| 4× | 4pt | accessibility text sizes |

**Appearance follows a global setting (revised 2026-08-14).** This section previously read "appearance is locked to light — Windows 95 has no dark mode and a dark bevel system is a different design, not a variant." That reasoning still holds historically, but the app now ships Light / Dark / System as one global `AppearanceMode` shared by both design modes, so the lock is gone: the root sets `.preferredColorScheme(settings.appearance.preferred)`, which returns `nil` for System so the device setting is honoured.

The dark palettes are an **invention**, not a restoration — Windows 95 had none. They are built to the same STRUCTURE rather than to authenticity, and the rules that survive are recorded in `Win95Scheme.swift`:

- `highlight` / `light` / `shadow` / `darkShadow` keep their ORDER, so a raised bevel still reads raised. Inverting the ramp would flip every control into looking pressed.
- `well` stays the lightest-relative surface of its scheme — it is the paper the list is written on.
- `important` is untouched (it is not part of the scheme at all): red carries exactly one meaning in every palette and every mode.
- Title bars keep their hue and lose brightness, so a scheme is still recognisably itself in the dark.

Two consequences worth naming, both found as bugs on 2026-08-14:

- `titleA` is deliberately darkened for dark-mode title bars, which makes it too low-contrast for a small standalone glyph. `Win95.accent` therefore resolves to the brighter `titleB` stop, lightened further, when the scheme is dark.
- Text sitting ON the title gradient must use `selectionText`, never `highlight`. `highlight` is a bevel-edge colour — near-white in the light schemes by coincidence, mid-grey in the dark ones.

-----

## 2. Palette

Six colours carry the entire interface. There are no others.

| Token | Hex | Use |
|---|---|---|
| `surface` | `#C0C0C0` | Every chrome surface — taskbar, title bar area, window body, buttons |
| `highlight` | `#FFFFFF` | Bevel outer top-left (raised); also the list well background |
| `light` | `#DFDFDF` | Bevel inner top-left (raised) |
| `shadow` | `#808080` | Bevel inner bottom-right (raised); secondary/disabled text |
| `darkShadow` | `#0A0A0A` | Bevel outer bottom-right (raised) |
| `text` | `#222222` | All primary text |

**Accents — used for exactly one meaning each:**

| Token | Hex | Meaning — and nothing else |
|---|---|---|
| `important` | `#FF0000` | A task marked Important. No other element in the app is red. |
| `titleActive` | `#000080` → `#1084D0` | Active title bar, 90° linear gradient |
| `titleInactive` | `#808080` → `#B5B5B5` | Inactive title bar (Mac only — iOS windows are always active) |
| `selection` | `#000080` bg / `#FFFFFF` text | A row being dragged or swiped |
| `desktop` | `#008080` | Teal desktop — **macOS only**, not used on iOS |

No other colour may be introduced. Overdue, completed, and dragging states are all expressed through channels other than hue (§5).

-----

## 3. The Bevel

The bevel is the entire visual language. It is always exactly 2 pixels (4pt at 2×), built as two nested 1px frames.

**Raised** — buttons, taskbar, window body, thumbnail frames:

```
outer top-left     highlight   #FFFFFF
inner top-left     light       #DFDFDF
inner bottom-right shadow      #808080
outer bottom-right darkShadow  #0A0A0A
```

**Even** *(list well only, 2026-08-04)* — the big white task well uses the same two nested frames with the SAME colours on all four sides: outer `#808080`, inner `#0A0A0A`, no lit edge. At that size the lit bottom-right of a true bevel stopped reading as depth and just looked like an uneven border. Small controls keep the real bevel — at chip and button size the lighting is what makes them look pressable.

**Sunken** — text fields, status bar panels, date chips, pressed buttons:

```
outer top-left     shadow      #808080
inner top-left     darkShadow  #0A0A0A
inner bottom-right light       #DFDFDF
outer bottom-right highlight   #FFFFFF
```

Sunken is the exact inversion of raised. A pressed button is simply a raised button rendered sunken, with its label shifted 1px (2pt) down and right.

**Absolute rules:** corner radius is always `0`. There are no drop shadows, no blur, no translucency, no gradients anywhere except the title bar. Focus, where shown, is a 1px dotted `#000000` rectangle inset 4px from the content edge.

-----

## 4. Metrics

All derived from the 1995 spec. Point values shown at 2×.

| Element | Spec | @2× | Notes |
|---|---|---|---|
| Bevel | 2px | 4pt | Two 1px frames |
| Grid unit | 4px | 8pt | All spacing is a multiple: 2/4/8/16/24px → 4/8/16/32/48pt |
| Standard button | 75×23px | 150×46pt | Minimum size |
| Checkbox | 12×12px | 24×24pt | Tap target extended invisibly to 44pt |
| Title bar | 18px tall | 36pt | Gear (or ✕ on Settings) at the trailing edge |
| Title bar control | 16×14px | 32×28pt | Raised bevel, pixel glyph |
| Taskbar | 32px tall | 64pt | Extends into the home-indicator safe area. The bar spans edge to edge; buttons are inset one grid unit so they don't run into the bezel, and 4px of the height sits ABOVE them as breathing room — the panel grew, the buttons did not |
| Status panel | 12px tall | 24pt | Floats above the taskbar; only present after an action |
| Scrollbar | 16px wide | 32pt | Hidden on iOS; relevant for macOS |
| List row | — | **44pt min** | Spec rows are 14px/28pt — too small for a thumb. Deliberate deviation. |
| Photo thumbnail | 32×32px | 64×64pt | Sunken bevel frame |
| Row with photo | — | ~120pt | Text row + thumbnail + spacing |

**The one deliberate deviation from the spec** is row height: Windows 95 list rows were built for a mouse cursor. 44pt is Apple's minimum touch target and overrides authenticity. Checkboxes keep their authentic 24pt *visual* size with an extended invisible tap area — the look is period-correct, the target is not.

-----

## 5. Components

### Window (each tab)

A maximized Windows 95 window filling the screen.

```
┌─────────────────────────────────────────┐
│ Today - shove.95                    [⚙] │  title bar, 36pt, navy gradient
├─────────────────────────────────────────┤
│ ┌─────────────────────────────────────┐ │
│ │  ☑  Repair bike            [ Mon ]  │ │  sunken white list well
│ │  ☐  Call dentist                    │ │
│ │  ☐  Build portfolio                 │ │
│ │     ┌────────┐                      │ │
│ │     │ photo  │                      │ │  64pt thumbnail, sunken frame
│ │     └────────┘                      │ │
│ │  ☑  B̶u̶y̶ ̶m̶i̶l̶k̶                        │ │
│ │  ─────────────────────────────────  │ │
│ │  [ + new task                     ] │ │  permanent add row
│ └─────────────────────────────────────┘ │
├─────────────────────────────────────────┤
│ Repair bike → Tomorrow         [ Undo ] │  status bar, 24pt, sunken
├─────────────────────────────────────────┤
│ [Today] [Tomorrow] [Week] [General] │12:04│ taskbar, 56pt
└─────────────────────────────────────────┘
```

**Title bar** — 36pt, `#000080 → #1084D0` gradient, white W95FA text reading `{Tab} - shove.95`, left-aligned with 4px (8pt) padding. One title-bar control at the trailing edge: a 32×28pt raised button containing a custom pixel gear glyph, opening Settings. Microsoft's own control glyphs are **not** used.

**List well** — sunken bevel, `#FFFFFF` background, edge to edge. No row separators (Windows 95 list boxes have none).

**Status panel** *(revised 2026-08-04)* — a light panel (`statusBG`, raised bevel) carrying `#222222` text reading `{task} → {destination}`, with a flat `statusAccent` `Undo` block at the trailing edge. **No bevel on the Undo block** — it is a tint, not a button.

It is **not window furniture**. It is absent until an action occurs, floats *over* the list well rather than taking layout space (so rows never shift when it appears), and retires itself after 6 seconds. Any further action restarts that clock. Undo remains single-level and reachable for as long as the panel is up.

Originally this was a permanent silver status bar inset into the window chrome. The founder rejected that on device: standing chrome that is empty most of the time reads as broken, and greying out an always-present Undo advertises a control you cannot use.

**Taskbar** — 56pt, raised, `#C0C0C0`, extending into the safe area with buttons positioned above the home indicator. Four text-only buttons (`Today` `Tomorrow` `Week` `General`) sharing the width. The active tab renders **pressed** (sunken bevel, label offset 1px down-right, dotted-hatch fill). A sunken clock well at the trailing edge shows the current date/time.

### Task row

- **Checkbox** — 24pt sunken white box with a black pixel checkmark when ticked; 44pt tap target.
- **Text** — W95FA, one size, one weight, `#222222`, left aligned, truncating with `…` before the chip.
- **Important** — text in `#FF0000`. Colour only; no weight or size change.
- **Overdue** — a trailing-edge sunken mini-well (a miniature status-bar panel) containing the date in `#808080`: `Mon`, `2d`. Chips align in a fixed right-hand column so they can be scanned vertically. Row text stays `#222222`, undimmed.
- **Completed** — strikethrough **and** text to `#808080`. Both, because strikethrough alone on a pixel font at small size is easy to miss.
- **Dragging / swiping** — the entire row inverts to `#000080` background with `#FFFFFF` text, the Windows 95 list selection state.
- **Photo** — 64×64pt thumbnail beneath the text, inset to align with the **text**, not the checkbox, in a sunken bevel frame.

### Add row

A permanent row at the bottom of the list, visually a sunken text field. Tapping focuses it; return commits the task and **keeps focus** for consecutive entry. A small camera glyph at the trailing edge attaches a photo.

### Photo viewer

A Windows 95 window, near-full-screen, centred: navy gradient title bar, a close (`✕`) control drawn as a pixel glyph, the image in a sunken frame. **Appears instantly, closes instantly** — tapping anywhere outside dismisses it. Not draggable, not resizable.

### Empty state

`(empty)` centred in the list well, `#808080`.

-----

## 6. Typography

**Typeface is switchable** *(2026-08-04)*. W95FA is the default and the point
of the app, but a bitmap-derived face is genuinely hard for some people to
read, and legibility outranks costume — so Settings offers the system face,
applied to EVERYTHING including chrome, and synced with the colour scheme.
The system face renders at 0.82× the nominal size: W95FA's glyphs fill their
em box, so matching point sizes makes the system face look oversized in the
same layout.

**W95FA** — an OpenType recreation of the MS Sans Serif bitmap, licensed **SIL OFL**, which explicitly permits embedding and redistribution inside a commercial application. It is the only typeface in the app: title bar, taskbar, task text, status bar, settings.

| Role | Spec | @2× |
|---|---|---|
| All text | 11px | 22pt |

One size, one weight, everywhere — as specified. Antialiasing is minimised (`.font(.custom(...))` with no dynamic optical adjustments); the font only renders correctly at whole multiples of its design size, which is why scaling is stepped rather than continuous (§7).

**Do not ship** the `Pixelated MS Sans Serif` webfont from 98.css — it is derived directly from Microsoft bitmaps and its licensing is unclear. W95FA is the clean choice.

-----

## 7. Accessibility Scaling

Dynamic Type is supported in **whole-pixel steps**, not continuously. The system text-size setting maps to the `pixel` token:

| System setting | `pixel` | Text size | Bevel | Grid |
|---|---|---|---|---|
| default | 2pt | 22pt | 4pt | 8pt |
| large | 3pt | 33pt | 6pt | 12pt |
| accessibility sizes | 4pt | 44pt | 8pt | 16pt |

The **entire interface** scales as one unit — text, bevels, controls, spacing — exactly like changing display resolution on a CRT. Because every step is an integer multiple, the pixel font stays crisp at all three.

Layouts must be verified at 4×, where fewer rows are visible and taskbar labels may need abbreviation.

**Other accessibility requirements:** all four taskbar buttons, the checkbox, the context menu and the swipe must carry VoiceOver labels and actions. Because the swipe is custom rather than `.swipeActions`, move actions must be exposed explicitly as VoiceOver custom actions — otherwise the app's primary gesture is unreachable without sight. Colour is never the sole carrier of meaning: Important is red *and* placed in the top tier; overdue is a chip, not a tint.

-----

## 8. Motion

> **Motion describes position, never appearance.**
> Anything that moves, moves continuously. Anything that appears or disappears does so instantly.

This governs every animation in the app. Windows 95 had no fades, scales, or dissolves — but it dragged continuously.

**Amendment, 2026-08-04.** The founder's read of the whole product: *"a very static vintage UI, but very responsive with smooth animations."* The frame is 1995; the response is 2026. So the rule above holds for everything **inside** the frame — chrome, labels, bevels, the photo viewer — while two things now carry modern motion, because their job is to answer a gesture rather than to redraw a surface:

- **The long-press menu springs in** (0.26s, bounce 0.38) scaled from its row anchor, the way iOS answers a long press. It leaves flat and fast (0.11s ease-out) — a bouncy dismissal reads as hesitation.
- **Tab changes slide** the list contents in from the side the tab lives on. Everything else holds still.

What did *not* change: appearance is still instant. The title text swaps with no crossfade, the taskbar highlight flips immediately, and the colour scheme repaints with animations explicitly disabled.

| Event | Behaviour |
|---|---|
| Swipe to move | The row **slides off the screen edge** in the swipe direction; rows below close the gap. Commits at **22% of the row width (≈86pt) or 350pt/s** — deliberately forgiving, because moving a task between days is the one thing this app exists to make cheap. The original 40%/800 meant a swipe had to cross most of the screen. |
| Swipe at a dead end | Rubber-band resistance, spring back, light haptic |
| Wrapped task row | Checkbox, chip and photo-plus stay on the FIRST line; extra lines flow underneath. The text is padded by half the slack between one line and the 44pt band — padding rather than centring, so line one lands identically whether the row is one line or four |
| Photo, zoom & text | Pinch or double-tap to zoom (double-tap targets the point you hit, not the centre); Live Text selects, copies, translates and looks up writing in the photo, via VisionKit — the same engine Photos uses. Deliberately NOT skinned: the costume stops at the window frame, because selection handles and the lookup menu are OS furniture people already know. |
| Photo viewer | A floating Win95 window at ~3/4 of the screen that HUGS the image — title bar with ✕, image inside the frame, app dimmed behind. Only the ✕ or the dimmed background closes it; tapping the image does nothing. |
| Overdue chip | Solid rectangle filled with the theme's status tint, date in black — no bevel, no outline. Editing an overdue task's text re-dates it to today and the chip disappears (a rewritten task is a new task). |
| Photos | Multiple per task, added ONE per edit session — the theme-coloured plus retires after a pick and returns on the next edit. Thumbnails accumulate left→right in the order added. |
| Return in any text field | **Commits and dismisses the keyboard.** It never inserts a line break — rows gain lines only by wrapping as the text grows. A vertical-axis `TextField` inserts a newline instead of firing `onSubmit`, so the newline is intercepted in the BINDING and the focus change is deferred a runloop turn; stripping it in `onChange`, or resigning focus inline, both lose to the field's own editing state and the newline survives. |
| Field opens under the keyboard | The list scrolls it to sit just above the keyboard (0.25s ease-out). A field already clear of the keyboard does NOT move — being yanked is as disorienting as being hidden |
| Scroll past either end | Rubber-band bounce — `.scrollBounceBehavior(.always)`, so it gives even when the list is shorter than the well |
| Launch | If the first frame hasn't arrived within 220ms, the wordmark appears on the icon's blue and is held ~600ms so it can't flicker. A warm launch never shows it: a splash that always appears makes a fast launch feel slower. |
| Photo viewer open | Thumbnail presses in (0.92 scale, ~140ms) so the press is SEEN, then the window appears with no transition (revised 2026-08-04) |
| Photo viewer close | **Instant.** No transition. |
| Long-press menu open | **Springs** from the row's bottom-left anchor — scale 0.86 → 1 + fade, 0.26s, bounce 0.38 |
| Long-press menu close | Flat 0.11s ease-out, scaling back toward the anchor |
| Row acted on | Tints to `light` whenever it is the thing being acted on — held (with 0.97 scale), menu open, **mid-swipe**, or **in edit mode** (unified 2026-08-04). The tint outlives the finger while the menu is open |
| Tab change | Contents **slide in from the side the tab lives on** (0.22s ease-out). The sunken well, title bar and taskbar never move — the frame is fixed and the content travels through it. Title text and taskbar highlight swap instantly. |
| Button press | **Instant** bevel inversion |

**All motion is snapped to the pixel grid.** Moving elements travel in whole `pixel` increments (2pt at default scale) rather than at sub-pixel smoothness — smooth but quantised, like a sprite. This preserves the retro texture during movement instead of the illusion breaking the moment anything moves.

**Haptics:** light impact on swipe commit and on rubber-band; selection feedback on drag pickup and drop.

-----

## 9. Prohibited

Things that would break the system, listed so they don't get reintroduced by habit:

- Corner radii, drop shadows, blur, translucency, SF Symbols, system tint colours
- Any gradient other than the title bar
- Any red that isn't Important
- Continuous (non-stepped) Dynamic Type
- Microsoft's icon artwork, the Windows logo, the Start button, or the word "Windows" in any user-facing string

("Dark mode" was on this prohibited list until 2026-08-14. It now ships — see §1 for the structural rules it has to obey. The prohibition on *inverting the bevel ramp* is what actually mattered, and that still stands.)

**Transitions came off this list on 2026-08-16.** It read "Fade, scale,
dissolve, or cross-fade transitions of any kind", and it was wrong about what
this design is. The vintage lives in the SURFACES — the bevel ramp, the pixel
grid, the two-tone chrome, the absence of a radius. It was never supposed to
live in the movement. A 1995 machine drew a menu in one frame because it could
not afford to draw it in twelve, not because instant was the intent; holding
the app to that limit costs the feel and buys nothing back.

So: **animate freely, in both looks.** Motion is a shared modern layer over
two different surface treatments, not a third thing the looks disagree about.
The constraints that remain are the ones about substance, not speed — a
transition may not introduce a radius, a blur, a translucency or a system tint
that the static design forbids, and position still lands on the pixel grid so
nothing comes to rest half a pixel off.


---

## 12. Colour schemes *(added 2026-08-04)*

Windows 95 shipped named Appearance schemes and swapping them was one of the era's
small pleasures, so the theme picker is period-correct rather than a modern bolt-on.
Five schemes ship: **Windows Standard**, **Desert**, **Eggplant**, **Rose**, **Slate**
(`Win95Scheme.swift`). They are picked from a **single row of window miniatures** —
title bar over body over well — with the selected one drawn pressed (sunken bevel,
nudged one pixel down and right) and named beneath the row. Five stacked rows with
checkboxes was a wall of chrome for one choice; the Win95 Appearance tab showed you
the scheme rather than naming it. Each supplies the full token set — surface, highlight, light,
shadow, darkShadow, text, the two title-bar gradient stops, selection pair, the list
well, and the status-panel pair.

Two rules hold across every scheme:

1. **Bevel structure never changes.** Only the palette moves; the two nested 1px
   frames stay exactly as §3 specifies. A scheme cannot introduce a radius or a shadow.
2. **`important` stays `#FF0000` in every scheme.** Colour carries exactly one meaning
   (§2). Remapping red to fit a palette would break that, so `Win95.important` is the
   one hard-coded `static let` in the theme.

Palettes are read through static accessors (`Win95.surface` etc.), so the chrome
subtree is rebuilt via `.id(scheme.id)` when the scheme changes. That `.id` sits
**inside** the presentation modifiers in `RootView` — rebuilding above them tears down
`showSettings` and slams the Settings window shut on every pick.

**Static accessors are invisible to SwiftUI.** A view whose own inputs haven't
changed is never re-rendered, so it keeps painting the previous palette. `TitleBar`
hit this exactly: its inputs (title, isClose, closure) don't move when the scheme
does, so inside the Settings cover — which sits outside the `.id` rebuild — the
window's own title bar stayed on the old colours while everything around it
repainted. The fix is the `\.win95Scheme` environment value: views that must repaint
on a scheme change read it and paint **from it** rather than from the statics. Any
new chrome that survives a scheme change unchanged needs the same treatment.

### Tab renaming

All four tabs are renamable (`AppSettings`, UserDefaults-backed). Renaming changes the
**label only** — `Bucket` semantics are date-derived and untouched, so a tab called
"Heute" still means today. An empty field restores the built-in name. At 4× the custom
name truncates to three characters, matching the built-in abbreviations.


---

## 13. The row's gesture budget *(added 2026-08-04)*

**A task row may attach exactly ONE `DragGesture` with `minimumDistance > 0`, and
its press must NOT be a SwiftUI construct at all.** This is not a style preference — it is the constraint that
makes a scrollable list with per-row gestures possible at all.

A `DragGesture(minimumDistance: 0)` claims the touch the instant the finger lands,
and the enclosing `ScrollView` never sees the pan. The list simply stops scrolling.
Two separate additions each did this independently: the reorder, built as
`LongPressGesture.sequenced(before: DragGesture(minimumDistance: 0))`, and a press
tint built on its own zero-distance drag. Bisected on device — with only the swipe
gesture attached the list scrolls; adding either of those back stops it dead.

The arrangement that works:

| Need | Mechanism |
|---|---|
| Press tint, tap, hold | `RowTouchHandler` — a `UIViewRepresentable` whose `UIView` overrides `touchesBegan/Moved/Ended/Cancelled` |
| Swipe *and* reorder | One `DragGesture(minimumDistance: 12)`; once the press has armed the row, the same pan drives the reorder instead of the swipe |

**Second round, 2026-08-04.** The `LongPressGesture` above was itself wrong: a
*slow* vertical pan starting on a row still died, while the same drag on empty
well space scrolled. Everything gesture-shaped failed, each bisected on device:

| Attempt | Result |
|---|---|
| `LongPressGesture` (any duration/distance) | slow pans die on rows |
| `DragGesture(minimumDistance: 0)` | list never scrolls at all |
| UIKit recognizers via `UIGestureRecognizerRepresentable` | same stall — SwiftUI replaces the recognizer's delegate, so "recognize simultaneously" never reaches the scroll view's pan |
| `Button` wrapper + simultaneous pan | starves the button entirely; not even the nested checkbox fired |

**Round three.** Even a lone `DragGesture(minimumDistance: 12)` had to go: it
claims the touch the moment the finger passes 12pt, and although the axis logic
then decides "vertical, not mine", the pan is already taken and the scroll view
never gets it. Fast flicks worked only because `UIScrollView`'s own recognizer
won the race first — which is exactly the reported symptom, *flick scrolls,
slow drag is dead*. **The row now has no SwiftUI gesture at all**: swipe and
reorder ride the same UIView touches as press/tap/hold, and UIKit arbitrates as
it always has (a vertical pan starts the scroll view, which cancels our touches
and aborts the swipe; a horizontal pan never triggers the vertical scroll view,
so the swipe runs).

Three traps inside that catcher, each of which silently broke one interaction:

| Trap | Symptom | Fix |
|---|---|---|
| `UIScrollView.delaysContentTouches` holds touches ~150ms | A quick swipe is over before delivery; the row measures almost nothing | Walk up to the enclosing scroll view and set `delaysContentTouches = false` — on every `touchesBegan`, not just on attach, because the scroll view isn't in the ancestor chain yet at `didMoveToWindow` |
| `touch.location(in: self)` on a view that MOVES with the drag | Measured distance is **half** the finger's travel, so the commit threshold is never reached | Measure in **window** space |
| Synthesised touches can share timestamps | Per-segment velocity stays 0, so flick-to-commit never fires | Fall back to the gesture's average velocity |

What works underneath is the layer UIKit built for it: **a plain `UIView`'s touch
methods**. `UIScrollView` delays content touches and then *cancels* them the
moment it begins panning, so the scroll always wins, a stationary finger sails
through, and `touchesBegan/Ended/Cancelled` yield touch-down, tap and hold. The
catcher goes in the row's `.background` — above the colour fill, below the
content, so the checkbox and edit field keep their own touches — and the HStack
must carry **no `contentShape`**, which would swallow everything first.

One more trap sits behind this. The `ScrollView` wins **every** vertical pan, so
even a correctly-configured row drag never sees one and the reorder never starts.
The list therefore sets `.scrollDisabled` the moment a row is armed — which is why
`ReorderCoordinator` exposes "armed" as state the list can read, separately from
"currently dragging".

And `.zIndex` only orders a stack's **own** children: applied inside the row's body
it is ignored, so a row dragged downward slides underneath every row it passes. It
belongs on the `ForEach` child in `TaskListView`.


---

## 14. Press feedback is universal *(added 2026-08-04)*

**Every control that opens, expands, or changes something animates on press.**
Founder direction: the app should feel responsive even though the surface is
static. This is not a per-control decision — it is the default, and a new
control without it is a bug.

| Control | Press behaviour |
|---|---|
| `Win95Button` (and Settings' Default / Delete / Add) | Bevel inverts, label nudges one pixel down-right — `Win95ButtonStyle` |
| Title-bar gear / ✕ | Same inversion — `TitleBarControlStyle` |
| Workspace label | Scales to 0.92 for as long as the dropdown is open, springs back on close |
| Task row | Tints to `light` and scales to 0.97; the tint outlives the finger while its menu is open |
| Taskbar tab | Renders pressed while active: sunken bevel + a LIGHTER grey (`light`), flat — the authentic hatch read as noise at phone size |
| Scheme swatch | Selected renders pressed |

The press itself is instant where a real Win95 control would be (bevel flips
don't tween); the *scale* is what carries the modern responsiveness. Build press
feedback on `ButtonStyle`, never on a `DragGesture(minimumDistance: 0)` — that
form is banned by §13 and freezes any scroll view it lands in.

---

## 15. Workspaces *(added 2026-08-04)*

Multiple named containers — **Personal** and **Work** ship by default. The
workspace is the window's identity, so it sits where a Win95 title sits: the
title bar reads `{Workspace} ▼` at the leading edge and the day name at the
trailing edge, and tapping the workspace drops a menu from it.

- `TaskItem.workspaceID` is `String?`; **nil means the default workspace**, so
  every task written before workspaces existed belongs to Personal with no
  migration.
- Scoping happens in **one** place — `TaskStore.allTasksSorted()`, the choke
  point every query already funnels through — so buckets, archive, placement
  and day-rollover are all scoped for free.
- The default workspace is renamable but **not deletable**. Deleting any other
  reassigns its tasks back to the default: deleting a label must never delete
  work.


---

## 16. Row interaction contract *(rebuilt from scratch 2026-08-04)*

The single source of truth for how a task row behaves. Code that disagrees
with this table is wrong, not the table.

| Input | Behaviour |
|---|---|
| **Tap** (anywhere on the row except the checkbox) | Routed by region: a thumbnail opens the photo viewer, anything else starts an inline edit: TextField with the title, keyboard up, caret in. Blocked on completed rows and during a reorder. |
| **Tap checkbox** | Toggle complete. Row travels to/from the completed block (0.35s spring). Untick restores the exact former position. |
| **Press** (finger down ~0.12s, still) | Row tints `light` and scales to 0.97 — the iOS press-in feel. NO tint for scroll-intent touches: the 0.12s delay means a moving finger never flashes the row. |
| **Hold 0.4s** (within 10pt) | Win95 menu springs in (0.26s, bounce 0.38) just below the row — or ABOVE it when there isn't room below, so the last item is always reachable. Height is CALCULATED from the item table, never measured: a PreferenceKey reports zero on the first layout pass, which is the pass the decision is made on — the task it acts on stays visible; light haptic; the tint HOLDS while the menu is open. Movement after the hold does nothing. |
| ~~Hold, then drag vertically~~ | **Reorder removed 2026-08-04** (founder call: too many gestures interfering with each other). Order within a bucket is placement-driven only. |
| **Horizontal drag** | Swipe: content follows the finger (pixel-snapped), and the axis LOCKS — once a pan is a swipe the touch is ours for the rest of the gesture, so vertical drift can't hand it back to the scroll view. Purely horizontal motion: the row never moves vertically. Right = defer, left = pull forward. Commits at **half the runway the finger actually had** (distance from the touch's start to the screen edge), capped at 22% of the row width — or 300pt/s. Runway-scaled because a swipe starting right of centre physically cannot travel 86pt before the edge; a fixed bar made off-text swipes on short rows bounce forever. Commit slides off the edge (0.15s), then the list closes the gap. Below threshold: spring back (0.3s). |
| **Horizontal drag at a dead end** | Rubber-band at 0.3 resistance + one light haptic. Today has no left step; General has no right step; completed rows never move. |
| **Vertical drag** | Scrolling, ALWAYS — slow or fast, starting on a row or on empty well. The row surrenders the touch; the scroll view cancels it. Bounce at both ends even when the list is short. |
| **Return while editing** | Commits and dismisses the keyboard. Never inserts a line — rows gain lines only by wrapping. |
| **Edit under the keyboard** | The list lifts the field to sit just above the keyboard; a field already clear does not move. |

### Why the touch layer is UIKit, not SwiftUI

Every SwiftUI construct was tried and failed on device (§13): gestures starve
the scroll view or get starved by it. The row therefore attaches **no SwiftUI
gesture at all**. One `UIView` in the row's background owns a five-phase state
machine — `pending → tap / held / swiping / reordering / surrendered` — and
UIKit arbitrates against the scroll view natively.

Standing traps, all bisected on device; violating any of them silently breaks
one interaction:

0. `canCancelContentTouches` must be turned OFF for the duration of a
   recognised swipe and restored on every exit path — no finger draws a
   straight line, and without the lock the scroll view cancels a diagonal
   swipe halfway through.
1. `delaysContentTouches` must be OFF (set from `touchesBegan`, the scroll view
   isn't in the ancestor chain at attach time) or quick swipes lose their first
   150ms and never reach the commit threshold.
2. Touches must be measured in **window** space — the row moves with the drag,
   so self-relative coordinates read half the real distance.
3. Synthesised touches can share timestamps → zero per-segment velocity → fall
   back to whole-gesture average.
4. The content HStack must carry **no `contentShape`**, or it swallows every
   touch before the catcher sees one. The checkbox and TextField keep their own
   touches by sitting above the catcher.
5. (Historical) `.zIndex` for a lifted row must be applied by the ForEach in
   the list, not inside the row's body — kept for the record although
   drag-reorder itself was removed 2026-08-04.


---

## 17. App icon *(2026-08-04)*

`sho>` — "sho" in a sans-serif mono, then a large **pixel chevron** for the
missing "v", white on a deep saturated blue (`#0C2EBE`).

The blue is NOT the title-bar azure it started as. At icon size that lighter
stop washed out against a bright home screen; the deeper tone holds the white
and still reads as the same family. A solid triangle was tried and rejected —
the open chevron is lighter and unmistakably an arrow at 40pt, where a filled
triangle reads as a play button.

The chevron is the whole idea: it is the app's verb. Tasks are shoved forward
along the line — Today → Tomorrow → Week → General — and the icon is that
motion. Drawn as square blocks on a grid, two blocks thick, one step per row,
so it belongs to the same pixel family as every glyph in the interface rather
than being a smooth arrow pasted on top.

Type is deliberately NOT W95FA. The interface is a 1995 costume; the icon is
the product's signature and reads at 40pt, where a bitmap face turns to mush.
Verified down to 40×40.

One 1024×1024 source fills the light iOS slot; the dark and tinted slots are
left empty so iOS derives them, keeping a single source of truth. The mac
slots stay empty — filling them with a 1024 triggers a size warning per slot.
