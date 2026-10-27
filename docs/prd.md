# PRD — shove.95

> Technical blueprint for coding agents. Read alongside `docs/design.md` (visual tokens — authoritative for every color, metric, and motion rule) and `docs/product-vision.md` (strategy). Where this document says "per design.md", the value there wins.

## 1. Overview

### Product Summary

**shove.95** — a to-do app with four time buckets where moving a task between days takes one swipe, wrapped in a pixel-faithful Windows 95 interface.

Tasks carry a real date (or none). The four tabs — Today, Tomorrow, Week, General — are *filters over that date*, never storage, so the app is always correct with zero rollover code. Swiping a row moves it one step along the line `Today → Tomorrow → Week → General`; a long-press context menu covers the longer jumps. The entire interface is Windows 95 rebuilt at 2× pixel scale.

### Objective

This PRD covers the v1 iOS MVP defined in `product-vision.md` § MVP Definition: the four date-derived tabs, the full gesture set (swipe-move, context menu, drag-reorder, inline add/edit), completion + archive, one photo per task, the complete Win95 visual system with stepped Dynamic Type, SwiftData + CloudKit sync, and a Settings screen (Archive, sync status, About). macOS is explicitly out of scope for v1 but shapes the architecture (shared logic package).

### Market Differentiation

The technical implementation must deliver two things to earn the product's positioning: **(1) a one-second, one-handed defer** — the swipe path must never route through a detail view, date picker, or confirmation, and must commit in a single gesture with the status bar as the only confirmation; **(2) a Win95 rendering that survives scrutiny** — every metric derived from the spec in `design.md`, no stock iOS chrome visible anywhere, and motion that is smooth but pixel-snapped.

### Magic Moment

Flicking a task from Today to Tomorrow with a thumb: swipe right → row slides off the screen edge → rows close the gap → status bar reads `Repair bike → Tomorrow` with an Undo button. Requirements this places on the implementation: gesture recognition must coexist with vertical scrolling without dead zones; commit must be instant (no spring-back-then-commit); the date write + placement must be synchronous so the destination tab is already correct if tapped immediately.

### Success Criteria

- Defer gesture completes (touch-down → row gone → status bar updated) in < 1s including animation
- App opens to a correct Today list after 3+ days unopened, offline, or across a timezone change — with no migration or rollover step
- A task created on one device appears on a second device signed into the same Apple Account without user action
- All P0 functional requirements pass their acceptance criteria; date/bucket logic covered by unit tests
- App Store approval

-----

## 2. Technical Architecture

### Architecture Overview

```mermaid
flowchart TD
    subgraph iPhone["iOS App (Shove95)"]
        V[SwiftUI Views\nWin95 component library] --> S[TaskStore\n@Observable façade]
        S --> E[Shove95Kit\nDateEngine · Placement · Buckets\npure functions, unit-tested]
        S --> DB[(SwiftData\nModelContainer)]
    end
    DB <-->|automatic sync| CK[(CloudKit\nprivate database\niCloud.com.lucasmaher.shove95)]
    CK <--> Mac[Future macOS app\nsame Shove95Kit + data]
```

No server, no accounts, no third-party services. All logic runs on-device; CloudKit mirrors the SwiftData store silently.

### Chosen Stack

| Layer | Choice | Rationale |
|---|---|---|
| Frontend | SwiftUI (iOS 26 SDK, Swift 6.3, Xcode 26.6) | Native, first-party, best fit for heavy custom gesture work; view code reusable for macOS |
| Backend | None | Entirely on-device; CloudKit provides sync with no server |
| Database | SwiftData + CloudKit (`.private` database) | Modern persistence, direct SwiftUI integration, cross-device sync via one entitlement |
| Auth | None | CloudKit uses the device's Apple Account silently; no login exists |
| Payments | None | Free app |
| Analytics | None | Private personal app; privacy policy commits to zero third parties |
| Email | None | No accounts, no notifications |
| Error tracking | None (v1) | Xcode Organizer crash reports via App Store Connect |

### Stack Integration Guide

**Setup order:**

1. Xcode project `Shove95` (iOS App, SwiftUI, Swift), bundle ID `com.lucasmaher.shove95`, deployment target iOS 26.0, display name `shove.95`. Default MainActor isolation (Xcode 26 template default) — keep it; this app has no background threading needs.
2. Local Swift package `Shove95Kit` inside the repo (`File → New → Package`, add to project). Contains: `TaskItem` model, `Bucket`, `DateEngine`, placement logic, chip formatting. **Rule: nothing in Shove95Kit imports SwiftUI or UIKit.** This is the macOS-reuse boundary.
3. W95FA font: download from FontsArena (OFL license — keep the license file in the repo at `Shove95/Resources/W95FA-LICENSE.txt`), add `w95fa.otf` to the app target, register under `UIAppFonts` in Info.plist. Verify with `UIFont.familyNames` dump on first run.
4. SwiftData: `ModelContainer(for: TaskItem.self)` — **local-only at first** (`cloudKitDatabase: .none`). The model is written CloudKit-compatible from day one (defaults on everything, no unique constraints), but sync is switched on in its own phase.
5. CloudKit (requires paid Apple Developer account — hard prerequisite): add iCloud capability → CloudKit → container `iCloud.com.lucasmaher.shove95`; add Background Modes → Remote notifications; change `ModelConfiguration(cloudKitDatabase: .private("iCloud.com.lucasmaher.shove95"))`.

**Known gotchas:**

- **Naming:** the model class is `TaskItem`, never `Task` — `Task` collides with Swift Concurrency.
- **CloudKit + SwiftData constraints** (must hold from the first model version): every stored property has a default value or is optional; no `#Unique`; no non-optional relationships. The model below complies. Changing the schema after sync is enabled requires additive-only migrations.
- **CloudKit does not run on a free team.** Build everything before the sync phase against the local configuration.
- **Dates:** store `dueDate` normalized to start-of-day in the current calendar. All comparisons go through `Calendar` (never raw `Date` arithmetic across days). The app defines week-end as **Sunday** explicitly (see DateEngine) rather than trusting locale `firstWeekday`.
- **Day rollover:** there is no timer. Recompute on `scenePhase == .active` and on `UIApplication.significantTimeChangeNotification` (fires at midnight, timezone changes, clock changes). The rollover placement pass (see § Data Model) runs at those moments.
- **List vs custom stack:** start with `List` + `ForEach` (`.onMove` gives long-press-drag reorder without edit mode, `.contextMenu` gives the menu, and the system disambiguates hold-vs-drag — this is how Reminders works). The custom horizontal swipe gesture must be attached per-row with `.gesture(...)` tuned to fail on vertical movement so scrolling wins. **If List's gesture system fights the horizontal swipe irrecoverably, the sanctioned fallback is `ScrollView` + `LazyVStack` with hand-rolled reorder** — decided in the Phase 2 spike, not later.
- **Row identity:** stable `id` (the model's `id`) everywhere; animations depend on it.

**Environment variables:** none. **Secrets:** none.

### Repository Structure

```
shove-95/
├── docs/                          # VISION, product-vision, prd, roadmap, design
├── Shove95.xcodeproj
├── Shove95/                       # app target
│   ├── Shove95App.swift           # @main, ModelContainer, pixel-scale environment
│   ├── Theme/
│   │   ├── Win95Theme.swift       # colors, pixel unit, metrics — values from docs/design.md
│   │   ├── BevelModifiers.swift   # raised/sunken bevel ViewModifiers
│   │   └── W95Font.swift          # font helper (11px × pixel scale)
│   ├── Components/                # Win95 primitives: Win95Window, TitleBar, Taskbar,
│   │   │                          # StatusBar, Win95Button, Win95Checkbox, SunkenWell, DateChip
│   ├── Screens/
│   │   ├── RootView.swift         # window chrome + tab switching + taskbar
│   │   ├── TaskListView.swift     # one tab's list: rows, add row, sections
│   │   ├── TaskRowView.swift      # checkbox, text, chip, thumbnail, gestures
│   │   ├── PhotoViewerView.swift  # Win95 window overlay
│   │   ├── SettingsView.swift
│   │   ├── ArchiveView.swift
│   │   └── AboutView.swift
│   ├── Store/
│   │   └── TaskStore.swift        # @Observable; queries + mutations + undo record
│   ├── Resources/                 # w95fa.otf, W95FA-LICENSE.txt, Assets.xcassets
│   └── Info.plist
├── Shove95Kit/                    # local SPM package — NO SwiftUI/UIKit imports
│   ├── Package.swift
│   ├── Sources/Shove95Kit/
│   │   ├── TaskItem.swift         # @Model
│   │   ├── Bucket.swift           # enum + line ordering + menu destinations
│   │   ├── DateEngine.swift       # pure date/filter/horizon functions
│   │   ├── Placement.swift        # sortOrder insertion rules + rollover pass
│   │   └── ChipFormat.swift       # overdue chip labels
│   └── Tests/Shove95KitTests/     # unit tests (Swift Testing)
└── privacy/
    └── index.md                   # privacy policy → GitHub Pages
```

### Infrastructure & Deployment

- **Distribution:** App Store via Xcode → Archive → App Store Connect. TestFlight on the founder's own device before submission.
- **CI/CD:** none for v1; local `xcodebuild test` for the Shove95Kit test suite.
- **Privacy policy hosting:** GitHub Pages from the repo (`privacy/`), URL entered in App Store Connect. Content: data stays in the user's private iCloud; the developer has no access; no analytics; no third parties.
- **App Store privacy questionnaire:** "Data Not Collected" (developer collects nothing; iCloud data is user-controlled).

### Security Considerations

- No credentials, tokens, or secrets exist in the app.
- All user data lives in the device's SwiftData store and the user's **private** CloudKit database — inaccessible to the developer by design.
- No network calls other than CloudKit's own sync. No input crosses a trust boundary; no injection surface.
- Photos are stored via `@Attribute(.externalStorage)` and never leave the private database.

### Cost Estimate

| Item | Cost |
|---|---|
| Apple Developer Program | $99 / year (hard prerequisite for CloudKit + App Store) |
| Servers, DB, analytics, email | $0 — none exist |
| CloudKit | $0 — user's own iCloud quota (a few MB of tasks + photos) |
| Privacy policy hosting | $0 — GitHub Pages |
| **Total** | **$99 / year** |

-----

## 3. Data Model

### Entity Definitions

One entity. CloudKit-compatible: every property defaulted or optional, no unique constraints, no relationships.

```swift
import SwiftData
import Foundation

@Model
public final class TaskItem {
    public var id: UUID = UUID()
    public var title: String = ""
    /// Start-of-day date this task is scheduled for. nil = General (dateless).
    public var dueDate: Date? = nil
    public var isImportant: Bool = false
    public var isCompleted: Bool = false
    /// Set when ticked; cleared when unticked. Drives archive visibility.
    public var completedAt: Date? = nil
    public var createdAt: Date = Date.now
    /// Global manual ordering. Placement rules assign it once; drags mutate it. Fractional (midpoint) inserts.
    public var sortOrder: Double = 0
    /// True once the day-rollover pass has positioned this task in Today's overdue block.
    /// Reset to false whenever dueDate changes. Prevents re-placing a task the user has dragged.
    public var overduePlaced: Bool = false
    /// One optional photo, downscaled on import (max 2048px long edge, JPEG q0.8).
    @Attribute(.externalStorage) public var photoData: Data? = nil

    public init() {}
}
```

**Derived state — computed, never stored** (all functions in `DateEngine`, parameterized by `now` and `Calendar` for testability):

| Concept | Definition |
|---|---|
| `startOfToday` | `calendar.startOfDay(for: now)` |
| Bucket of a task | `general` if `dueDate == nil`; `today` if `dueDate < startOfTomorrow` (includes all past dates → overdue rolls forward automatically); `tomorrow` if within tomorrow; `week` if `dueDate > endOfTomorrow && dueDate <= weekHorizon` |
| `weekHorizon(now)` | The Sunday that ends the current week **if it is after tomorrow**; otherwise the following Sunday. (Encodes the Sat/Sun rollover: on Fri the horizon is this Sunday; from Sat it is next Sunday.) Week-end is Sunday by definition, independent of locale. |
| Target date for a move | `today → startOfToday`, `tomorrow → startOfTomorrow`, `week → weekHorizon(now)`, `general → nil` |
| `isOverdue` | `!isCompleted && dueDate != nil && dueDate < startOfToday` |
| `isArchived` | dated task: `isCompleted && completedAt < startOfToday` (visible struck-through only on its completion day); General task: `isCompleted && now - completedAt >= 24h` |
| Visible in tab T | matches T's bucket filter && `!isArchived` |
| Chip label | overdue 1–6 days: weekday abbreviation of `dueDate` (`Mon`); ≥7 days: `Nd` (e.g. `12d`) |

**The line:** `today ↔ tomorrow ↔ week ↔ general`. **Swipe right = defer** (one step toward General); **swipe left = pull forward** (one step toward Today). Reversed from the original spec on device feedback 2026-08-04: the taskbar reads Today | Tomorrow | Week | General left-to-right, so the row must travel the same direction as the destination tab — content follows the finger. Ends rubber-band. Context menu shows only non-adjacent destinations: from Today `> Week`, `>> General`; from Tomorrow `> General`; from Week `< Today`; from General `< Tomorrow`, `<< Today` (arrow = direction of travel, count = distance).

### Relationships

None. Single-entity model, intentionally.

### Indexes

None needed at personal-app scale (hundreds of rows). All filtering is in-memory over a full fetch sorted by `sortOrder`; SwiftData `#Predicate` filtering per tab is an optional optimization, not a requirement.

### Placement rules (write-once ordering)

Ordering is **placement-on-event + free manual reorder**, never a live sort:

| Event | sortOrder assignment |
|---|---|
| Create via add row | `maxVisibleSortOrder(in: currentTab) + 1` (bottom of incomplete section) |
| Swipe/menu move arrives in tab | bottom of destination's incomplete section; **if `isImportant`**: midpoint after the destination's last important task (or top if none) |
| Flag Important | `minVisibleSortOrder(in: tab) - 1` (jumps to very top) |
| Unflag Important | no change (stays where it is, loses red) |
| Complete / untick | **no change** — completed section renders separately, so unticking returns the task to its exact prior position |
| Day rollover pass | for each task with `isOverdue && !overduePlaced` (ordered by dueDate, then sortOrder): insert after the important block and any already-placed overdue tasks, before normal tasks; set `overduePlaced = true`. Runs on app-active and significant-time-change. Never touches tasks the user has since dragged (flag already true). |
| Drag reorder | midpoint of neighbors' sortOrders; if gap < 1e-9, renormalize the tab's visible tasks to integers |
| Any dueDate change | `overduePlaced = false` |

Rendering order within a tab: incomplete tasks by `sortOrder` ascending, then completed (non-archived) tasks by `completedAt` ascending, struck through.

-----

## 4. API Specification

### API Design Philosophy

There is no network API — the app is local-first with CloudKit mirroring underneath SwiftData. This section specifies the **store façade** (`TaskStore`, `@Observable`) that views call. It is the only object that mutates the model context; views never touch `ModelContext` directly. Every mutation is synchronous on the main actor and immediately visible to all tabs.

### Store Operations

```swift
@Observable @MainActor
final class TaskStore {
    // ── Queries (computed from one fetch, filtered per DateEngine) ──
    func tasks(in bucket: Bucket) -> (active: [TaskItem], completed: [TaskItem])
    func archivedTasks() -> [Date: [TaskItem]]        // grouped by completion day, newest first
    var lastAction: LastAction?                       // drives the status bar

    // ── Mutations ──
    /// Creates in the given bucket with placement; empty/whitespace title → no-op.
    func addTask(title: String, in bucket: Bucket)
    func editTitle(_ task: TaskItem, to newTitle: String)   // empty result → delete? No: revert to old title
    /// One step along the line. Returns nil if at a dead end (caller rubber-bands).
    func step(_ task: TaskItem, direction: StepDirection) -> Bucket?
    /// Direct jump (context menu). Records undo, applies placement.
    func move(_ task: TaskItem, to bucket: Bucket)
    func toggleCompleted(_ task: TaskItem)            // sets/clears completedAt
    func toggleImportant(_ task: TaskItem)            // flag → jump-to-top placement
    func delete(_ task: TaskItem)                     // immediate; snapshot into lastAction for undo
    func reorder(_ task: TaskItem, betweenSortOrders a: Double?, and b: Double?)
    func attachPhoto(_ task: TaskItem, imageData: Data)     // downscales before storing
    func removePhoto(_ task: TaskItem)
    func undoLastAction()                             // restores move (date+order+flag) or resurrects delete
    func runDayRolloverPassIfNeeded()                 // called on scenePhase.active + time-change notification

    enum StepDirection { case deferOne   // toward General
                         case pullOne }  // toward Today
}

enum LastAction {
    case moved(taskID: UUID, title: String, to: Bucket,
               previousDueDate: Date?, previousSortOrder: Double, previousOverduePlaced: Bool)
    case deleted(snapshot: TaskSnapshot)              // full field copy incl. photoData
}
```

**Undo semantics:** single-level, persistent until the next undoable action replaces it (moves and deletes are undoable; completion is not — unticking *is* the undo). Undo of a move restores `dueDate`, `sortOrder`, and `overduePlaced` exactly. Undo of a delete re-inserts a new `TaskItem` with all fields from the snapshot (new UUID acceptable).

**Status bar text:** `"{title} → {Destination}"` for moves, `"{title} deleted"` for deletes, per the voice rules in `product-vision.md` (no exclamation marks, terse).

-----

## 5. User Stories

### Epic: Time buckets

**US-001: See an honest Today**
As Lucas, I want Today to show everything dated today *plus* everything overdue, so that nothing silently disappears.
- [ ] Given a task dated yesterday and unfinished, when I open the app today, then it appears in Today with a date chip reading yesterday's weekday
- [ ] Given the app was closed for 5 days, when I open it, then all five days' unfinished tasks appear in Today, no rollover step visible
- [ ] Edge: task completed yesterday, dated yesterday → appears in Archive, not Today

**US-002: A Week that flows toward me**
As Lucas, I want tasks parked in Week to surface in Tomorrow and then Today as their day approaches, so that future tasks walk toward me on their own.
- [ ] Given a task dated Sunday, when Saturday arrives, then it appears in Tomorrow (and no longer in Week)
- [ ] Given it is Friday, when I view Week, then it shows only Sunday-dated tasks
- [ ] Given it is Saturday or Sunday, when I view Week, then it shows next week's range and swipe-to-Week targets next Sunday

### Epic: Moving tasks (the wedge)

**US-003: One-flick defer**
As Lucas, I want to push a task one step away with a left swipe, so that updating my plan costs nothing.
- [ ] Given a task in Today, when I swipe it **right** past the commit threshold, then it slides off the edge, the list closes the gap, its date becomes tomorrow, and the status bar shows `{title} → Tomorrow` with Undo
- [ ] Given a task in General, when I swipe **right**, then the row rubber-bands with a light haptic and nothing changes
- [ ] Given I swipe but release before the threshold, then the row springs back and nothing changes
- [ ] Edge: swiping during an active scroll → scroll wins; no accidental move

**US-004: One-flick pull-forward**
As Lucas, I want to pull a task one step closer with a **left** swipe.
- [ ] Given a task in Week, left swipe → it moves to Tomorrow
- [ ] Given a task in Today, left swipe → rubber-band + haptic, no change

**US-005: Long jump via menu**
As Lucas, I want to send a task straight across the line, so that General → Today is not three swipes.
- [ ] Given a task in General, when I long-press without moving, then the iOS context menu opens showing `< Tomorrow`, `<< Today`, `Mark as Important`, `Delete` (red, last)
- [ ] Given a task in Tomorrow, the menu shows exactly one move entry: `> General`
- [ ] Tapping `<< Today` moves the task to Today with important/bottom placement and updates the status bar
- [ ] Edge: menu never shows destinations reachable in one swipe

**US-006: Undo from the status bar**
As Lucas, I want the last move or delete undoable until I act again.
- [ ] Given I just moved a task, when I tap Undo, then it returns to its exact previous position (date, order, overdue flag)
- [ ] Given I deleted a task with a photo, Undo restores it with the photo
- [ ] The status bar entry persists until the next move/delete replaces it — no timeout

### Epic: The list

**US-007: Rapid inline capture**
As Lucas, I want to add several tasks without the keyboard closing.
- [ ] Given the add row is focused, when I type and hit return, then the task appends to the bottom of the active section and the keyboard dismisses
- [ ] Return on an empty field → nothing created
- [ ] The new task's date = the current tab's target date (General → nil)

**US-008: Inline edit**
As Lucas, I want to tap a task's text to fix a typo in place.
- [ ] Tap text → inline text field, keyboard up, cursor at end; return or tap-away commits
- [ ] Clearing the text entirely and committing → title reverts (delete is the menu's job)

**US-009: Completion that self-cleans**
As Lucas, I want ticked tasks to drop away on their own schedule.
- [ ] Tick → strikethrough + grey (per design.md), drops to the completed section at the bottom, no confirmation
- [ ] Untick any time → returns to its former spot in the active list
- [ ] A dated task completed yesterday no longer shows in its tab; it shows in Archive
- [ ] A General task completed 25h ago shows only in Archive
- [ ] A completed task never appears as overdue

**US-010: Manual order that's respected**
As Lucas, I want to drag tasks into my own order and have the app keep its hands off.
- [ ] Long-press-and-drag (finger moves) → reorder mode, row renders navy/white and follows finger; menu never appears
- [ ] Long-press-and-hold (no movement) → context menu; reorder never triggers
- [ ] After I drag a task somewhere, no automatic process ever moves it again (rollover pass skips `overduePlaced` tasks)
- [ ] Flagging Important jumps the task to the top; unflagging leaves it in place

### Epic: Photos

**US-011: Attach one photo**
As Lucas, I want to attach a photo to a task and view it big.
- [ ] Context menu (or add-row camera glyph) → system photo picker / camera; chosen image downscaled and stored
- [ ] Row shows a 64pt sunken-framed thumbnail beneath the text, aligned with the text
- [ ] Tap thumbnail → Win95 window viewer opens instantly (no animation), near-full-screen, navy title bar, pixel ✕
- [ ] Tap anywhere outside (or ✕) → closes instantly
- [ ] Edge: second attach replaces the first (one photo max)

### Epic: Sync & settings

**US-012: Silent sync**
As Lucas, I want my tasks on all my devices with no login.
- [ ] Task (with photo) created on device A appears on device B within ~a minute of both being online
- [ ] Full functionality offline; changes sync when back online
- [ ] Signed out of iCloud → app works locally; Settings shows `iCloud: not signed in`

**US-013: Archive & about**
As Lucas, I want yesterday's completions out of the way but not gone.
- [ ] Settings (title-bar gear) → Archive lists completed tasks grouped by completion day, newest first
- [ ] Archive rows: untick restores the task to its bucket; context-menu Delete removes permanently
- [ ] About shows version, W95FA font credit, tappable privacy policy link

-----

## 6. Functional Requirements

Priorities: P0 = broken without it · P1 = incomplete without it · P2 = nice to have.

**FR-001: Date-derived buckets** — P0
Tabs are pure filters per DateEngine table (§3). No stored bucket, no rollover job. Acceptance: unit tests cover bucket assignment at boundary times (23:59/00:00), the Fri/Sat/Sun weekHorizon cases, and a 5-day-gap reopen. Related: US-001, US-002.

**FR-002: Swipe = one step** — P0
Custom horizontal drag on rows. **Right = defer, left = pull forward** (reversed 2026-08-04, see § Data Model > The line). The gesture must be hit-testable across the ENTIRE row, not just the drawn text. Commit: translation > 40% of row width **or** velocity > 800pt/s in the swipe direction. Below threshold → spring back. At line ends → rubber-band (resistance ~0.3× translation) + light haptic. On commit: row animates off the screen edge (motion snapped to the pixel grid per design.md § Motion), gap closes, model updates synchronously. Gesture must fail fast on predominantly-vertical movement. Related: US-003, US-004.

**FR-003: Context menu** — P0
`.contextMenu`: contextual move entries exactly per the table in §3, then `Mark as Important` / `Unmark Important`, `Attach photo` / `Replace photo` / `Remove photo`, then `Delete` (role: .destructive). Move entries labeled `< Tomorrow`, `<< Today`, `> Week`, `>> General` etc. Related: US-005, US-011.

**FR-004: Drag reorder + disambiguation** — P0
Hold-without-move → menu; hold-with-move → reorder (navy row follows finger). Midpoint sortOrder insert; renormalize when gaps vanish. Related: US-010.

**FR-005: Placement engine** — P0
Exactly the placement table in §3 — including `overduePlaced` semantics and the rollover pass trigger points (app active, significant time change). Acceptance: unit tests for each placement row, plus "dragged overdue task not re-placed next morning". Related: US-001, US-010.

**FR-006: Inline add** — P0
Permanent add row at list bottom (sunken field per design.md): return commits and **dismisses the keyboard** (reversed 2026-08-04 on device feedback); empty return no-ops. The camera glyph COMMITS the task being typed and opens the photo menu for a new one (revised 2026-08-14 — it used to attach to the task it created, which made the plus mean two different things depending on where you pressed it). A pin control sits left of the camera; its state is held until commit, since there is nothing to pin until the task exists (2026-08-16). Related: US-007.

**FR-007: Inline edit** — P0
Tap text → edit in place. Commit on return or focus loss; empty → revert. Related: US-008.

**FR-008: Completion & archive** — P0
Tick/untick per US-009 rules; archive visibility per `isArchived` definition (§3). Archive screen grouped by day. Related: US-009, US-013.

**FR-009: Undo** — P0
Single-level `LastAction` for moves and deletes, surfaced in the status bar. **Retires itself after 6s**; any further mutation restarts the clock. (Was "persistent until replaced"; the implementation has always timed out, and a panel that never leaves covers the last row of the list.) Related: US-006.

**FR-010: Win95 visual system** — P0
Implement every component in design.md § Components with tokens from §§ 2–4: window + title bar (`{Tab} - shove.95`, gear control), sunken list well, task rows (checkbox, single-size text, red Important, trailing chip column, strikethrough+grey completed, navy drag state), status bar, taskbar (four text buttons, pressed active state, clock/date well, safe-area fill), photo viewer window, `(empty)` states. Prohibited-list (design.md §9) violations are bugs. Related: all.

**FR-011: Motion rules** — P0 *(rewritten 2026-08-16)*
Motion is a SHARED layer across both looks and is modern in both: the vintage is in the surfaces, not in the movement (founder direction 2026-08-16). Animate position, appearance and dismissal wherever it helps the reader follow what changed — menus, sheets, the tab switch, the undo bar, the photo viewer. Position lands on the pixel grid so nothing rests half a pixel off, and a transition may not introduce a radius, blur, translucency or system tint that the static design forbids. Haptics: light impact on swipe commit and rubber-band; selection feedback on drag pickup/drop. Supersedes the original "appearance is instant / no transition" rule, which described a 1995 hardware limit rather than an intent. Related: US-003, US-011.

**FR-012: Photos** — P1
MANY photos per task, each its own `TaskPhoto` record (revised for CloudKit: an array of blobs serialises into one field and CKRecord caps non-asset payload at 1MB, so a second photo would have failed to sync silently). Added via PhotosPicker + camera; downscale ≤2048px JPEG q0.8 on import; `@Attribute(.externalStorage)`; 64pt thumbnail; instant viewer. Related: US-011.

**FR-013: CloudKit sync** — P1
`.private` database, container `iCloud.com.lucasmaher.shove95`. No login UI. Settings shows account status (`iCloud: available / not signed in / restricted`). Acceptance: two-device round-trip including a photo; offline edit syncs on reconnect. Related: US-012.

**FR-014: Settings / Archive / About** — P1
Gear in title bar → Settings (Win95 window): Archive, iCloud status row, About (version, font credit, privacy policy link opening in Safari). Related: US-013.

**FR-015: Stepped Dynamic Type** — P1
Map system content size to pixel scale: default sizes → 2×; large/xLarge accessibility bands → 3×; largest accessibility sizes → 4×. Entire UI (text, bevels, metrics) scales via the single `pixel` token. Layouts verified at all three; taskbar labels may abbreviate at 4× (`Tod / Tom / Wk / Gen`). Related: FR-010.

**FR-016: VoiceOver** — P1
Rows expose label (title + state: "important", "overdue since Monday", "completed") and custom actions: Complete/Uncomplete, Defer one step, Pull forward one step, Move to {each menu destination}, Delete. Taskbar buttons are tabs with selected state. The swipe being custom makes these actions mandatory, not optional. Related: FR-002, FR-003.

**FR-017: App icon & launch** — P1
32×32-style pixel-art icon (drawn from scratch — no Microsoft assets), exported at required sizes; launch screen plain `#C0C0C0`. Related: —.

**FR-019: Two design languages** — P0 *(added 2026-08-14)*
The Win95 system of FR-010 is one of TWO complete looks, switched in Settings. The second is soft skeuomorphism per `docs/SKEUOMORPHIC_DESIGN_SYSTEM.md`. Both must reach feature parity — every FR above holds in both. Neither wraps the other; they are siblings chosen above the root. Acceptance: flipping Design never loses state, never closes an open sheet, and leaves the reader looking at the same control in the same place.

**FR-020: Global appearance and typeface** — P1 *(added 2026-08-14)*
Light/dark is GLOBAL and independent of the design switch; both looks ship light and dark palettes. The typeface switch (W95FA / system) is per-look, since the two default differently. Light palettes carry near-black ink at ≥ 4.5:1 (2026-08-16).

**FR-021: The pinned task** — P1 *(added 2026-08-16)*
EXACTLY ONE task, app-wide across every workspace, may be pinned to the Lock Screen and Dynamic Island as a Live Activity, with a tick button that completes it in place. Borrowed from Mononote: the point is not that one item exists, it is that one thing may follow you out of the app and you have to choose which. Replacing the pin asks first; unpinning does not. Completing, deleting or archiving releases it. The card is drawn in the active design. iOS ends any Live Activity within 8h; the app restarts it on next foreground, since the pin belongs to the task rather than to the activity.

**FR-018: Empty states** — P2 — **WITHDRAWN 2026-08-14.**
The main list shows nothing at all when empty; the add row is the invitation. `(empty)` read as an error state. Archive keeps its `(empty)`. Related: US-013.

-----

## 7. Non-Functional Requirements

### Performance
- Cold launch to interactive Today list < 1.0s on the founder's device
- Steady 120fps during swipe, drag, and scroll on ProMotion (no dropped-frame bursts in Instruments)
- Any tap/gesture → visible feedback < 100ms
- App binary < 20MB; typical database (500 tasks, 30 photos) < 100MB iCloud usage

### Security
- Zero secrets, zero network endpoints beyond CloudKit; privacy questionnaire = Data Not Collected

### Accessibility
- Tap targets ≥ 44pt (checkbox visual 24pt with expanded hit area)
- Stepped Dynamic Type per FR-015; VoiceOver per FR-016
- Meaning never carried by color alone (red + top-tier placement; chip + block position; strikethrough + grey)

### Scalability
- Correct and smooth at 1,000 tasks / 100 photos (personal-app ceiling; in-memory filtering is acceptable at this scale)

### Reliability
- Fully functional offline, indefinitely; no data loss across force-quit, reboot, or reinstall-with-iCloud
- Date logic correct across timezone changes, DST, and midnight-while-open (recompute triggers per §2)
- CloudKit conflicts: last-writer-wins (CloudKit default) is acceptable for a single-user app

-----

## 8. UI/UX Requirements

Visual styling lives in `docs/design.md` — components referenced by name. This section covers structure, states, and interactions.

### Screen: Main (Today / Tomorrow / Week / General)
Route: root; four tabs share one screen, switched by taskbar. **Structure (top→bottom):** TitleBar (`{Tab} - shove.95`, gear → Settings) · SunkenWell containing the task list + AddRow · StatusBar (last action + Undo) · Taskbar (4 buttons + clock well).

States:
- **Empty:** `(empty)` centered in the well; add row still present at bottom
- **Loading:** none — SwiftData is synchronous at this scale; first frame is populated
- **Populated:** incomplete by sortOrder → completed struck-through → AddRow last
- **Error:** none reachable (no network in the view path)

Key interactions:
- Taskbar tap → instant tab switch (no transition); active button renders pressed
- Swipe row L/R → FR-002 · Long-press → FR-003 menu · Long-press-drag → FR-004 reorder
- Tap checkbox → toggle complete · Tap text → inline edit · Tap thumbnail → photo viewer
- Tap Undo in StatusBar → FR-009
- Clock well: displays current date + time (non-interactive)

Components: Win95Window, TitleBar, SunkenWell, TaskRow, DateChip, AddRow, StatusBar, Taskbar, Win95Checkbox.

### Screen: Photo viewer (overlay)
Opens instantly over everything; near-full-screen Win95Window: TitleBar (task title, ✕ control), image in sunken frame on `#C0C0C0` body. Tap ✕ or anywhere outside → instant close. No zoom/pan in v1. Not draggable.

### Screen: Settings
Presented from gear (full-screen Win95 window, title `Settings - shove.95`, ✕ returns). Rows as raised-bevel list items: **Archive** → Archive screen · **iCloud** status line (`iCloud: available` / `not signed in`) · **About** → About screen.

### Screen: Archive
Title `Archive - shove.95`. Sunken well; sections per completion day (`Today — 3 items`, `Mon 28 Jul — 5 items`), newest first. Rows: struck-through text + checkbox (tick state on). Untick → task leaves archive, returns to its bucket. Context menu: Delete (permanent, no confirmation — but records nothing in undo; acceptable, it's two deliberate steps). Empty: `(empty)`.

### Screen: About
Title `About - shove.95`. Static: app name + version/build, "Typeface: W95FA by Alina Sava (SIL OFL)", `Privacy policy` link (opens Safari), © line.

### Onboarding
None. First launch lands on empty Today. The interface is the tutorial; the status bar teaches the swipe result on first use.

-----

## 9. Auth Implementation

This app does not require authentication — CloudKit binds to the device's Apple Account with no login surface. If auth is ever added (it should not be), revisit this section.

-----

## 10. Payment Integration

Free app, no payments. Section intentionally empty.

-----

## 11. Edge Cases & Error Handling

### Feature: Date engine
| Scenario | Expected behavior | Priority |
|---|---|---|
| Midnight passes while app foregrounded | On next significant-time-change notification: filters recompute, rollover pass runs, Today updates in place | P0 |
| App opened after N days | All accumulated overdue appear in Today; rollover pass places only never-placed ones | P0 |
| Timezone change / DST | All boundaries derive from `Calendar.current` at read time; no stored day boundaries to invalidate | P0 |
| Device clock set backwards | Tasks may appear "in the future" in Today's filter — accept (filter is `< startOfTomorrow`, future-dated beyond tomorrow simply appear in their buckets); no crash | P2 |
| Saturday/Sunday Week semantics | weekHorizon rolls to next Sunday; Week tab never empty-by-construction | P0 |

### Feature: Gestures
| Scenario | Expected behavior | Priority |
|---|---|---|
| Diagonal swipe | Vertical dominance → scroll; horizontal dominance → swipe; no simultaneous both | P0 |
| Swipe at line end | Rubber-band + haptic, no mutation | P0 |
| Long-press then slight tremor (<10pt) | Still menu, not reorder | P1 |
| Swipe during inline edit | Commit the edit first, then normal gesture handling | P1 |
| Rapid consecutive swipes on different rows | Each commits independently; status bar shows the latest | P1 |

### Feature: Data & sync
| Scenario | Expected behavior | Priority |
|---|---|---|
| iCloud signed out / restricted | Local-only operation; Settings shows status; no prompts, no errors | P0 |
| Same task edited on two offline devices | CloudKit last-writer-wins; no user-facing conflict UI | P1 |
| Photo import very large / HDR | Downscaled ≤2048px JPEG before store; failure → task saved without photo, no crash | P1 |
| iCloud quota full | CloudKit stops syncing; app keeps working locally (SwiftData unaffected) | P2 |
| Delete syncs while task open in edit on other device | Edit target vanishes; view dismisses gracefully via id-based rendering | P2 |

### Feature: Input
| Scenario | Expected behavior | Priority |
|---|---|---|
| Return on empty add row | No task created, field stays focused | P0 |
| Edit cleared to empty | Revert to previous title | P0 |
| Very long title | Truncates with `…` before the chip column (design.md); full text visible in edit mode | P1 |
| Paste multiline text into add row | Newlines collapsed to spaces | P2 |

-----

## 12. Dependencies & Integrations

### Core Dependencies
**None.** No SPM/CocoaPods packages. Apple frameworks only: SwiftUI, SwiftData, CloudKit (via SwiftData), PhotosUI, UIKit (font registration + haptics only).

### Development Dependencies
Xcode 26.6 toolchain; Swift Testing (bundled) for Shove95Kit tests.

### Third-Party Services
| Service | Used for | Cost / requirement |
|---|---|---|
| Apple Developer Program | CloudKit entitlement + App Store distribution | $99/yr — **must exist before FR-013** |
| iCloud / CloudKit | Sync, private database | Free (user quota) |
| GitHub Pages | Privacy policy URL for App Store Connect | Free |
| W95FA typeface (FontsArena, Alina Sava) | The app's single font | Free, SIL OFL — bundle license file, credit in About |

-----

## 13. Out of Scope

**Revised 2026-08-14:** dark mode has SHIPPED and is no longer out of scope — Light / Dark / System as one global `AppearanceMode`, with dark palettes for all five Win95 schemes plus the skeu look. See `design.md` §1 for the structural rules the dark palettes obey. A second design mode (`DesignMode.skeu`, soft skeuomorphism) also ships alongside the Windows 95 look; see `SKEUOMORPHIC_DESIGN_SYSTEM.md` and `skeu-mode-plan.md`.

Per `product-vision.md` § Explicitly Out of Scope, all deferred with reasoning there: notifications/reminders (v1.1 — most valuable deferred feature), macOS app (immediately post-v1; Shove95Kit exists for it), multiple photos, recurring tasks / subtasks / tags / projects / search / collaboration (permanently, barring proven daily need), statistics/streaks (brand-incompatible), data export (pre-requisite only if external users ever matter). Also out of scope for v1: iPad-optimized layout (iPhone layout runs compatibly), widgets, Watch, Siri/Shortcuts, localization (English UI only).

-----

## 14. Open Questions

1. **App icon artwork.** Pixel-art direction locked (no Microsoft assets); the actual drawing is undecided. Options: a pixel hand mid-shove, a tilted red arrow, a bevelled "95". Owner: Lucas, before the App Store phase. *Default if undecided: bevelled raised square with a pixel right-arrow glyph.*
2. **Week-end = Sunday** is hard-coded by design (German/ISO convention). Confirm acceptable if the phone's locale ever differs. *Default: keep Sunday, locale-independent.*
3. **Archive retention.** Currently: forever, delete manually. Revisit only if the archive grows annoying. *Default: keep forever.*
4. **Delete inside Archive is permanent with no undo.** Accepted? *Default: yes — it is two deliberate steps deep.*
5. **Clock well format.** `Tue 03.08.` vs `12:04` vs both stacked. *Default: date on top of time, both in W95FA 8px×scale — decide visually in the styling phase.*
