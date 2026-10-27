//
//  SkeuRootView.swift
//  shove95
//
//  The main screen in the skeu look, rebuilt from the founder's frame (shove95
//  file, node 2:609) in light brown.
//
//  That frame is 1495 × 3250 — an iPhone layout drawn at 3.72×. Every number
//  in `F` is its value times 402/1495, with the source value alongside so any
//  of them can be checked against the file.
//
//  The list between the bars is live — real tasks from the store, completion
//  toggles, an add row, swipes, the row menu, photos and date chips.
//
//  Row construction follows the founder's established language rather than the
//  design-system §9.6 slat: a task is a TROUGH cut into the ground (the same
//  channel the bars use), its checkbox a glass circle lying in it — subdued
//  while open, prominent once done. One vocabulary for the whole screen.
//

import SwiftUI
import PhotosUI
import Shove95Kit

private enum F {
    /// 402pt of phone over 1495pt of frame.
    static let s: CGFloat = 402.0 / 1495.0

    /// Founder direction (2026-08-14): the menu/settings gear read too small
    /// next to the close ✕ used everywhere else in this look (a flat 37pt in
    /// SkeuSettingsView and SkeuSecondaryScreens). Rather than bump `plus`
    /// alone and leave it looking oversized against its neighbours, every
    /// button/toggle/row token below scales by the same ratio — including
    /// font sizes and the glass "bloom" shading, both of which are already
    /// parametrized off these values, so they grow in proportion for free.
    static let scaleUp: CGFloat = 37 / (107.444 * s)

    /// ONE margin on every side. The frame itself is uneven — 28.0 leading,
    /// 46.2 trailing, 21.5 below — which reads as a bar pushed off-centre
    /// rather than as a deliberate inset. The smallest of the three wins.
    /// Page-edge inset, not a button/toggle — left out of the scale-up.
    static let margin = 21.5

    /// The workspace/tab bars sit INSIDE the safe area, so the old code's
    /// `.padding(.vertical, margin)` stacked a full second margin on top of
    /// whatever the Dynamic Island and home indicator already reserve — far
    /// more room above the workspace bar and below the tab bar than beside
    /// them (founder bug report 2026-08-14). This is the smaller, VERTICAL-
    /// ONLY margin that replaces it: just the breathing room beyond the
    /// mandatory safe-area clearance, pushing both bars toward their
    /// physical top/bottom edges, on device — to about where Apple Notes
    /// sits its own toolbars.
    ///
    /// Horizontal stays on `margin` for every bar, workspace included — an
    /// earlier pass here also swapped the workspace bar's LEFT/RIGHT inset
    /// to this smaller value, which reads fine on the simulator but jams the
    /// pill into the corner on a real device's rounded edge (founder bug
    /// report 2026-08-14, second round). Vertical and horizontal insets
    /// answer different physical constraints — a notch and a corner radius —
    /// and conflating them was the bug.
    ///
    /// ZERO is deliberate, measured off Apple Notes at the founder's request
    /// (2026-08-14, third round): Notes puts its top toolbar's upper edge at
    /// ~55pt against a ~59pt top inset, and its bottom toolbar's lower edge
    /// at ~836pt against an ~840pt bottom boundary. In other words it adds no
    /// margin of its own — the safe area IS the margin, and the toolbars ride
    /// right on it. Anything above zero here reads as the bars floating short
    /// of the edge, which is exactly what kept getting flagged.
    static let marginNotch = 0.0

    /// The TOP needs to go slightly negative to land where Notes lands, and
    /// the bottom does not — hence a second constant rather than one shared
    /// value. At `marginNotch = 0` the bottom bar already sits ~842pt against
    /// an ~840pt boundary (matched), but the top bar can only reach ~66pt,
    /// because the top safe-area inset is ~59pt and the bar's own glass bloom
    /// eats the rest. Notes clears ~55pt by drawing INTO that inset, so this
    /// lifts by the difference. Small on purpose: the status bar's own glyphs
    /// sit above this line, and a larger lift would run the pill into them.
    /// Positive now (founder direction 2026-08-14): the negative lift put the
    /// workspace pill and gear tight against the status-bar glyphs. They sit
    /// just below the safe area instead.
    static let marginTopLift = 6.0

    /// How far a row dissolves as it passes under a docked bar. About half a
    /// row: long enough to read as a fade rather than a flicker, short enough
    /// that the row under the bar is still legible on its way out.
    static let edgeFade = 28.0

    // Workspace bar — node 2:655, positioned by 2:654
    static let topHeight = 145.8 * s * scaleUp        // 39.2 → 50.2
    static let gapTop = 54 * s * scaleUp              // 14.5 → 18.5

    // Tab bar — node 2:639
    static let bottomHeight = 148.2 * s * scaleUp     // 39.9 → 51.1

    // Shared trough padding — nodes 2:639 / 2:655
    static let padLead = 71.313 * s * scaleUp         // 19.2 → 24.6
    static let padTrail = 20.617 * s * scaleUp        // 5.5 → 7.1
    /// How much further OUT a row's two edges sit than the figures above put
    /// them (founder direction 2026-08-23): the tick and the title a touch
    /// left, the day chip and the grip a touch right. Small on purpose — the
    /// ask was for a nudge, not a new margin.
    static let edgeNudge: CGFloat = 4

    // Glass pill — node 2:657
    static let glassPadH = 35.656 * s * scaleUp       // 9.6 → 12.3
    static let glassPadV = 23.771 * s * scaleUp       // 6.4 → 8.2
    static let glassGap = 29.714 * s * scaleUp        // 8.0 → 10.2
    static let icon = 59.427 * s * scaleUp            // 16.0 → 20.5
    static let label = 47.542 * s * scaleUp           // 12.8 → 16.4

    // Round glass button — node 2:665
    static let plus = 107.444 * s * scaleUp           // 28.9 → 37 (matches the ✕)
    static let plusIcon = 53.722 * s * scaleUp        // 14.4 → 18.5

    /// The workspace pill and the settings gear ONLY: +20%, font included
    /// (founder direction 2026-08-14). Applied at those two call sites rather
    /// than folded into the tokens above, because `plus`/`plusIcon` are also
    /// worn by the camera glyphs and `label`/`glassPad*` by the tab bar —
    /// none of which are meant to grow with the top bar.
    static let topControlScale: CGFloat = 1.2

    // Bloom behind each trough — nodes 2:653 / 2:610
    static let bloomBlur = 5.381 * s * scaleUp        // 1.45 → 1.85
    /// ONE overhang, not the frame's two (40 wide / 15.4 tall): the uneven
    /// halo pooled at the ends and pinched at the edges. The vertical wins.
    static let bloomOverhang = 15.4 * s * scaleUp     // 4.1 → 5.3

    /// The tab bar's own type size and pill padding, SMALLER than the shared
    /// `label`/`glassPadH`.
    ///
    /// Four labels have to share the phone's width, and "Tomorrow" is the
    /// longest word in the app. At the shared 16.4 it did not fit its quarter,
    /// so `minimumScaleFactor` shrank that ONE label and the row read as three
    /// normal tabs and one small one (founder bug report 2026-08-14). Sizing
    /// the row so its widest member fits keeps every label identical, which is
    /// the whole point of a four-up toggle.
    static let tabLabel = 41 * s * scaleUp            // 11.0 → 14.1
    static let tabPillPadH = 22 * s * scaleUp         // 5.9 → 7.6

    // Task rows — no frame reference yet; sized against the bars.
    static let rowHeight: CGFloat = 44 * scaleUp      // 56.3
    static let rowGap: CGFloat = 2 * scaleUp          // 2.6
    static let check: CGFloat = 26 * scaleUp          // 33.3
    /// Photo thumbnail — the 64pt spec size (TASK-045), scaled
    /// up with everything else so it doesn't read small next to a bigger row.
    static let thumb: CGFloat = 64 * scaleUp          // 82.0
}

struct SkeuRootView: View {
    @Environment(\.skeu) private var skeu
    @Environment(\.skeuTextScale) private var textScale
    @Environment(\.skeuChromeScale) private var chromeScale
    @Environment(\.pixel) private var pixel
    @Environment(AppSettings.self) private var settings
    @Environment(SyncStatus.self) private var sync
    @Environment(TaskStore.self) private var store

    /// Owned by AppShell — see that file for why the sheet cannot live here.
    @Binding var showSettings: Bool
    @State private var bucket: Bucket = .today
    /// Which way the last tab change travelled — decided BEFORE `bucket`
    /// moves, so both halves of the transition agree on a direction.
    @State private var goingRight = true
    @State private var menu = MenuCoordinator()
    /// Which field is open and where its bottom edge sits.
    @State private var editing = EditingCoordinator()
    /// Seeded with the list's own row gap: part of the distance a row travels
    /// before it displaces the next one — see `ReorderCoordinator`.
    @State private var reorder = { let c = ReorderCoordinator(); c.rowGap = F.rowGap; return c }()
    /// How much of the list the keyboard is covering, in points.
    @State private var keyboardOverlap: CGFloat = 0
    /// The keyboard's top edge in global coordinates; .infinity when hidden.
    @State private var keyboardTop: CGFloat = .infinity
    /// The keyboard's own animation, kept from its last notification so the
    /// inset and the lift both travel on it.
    @State private var keyboardAnimation: Animation = .easeOut(duration: 0.25)
    /// How far this list's bottom edge sits above the screen's — measured,
    /// because the tab bar's height is not the same number. See KeyboardDock.
    @State private var bottomGap: CGFloat = 0

    // Dynamic Type (FR-015): text on the full curve, chrome at half — see
    // SkeuTypeScale for why the two differ. The BARS are fixed-height chrome
    // transcribed from the Figma frame, so they take the gentler curve; the
    // labels inside them take the full one and truncate if they must.
    private var labelSize: CGFloat { F.label * textScale }
    private var rowH: CGFloat { F.rowHeight * chromeScale }
    private var checkSize: CGFloat { F.check * chromeScale }

    private var glyphSize: CGFloat { F.plusIcon * chromeScale }
    private var glyphBox: CGFloat { F.plus * chromeScale }
    private var bottomBarHeight: CGFloat { F.bottomHeight * chromeScale }

    /// The tab bar's glass pill glides from the old selection to the new one
    /// instead of popping in fresh each time (founder direction 2026-08-14).
    @Namespace private var tabPillNS

    // The workspace pill's open/closed flag deliberately does NOT live here —
    // see SkeuWorkspacePill for why keeping it out of the root's state is
    // what makes opening the menu cheap.

    // The add row's own state — draft, focus, buffered photos, pending day —
    // lives on `SkeuAddRow` at the foot of this file, not here. Soon carries
    // one add row per section (founder direction 2026-08-17), and state held
    // on the root would be shared between them: typing under one day would
    // put the same draft under every other.

    /// Identity of the list's top, for `scrollTo` on a workspace change.
    private static let topAnchor = "list.top"
    /// Half-turns the gear has made. See the settings button.
    @State private var gearTurns = 0
    /// True when the Live section holds the screen instead of a task list.
    @State private var showLive = false
    /// The Live tab's swell, held here rather than by `.skeuPress` — see
    /// `liveTab` for why the modifier could not be used as-is. §8.5 is this
    /// view's to honour now that it owns the scaling.
    @State private var livePressed = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            skeu.canvas.ignoresSafeArea()

            VStack(spacing: 0) {
                workspaceBar
                    .padding(.horizontal, F.margin)
                    .padding(.top, F.marginTopLift)
                // Tabs slide in from the side they live on: tapping a tab to
                // the right brings its list in from the right. Only the LIST
                // travels — the bars are furniture and hold still, so the
                // frame reads as fixed and the content as moving through it.
                ZStack {
                    Group {
                        if showLive {
                            SkeuLiveSection()
                        } else {
                            taskList
                        }
                    }
                        .id(showLive ? "live" : bucket.rawValue)
                        .transition(.asymmetric(
                            insertion: .move(edge: goingRight ? .trailing : .leading),
                            removal: .move(edge: goingRight ? .leading : .trailing)
                        ))
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .clipped() // contents travel; the window never does
                // The undo panel FLOATS over the list rather than taking
                // layout space, so it can come and go without shifting the
                // rows — and it sits above the tab bar, not inside it. Outside
                // the slide, so it doesn't ride along.
                .overlay(alignment: .bottom) { undoPanel }
                tabBar
                    .padding(.horizontal, F.margin)
                    .padding(.bottom, F.marginNotch)
            }
        }
        // The bars are furniture: they stay put while the keyboard is up.
        .ignoresSafeArea(.keyboard, edges: .bottom)
        // The row menu draws above everything, unclipped by the scroll view.
        .overlay { SkeuMenuOverlay() }
        // And so does the row being carried — above the bars as well, since a
        // row dragged to the top of the screen passes over them.
        .overlay { carriedRow.ignoresSafeArea() }
        // Only one thing can be live, so sending a second one asks first.
        .overlay {
            if menu.pendingLive != nil {
                SkeuPinReplaceDialog(
                    outgoing: store.liveNote()?.title ?? "",
                    title: "Replace what is live",
                    message: "Something is already live. This task takes its place, and the one there now goes — the undo bar can bring it back.",
                    confirmLabel: "Replace"
                ) {
                    withAnimation(SkeuMotion.layout) { menu.confirmLive(store: store) }
                } onCancel: {
                    menu.cancelLive()
                }
            }
        }
        .animation(SkeuMotion.present, value: menu.pendingLive?.id)
        // The Live section's bin asks from HERE rather than from inside the
        // section, so its scrim covers the bars as well — see
        // `MenuCoordinator.pendingLiveDelete`.
        .overlay {
            if menu.pendingLiveDelete {
                SkeuPinReplaceDialog(
                    outgoing: store.liveNote()?.title ?? "",
                    title: "Delete this",
                    message: "It goes for good, and it stops showing on the Lock Screen.",
                    confirmLabel: "Delete",
                    confirmTint: skeu.accent
                ) {
                    menu.pendingLiveDelete = false
                    withAnimation(SkeuMotion.layout) { store.clearLiveNote() }
                } onCancel: {
                    menu.pendingLiveDelete = false
                }
            }
        }
        .animation(SkeuMotion.present, value: menu.pendingLiveDelete)
        .environment(menu)
        .environment(editing)
        .environment(reorder)
        // The store's queries are scoped to the active workspace, and this
        // view is the one that has to keep that scope pointed at the pick.
        .onAppear {
            store.seedWorkspacesIfNeeded(legacy: settings.legacyWorkspaces)
            syncWorkspaceScope()
        }
        .onChange(of: settings.currentWorkspaceID) { syncWorkspaceScope() }
        .onChange(of: store.revision) { syncWorkspaceScope() }
        // A row that just sent itself to another day names the tab it landed
        // on — see `EditingCoordinator.followTo`. Going there is what keeps
        // the edit visible instead of leaving it on a row that is no longer
        // in this list.
        .onChange(of: editing.followTo) { _, destination in
            guard let destination else { return }
            editing.followTo = nil
            select(destination)
        }
        // Fires at midnight, timezone changes and clock changes (PRD §2).
        // Without it a task left overnight never gets its arrival placement
        // and the day boundary silently passes — a DATA bug, not a cosmetic
        // one.
        .onReceive(NotificationCenter.default.publisher(
            for: UIApplication.significantTimeChangeNotification)) { _ in
            store.runDayRolloverPassIfNeeded(
                timeRules: settings.timeRulesEnabled(for: .today))
        }
    }

    // MARK: Workspace bar — node 2:654

    private var workspaceBar: some View {
        HStack(alignment: .top, spacing: 0) {
            SkeuWorkspacePill()

            Spacer(minLength: SkeuSpace.sm)

            // The gear stands in for the frame's ✚ — this screen still has to
            // reach Settings, and there is nowhere else yet.
            Group {
                // Shared with the ✕ that closes every sheet — see SkeuTopBar.
                let size = SkeuTopBar.control * chromeScale
                // Pixel under Retro and Blend, the system symbol under
                // System — see SkeuChromeGlyph.
                SkeuChromeGlyph(kind: .gear, face: settings.skeuFace,
                                size: SkeuTopBar.icon * chromeScale, tint: skeu.ink)
                    .frame(width: size, height: size)
                    .rotationEffect(.degrees(Double(gearTurns) * 180))
                    .skeuGlass(Circle(), height: size)
            }
            // Half a turn on every press (founder direction 2026-08-17),
            // accumulated rather than toggled so it keeps turning one way.
            .skeuPress {
                withAnimation(SkeuMotion.layout) { gearTurns += 1 }
                showSettings = true
            }
            .frame(minWidth: SkeuControl.minTouch, minHeight: SkeuControl.minTouch)
            .accessibilityAddTraits(.isButton)
            .accessibilityLabel("Settings")
        }
    }

    // MARK: Task list

    private var taskList: some View {
        let (active, completed) = store.tasks(in: bucket)

        // ScrollView, not List — List eats the horizontal pans the app's core
        // swipe will need (the TASK-019 spike finding).
        //
        // ScrollViewReader so a field that opens under the keyboard can be
        // lifted to sit just above it, exactly as TaskListView does. Without
        // it, editing a row near the bottom put the caret behind the keyboard
        // with no way to see what you were typing.
        return ScrollViewReader { proxy in
        ScrollView {
            LazyVStack(spacing: F.rowGap) {
                // Scroll anchor. Switching workspace jumps here rather than
                // keeping the old list's offset, which left a long list part
                // way down and mid-animation (founder bug report 2026-08-17).
                //
                // A HAIRLINE, not zero height: a zero-height row inside a
                // LazyVStack is not reliably laid out, and `scrollTo` cannot
                // reach what was never placed.
                Color.clear.frame(height: 0.5).id(Self.topAnchor)
                // No empty-state text: the add row's own "add" placeholder
                // already says the list is empty and where to start.
                //
                // Soon is the one tab with structure inside it: the undated
                // block, then a heading per scheduled day (founder direction
                // 2026-08-17). The others are one flat run.
                if bucket == .general {
                    // ONE shape for every block, General included. It used to
                    // be written out twice — an undated run and then a loop
                    // over the days — and General is not a special case, it is
                    // the block whose day is nothing.
                    //
                    // Each block carries its own DONE tasks now, so ticking
                    // something off under Wednesday leaves it under Wednesday
                    // (founder direction 2026-08-17).
                    ForEach(store.soonSections()) { section in
                        sectionHeading(section.day.map {
                            DayHeading.label(for: $0, calendar: .current)
                        } ?? "General", day: section.day)

                        // The block folds away entire: a section shut is a
                        // section with nothing showing, and a stray capture row
                        // under a closed heading belongs to nothing visible.
                        if !settings.isCollapsed(section.day) {
                            ForEach(section.active, id: \.id) { task in
                                reorderRow(task, in: section.active)
                                    .id(task.id.uuidString)
                            }

                            if !section.completed.isEmpty {
                                Color.clear.frame(height: F.rowGap)
                                ForEach(section.completed, id: \.id) { task in
                                    taskRow(task)
                                        .id(task.id.uuidString)
                                }
                            }

                            // Every block ends in its own add row, which stamps
                            // that block's date on what it creates. One row at
                            // the foot of the list could only ever add to one
                            // section. Soon therefore has NO trailing add row —
                            // the last day's is the bottom one.
                            SkeuAddRow(bucket: bucket, day: section.day)
                                .id(EditingCoordinator.addRowID(for: section.day))
                                // Soon's capture row answers to the walkthrough
                                // too, and General's is the one that stands in:
                                // it is the block a task lands in when no day
                                // is chosen (code review 2026-08-17).
                        }
                    }
                } else {
                    ForEach(active, id: \.id) { task in
                        reorderRow(task, in: active)
                            .id(task.id.uuidString)
                    }
                }

                // Soon's completed tasks sit inside their own block above; only
                // the flat tabs keep one run of them at the foot.
                if bucket != .general, !completed.isEmpty {
                    Color.clear.frame(height: F.rowGap)
                    ForEach(completed, id: \.id) { task in
                        taskRow(task)
                            .id(task.id.uuidString)
                    }
                }

                if bucket != .general {
                    SkeuAddRow(bucket: bucket)
                        .id(EditingCoordinator.addRowID)
                }
            }
            .padding(.vertical, SkeuSpace.lg)
            // The MARGIN is on the ROWS, not on anything that clips.
            //
            // A ScrollView clips to its own bounds, so every enclosing inset
            // was also a wall: a swiped row stopped a margin short of the
            // screen with a strip of page still showing beside it (founder
            // bug report 2026-08-17, twice — the first fix moved the padding
            // off the outer clip and left this one in place). The rows are
            // inset exactly as before; nothing between them and the screen
            // edge is.
            .padding(.horizontal, F.margin)
        }
        // Follow the add row down as the list grows. Committing a task inserts
        // it exactly where the add row was standing, which pushes the add row
        // below the fold — the task lands, the keyboard drops, and there is
        // suddenly nowhere to type the next one (founder bug report
        // 2026-08-14). Keyed on the count rather than `store.revision` so that
        // ticking, renaming or moving a task doesn't yank the list downward.
        .onChange(of: active.count + completed.count) { old, new in
            guard new > old else { return } // only on ADD, never on delete
            // Follow the row that was TYPED INTO, not the one at the bottom:
            // with an add row per section, the two are usually different.
            let target = editing.lastAddRowID ?? EditingCoordinator.addRowID
            withAnimation(SkeuMotion.layout) {
                proxy.scrollTo(target, anchor: .bottom)
            }
        }
        // Go to the task that just took an edit to another day. The list is
        // LAZY, so this is not a convenience — the row does not exist until
        // something scrolls to it, and until it exists there is nothing to
        // hand the edit back to. See `EditingCoordinator.reopenTaskID`.
        //
        // Deferred a runloop turn for the same reason the workspace change is:
        // the section it landed in is being built on this very pass, so a
        // `scrollTo` run inline aims at the list as it was before the move.
        .onChange(of: editing.reopenTaskID) { _, id in
            guard let id else { return }
            Task { @MainActor in
                withAnimation(SkeuMotion.layout) {
                    proxy.scrollTo(id.uuidString, anchor: .center)
                }
            }
        }
        .onChange(of: editing.focused) { _, _ in
            // The NEXT runloop turn, not a fixed beat. The inset is applied in
            // this same pass and a `scrollTo` run inline would aim at the
            // layout the list had before it — but the 80ms this used to wait
            // was long enough to read as a second, later movement chasing the
            // keyboard (founder bug report 2026-08-17).
            Task { @MainActor in liftFocusedFieldIfCovered(proxy) }
        }
        .onChange(of: keyboardTop) { _, _ in liftFocusedFieldIfCovered(proxy) }
        .scrollDismissesKeyboard(.interactively)
        // The give at the limit is what tells you the list ended.
        .scrollBounceBehavior(.always, axes: .vertical)
        .scrollIndicators(.hidden)
        // The list carries its own bottom inset so the keyboard has somewhere
        // to sit. `.ignoresSafeArea(.keyboard)` above keeps the BARS docked,
        // and that same modifier is why automatic field-avoidance never fires
        // here — this inset replaces it.
        .contentMargins(.bottom, keyboardOverlap, for: .scrollContent)
        .bottomGapToScreen($bottomGap)
        .onReceive(NotificationCenter.default.publisher(
            for: UIResponder.keyboardWillChangeFrameNotification)) { note in
            guard let change = KeyboardDock.read(note, clearance: bottomGap) else { return }
            keyboardTop = change.top
            // Held so the lift travels on the same curve — see KeyboardDock
            // for why the keyboard's own is the only right one.
            keyboardAnimation = change.animation
            withAnimation(change.animation) { keyboardOverlap = change.overlap }
        }
        // Both bars are docked and the list runs out under them, so each edge
        // dissolves rather than cutting — and only once there is something
        // past it to dissolve. See SkeuEdgeFade.
        .skeuScrollEdgeFade(F.edgeFade * chromeScale)
        .onChange(of: settings.currentWorkspaceID) {
            // DEFERRED a runloop turn. The scope sync and the store's re-query
            // run on this same change, so scrolling inline aims at the list
            // that is on its way out — which is why the first attempt did
            // nothing at all (founder bug report 2026-08-17).
            //
            // No animation either: the two lists share no rows, so anything
            // interpolating between them is the stutter itself.
            Task { @MainActor in
                var t = Transaction(); t.disablesAnimations = true
                withTransaction(t) { proxy.scrollTo(Self.topAnchor, anchor: .top) }
            }
        }
        } // ScrollViewReader
    }

    /// Docks the focused field just above the keyboard — but ONLY if the
    /// keyboard is actually covering it. A field already in the clear stays
    /// exactly where it is (founder spec 2026-08-04); yanking it would be as
    /// disorienting as hiding it.
    private func liftFocusedFieldIfCovered(_ proxy: ScrollViewProxy) {
        guard let id = editing.focused, editing.focusedBottom > 0 else { return }
        guard editing.focusedBottom + SkeuSpace.md > keyboardTop else { return }
        withAnimation(keyboardAnimation) {
            proxy.scrollTo(id, anchor: .bottom)
        }
    }

    /// One task row. A separate STRUCT, not a helper function, and that is
    /// load-bearing: inside a LazyVStack the model reads must happen in the
    /// row's own body, or the row belongs to the parent's observation scope
    /// and keeps its stale look after a toggle — the task moved to the
    /// completed section but kept rendering unchecked (caught on device
    /// 2026-08-13).
    private func taskRow(_ task: TaskItem, siblings: [TaskItem] = []) -> some View {
        SkeuTaskRow(task: task, siblings: siblings)
    }

    /// A row in the list, which gets out of the way when a neighbour is being
    /// carried past it.
    ///
    /// The row being carried is INVISIBLE here — it is drawn by
    /// `carriedRow`, floating above the whole screen. Its slot stays, which is
    /// what the rows around it close up into.
    ///
    /// Only the rows getting out of the way are animated; nothing else here
    /// moves under its own steam.
    private func reorderRow(_ task: TaskItem, in siblings: [TaskItem]) -> some View {
        let shift = reorder.offset(for: task.id)
        return taskRow(task, siblings: siblings)
            .opacity(reorder.isDragging(task.id) ? 0 : 1)
            .offset(y: shift)
            .animation(ReorderCoordinator.displace, value: shift)
    }

    /// The row under the finger, drawn OVER everything.
    ///
    /// See `SkeuTaskRow.carried` for why it is a copy rather than the row
    /// itself. It is placed in global coordinates from the frame the row had
    /// when it was picked up, plus however far the finger has gone since.
    @ViewBuilder
    private var carriedRow: some View {
        if let task = reorder.carriedTask {
            let frame = reorder.grabFrame
            SkeuTaskRow(task: task, siblings: [], carried: true)
                .frame(width: frame.width)
                // A little bigger and off the page. Small on purpose — the row
                // is being carried, not thrown.
                .scaleEffect(1.03)
                .shadow(color: skeu.shadow.opacity(0.30), radius: 16, y: 10)
                .position(x: frame.midX, y: frame.midY + reorder.travel)
                .allowsHitTesting(false)
        }
    }

}

// MARK: - The add row

/// The add row: a plain row like the tasks themselves — an unchecked circle
/// and a faded "add" beside it, no frame (founder direction 2026-08-13). The
/// commit ＋ only exists while the field is being edited, the same way the
/// existing rows grow their controls in edit mode.
///
/// A VIEW OF ITS OWN, not a slice of the root, because Soon stands one of
/// these at the foot of every section rather than one at the foot of the list
/// (founder direction 2026-08-17). Draft, focus and buffered photos have to
/// belong to the row that owns them; held on the root they would be shared,
/// and typing under one day would show the same half-written task under all
/// of them.
private struct SkeuAddRow: View {
    let bucket: Bucket
    /// The section this row sits under, and therefore the date it stamps on
    /// what it creates. nil is the undated section — General in Soon, and the
    /// whole of every other tab.
    var day: Date?

    @Environment(\.skeu) private var skeu
    @Environment(TaskStore.self) private var store
    @Environment(EditingCoordinator.self) private var editing
    @Environment(\.skeuTextScale) private var textScale
    @Environment(\.skeuChromeScale) private var chromeScale

    // Dynamic Type (FR-015) — the same five measurements the task rows take.
    private var labelSize: CGFloat { F.label * textScale }
    private var rowH: CGFloat { F.rowHeight * chromeScale }
    private var checkSize: CGFloat { F.check * chromeScale }
    private var glyphSize: CGFloat { F.plusIcon * chromeScale }
    private var glyphBox: CGFloat { F.plus * chromeScale }

    @State private var draft = ""
    @FocusState private var addFocused: Bool

    // Photo attach from the add row. NOT the flow the old add row used — that
    // one committed the draft the moment ✚ was pressed and then targeted the fresh
    // task, which reads as "my editing just ended and a photo menu opened for
    // something else" (founder bug report 2026-08-13). Here the picked photos
    // are BUFFERED alongside the draft and attach when the task is actually
    // committed, so taking a photo is part of composing, not the end of it.
    @State private var showPhotoPicker = false
    @State private var showCamera = false
    @State private var showSourceChoice = false
    @State private var pickedItem: PhotosPickerItem?
    @State private var pendingPhotos: [Data] = []
    /// A day chosen at the calendar, OVERRIDING the section this row sits in.
    /// Held until commit, like `pendingPhotos`: there is nothing to schedule
    /// until the task exists (founder bug report 2026-08-17). Cleared on
    /// commit, which drops the row back to its own section, not to undated.
    @State private var pendingDay: Date?
    @State private var showAddDayPicker = false
    /// The add row's frame in global space — reported to the editing
    /// coordinator so a focused field can be lifted above the keyboard.
    @State private var addRowFrame: CGRect = .zero
    /// Guards against a double insert when both Return paths fire.
    @State private var committingAdd = false

    /// What this row will stamp on the next task: the day picked by hand, else
    /// the section the row stands in.
    private var effectiveDay: Date? { pendingDay ?? day }

    /// This row's own scroll and focus identity — one per section in Soon.
    private var rowID: String { EditingCoordinator.addRowID(for: day) }

    /// The two glyphs take the "add" placeholder's ink until something is
    /// typed, and the full ink after (founder direction 2026-08-17).
    /// Standing at full strength
    /// over an empty field, they were the brightest things in the list and the
    /// loudest part of a row that has nothing in it yet.
    private var controlInk: Color {
        draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? skeu.inkFaint : skeu.ink
    }

    var body: some View {
        HStack(spacing: F.glassGap) {
            ZStack {}
                .frame(width: checkSize, height: checkSize)
                .skeuGlass(Circle(), height: checkSize, prominent: false)
                .frame(width: SkeuControl.minTouch, height: SkeuControl.minTouch)
                .contentShape(Rectangle())
                .onTapGesture { addFocused = true }

            // Vertical axis so a long entry wraps and the row grows a line at a
            // time. That growth is the ONLY way a
            // line is added — Return is a commit, never a break.
            TextField("", text: returnCommittingAdd,
                      prompt: Text("add").foregroundStyle(skeu.inkFaint),
                      axis: .vertical)
                .lineLimit(1...4)
                .font(SkeuFont.at(labelSize))
                .foregroundStyle(skeu.ink)
                .focused($addFocused)
                .submitLabel(.done)
                // BOTH Return paths — see AddRowView.returnCommitting for why
                // intercepting only one of them fails on device.
                .onSubmit { commitAdd(title: draft) }
                .onChange(of: addFocused) { _, isFocused in
                    if isFocused {
                        editing.begin(rowID, bottom: addRowFrame.maxY)
                    } else {
                        editing.end(rowID)
                    }
                }

            // Photos picked mid-composition wait here, visibly, until commit.
            ForEach(Array(pendingPhotos.enumerated()), id: \.offset) { _, data in
                if let image = PhotoCache.image(data) {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .frame(width: checkSize, height: checkSize)
                        .clipShape(RoundedRectangle(cornerRadius: SkeuRadius.xs,
                                                    style: .continuous))
                }
            }

            // NO pin here. A task becomes live by being typed into the Live
            // section, and that is the only door (founder direction
            // 2026-08-17).


            if addFocused {
                Button {
                    if UIImagePickerController.isSourceTypeAvailable(.camera) {
                        showSourceChoice = true
                    } else {
                        showPhotoPicker = true
                    }
                } label: {
                    // A BARE glyph — no glass circle behind it (founder
                    // direction 2026-08-14). It keeps the full-size frame so
                    // the tap target stays honest; only the surface is gone.
                    Image(systemName: "camera")
                        .font(SkeuFont.at(glyphSize, weight: .medium))
                        .symbolRenderingMode(.hierarchical)
                        .foregroundStyle(controlInk)
                        .frame(width: glyphBox, height: glyphBox)
                }
                .buttonStyle(.plain)
                .transition(.scale(scale: 0.6).combined(with: .opacity))
                .accessibilityLabel("Add photo to new task")
            }

            // The calendar, AFTER the camera — which is where editing a task
            // puts it. It used to sit BEFORE the camera here, so the pair
            // swapped sides between writing a task and editing one, and you
            // had to look for the same control twice (founder bug report
            // 2026-08-17).
            //
            // Drawn in the same ink as the camera, never in the accent. It
            // used to light up once a day was chosen; that made two controls
            // standing side by side look like different KINDS of thing, and
            // the row already says which day it belongs to — its heading is
            // directly above it (founder direction 2026-08-17).
            if addFocused, bucket == .general {
                Image(systemName: "calendar")
                    .font(SkeuFont.at(glyphSize, weight: .medium))
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(controlInk)
                    .frame(width: glyphBox, height: glyphBox)
                    .frame(width: SkeuControl.minTouch, height: rowH)
                    .contentShape(Rectangle())
                    .onTapGesture { SkeuHaptic.press(); showAddDayPicker = true }
                    .transition(.scale(scale: 0.6).combined(with: .opacity))
                    .accessibilityLabel("Schedule")
            }
        }
        .padding(.leading, max(0, SkeuSpace.xs - F.edgeNudge))
        .padding(.trailing, max(0, F.padTrail - F.edgeNudge))
        .frame(minHeight: rowH)
        .animation(SkeuMotion.press, value: addFocused)
        .background {
            GeometryReader { proxy in
                Color.clear
                    .onChange(of: proxy.frame(in: .global)) { _, new in addRowFrame = new }
                    .task { addRowFrame = proxy.frame(in: .global) }
            }
        }
        .photosPicker(isPresented: $showPhotoPicker, selection: $pickedItem, matching: .images)
        .sheet(isPresented: $showAddDayPicker) {
            SkeuDayPickerSheet(current: effectiveDay) { picked in
                showAddDayPicker = false
                pendingDay = picked
            }
        }
        .fullScreenCover(isPresented: $showCamera) {
            CameraPicker { data in
                showCamera = false
                guard let data, let prepared = ImageImport.prepare(data) else { return }
                pendingPhotos.append(prepared)
            }
            .ignoresSafeArea()
        }
        // The one system sheet worth keeping — see the row's own picker.
        .confirmationDialog("Add photo", isPresented: $showSourceChoice) {
            if UIImagePickerController.isSourceTypeAvailable(.camera) {
                Button("Camera") { showCamera = true }
            }
            Button("Photo Library") { showPhotoPicker = true }
            Button("Cancel", role: .cancel) {}
        }
        .onChange(of: pickedItem) { _, item in
            guard let item else { return }
            Task { @MainActor in
                if let data = try? await item.loadTransferable(type: Data.self),
                   let prepared = ImageImport.prepare(data) {
                    pendingPhotos.append(prepared)
                }
                pickedItem = nil
            }
        }
    }

    /// The newline half of the Return story — see `AddRowView.returnCommitting`
    /// for why both this and `onSubmit` have to be wired.
    private var returnCommittingAdd: Binding<String> {
        Binding(
            get: { draft },
            set: { new in
                guard new.contains("\n") else { draft = new; return }
                commitAdd(title: new.replacingOccurrences(of: "\n", with: ""))
            }
        )
    }

    private func commitAdd(title raw: String) {
        guard !committingAdd else { return } // second call for one Return
        let title = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty else {
            draft = ""
            Task { @MainActor in addFocused = false }
            return
        }
        committingAdd = true
        draft = ""
        // Told BEFORE the store write: the list scrolls to follow whichever add
        // row committed, and the change it reacts to is the one below.
        editing.lastAddRowID = rowID
        // Deferred: a store write and a focus change from inside a binding
        // setter both land mid-update, where SwiftUI drops them.
        Task { @MainActor in
            // Buffered photos attach HERE, to the task the user was composing —
            // not to some fresh context the moment the camera was pressed.
            if let task = store.addTask(title: title, in: bucket) {
                for data in pendingPhotos {
                    store.addPhoto(task, data: data)
                }
                pendingPhotos = []
                if let day = effectiveDay {
                    store.schedule(task, on: day, recordingUndo: false)
                }
            }
            // Keyboard dismisses on commit: a field that stays open reads as
            // "still typing" and hides the list you just added to.
            pendingDay = nil
            addFocused = false
            // Second clear — UIKit writes its own buffer back after the
            // setter returns. See AddRowView.returnCommitting.
            draft = ""
            committingAdd = false
        }
    }
}

// MARK: - The root, continued

extension SkeuRootView {

    // MARK: Undo

    /// Appears only when there is a last action to report, and retires itself
    /// after six seconds — any further mutation restarts the clock. Built as a
    /// trough with a glass Undo pill, the same vocabulary as the bars.
    @ViewBuilder
    private var undoPanel: some View {
        if let action = store.lastAction {
            HStack(spacing: F.glassGap) {
                Text(action.statusText(name: settings.name))
                    .font(SkeuFont.at(labelSize))
                    .foregroundStyle(skeu.ink)
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .frame(maxWidth: .infinity, alignment: .leading)

                // Flat too. A glass pill inside a flat bar would have been the
                // only lit object on it; tone alone carries the button here.
                Text("Undo")
                    .font(SkeuFont.at(labelSize, weight: .medium))
                    .foregroundStyle(skeu.ink)
                    .lineLimit(1)
                    .padding(.horizontal, F.glassPadH)
                    .frame(height: 30)
                    .background(Capsule().fill(skeu.material))
                    // The pill reads 30 so it sits quietly in the 46pt bar;
                    // the target is 44 and reaches nearly the bar's full height.
                    .frame(height: SkeuControl.minTouch)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        SkeuHaptic.press()
                        withAnimation(SkeuMotion.layout) { store.undoLastAction() }
                    }
                    .accessibilityLabel("Undo last action")
                    .accessibilityAddTraits(.isButton)
            }
            .padding(.leading, F.padLead)
            .padding(.trailing, SkeuSpace.sm)
            .frame(height: 46)
            // FLAT, and inset from the edges (founder direction 2026-08-16).
            // It was a trough running the full screen width — the one object
            // in the app that touched both edges, and carved into the ground
            // on top of that. It is not part of the furniture; it is a message
            // that arrives and leaves, so it lies ON the page rather than
            // being cut into it. `recess` is the same stock a shade darker,
            // which is all the separation a flat panel needs.
            .background(Capsule().fill(skeu.recess))
            .padding(.horizontal, F.margin)
            .padding(.bottom, SkeuSpace.sm)
            .transition(.move(edge: .bottom).combined(with: .opacity))
            // Retires itself; any further mutation restarts the clock.
            .task(id: store.revision) {
                try? await Task.sleep(for: .seconds(4))
                if !Task.isCancelled {
                    withAnimation(SkeuMotion.layout) { store.dismissLastAction() }
                }
            }
        }
    }

    // MARK: Tab bar — node 2:639

    /// Live in its own frame, then the three tabs in theirs.
    ///
    /// Live is NOT a fourth segment (founder direction 2026-08-17). It is not
    /// a slice of the date line the other three divide up — it is the thing
    /// you are doing now — so it stands in a frame of its own, in the same
    /// materials, rather than sharing their channel.
    private var tabBar: some View {
        // A gap wider than anything inside either frame, so the eye reads two
        // objects rather than one bar with a seam. The three tabs give up the
        // width — they share a trough that stretches, and Live's is fixed.
        HStack(spacing: SkeuSpace.lg) {
            liveTab
            bucketTabs
        }
    }

    /// A square of the same channel, holding the mark and no word. A label
    /// would say what the icon already says, and there is no room for both.
    private var liveTab: some View {
        let height = SkeuToggle.height * chromeScale
        let pill = height - SkeuToggle.padV * chromeScale * 2

        // The SWELL rides the MARK, and the channel it sits in holds still
        // (founder bug report 2026-09-01).
        //
        // `.skeuPress` was wrapped around the finished control — trough, bloom
        // and all — so pressing Live grew the whole frame, while every tab
        // beside it grows only its own pill inside a trough that never moves.
        // One bar, two different reactions.
        //
        // The bucket tabs get this for free: their `.skeuPress` sits on the
        // SEGMENT, and `SkeuSegmentedTrough` wraps all of them from outside,
        // so it is never in the scaled subtree. Live has a trough of its own
        // and no such separation, so the swell is held here by hand — the same
        // thing SkeuWorkspacePill does, and for the same reason.
        return liveMark(pill: pill)
            .scaleEffect(reduceMotion ? 1 : (livePressed ? SkeuMotion.pressGrow : 1))
            .animation(reduceMotion ? SkeuMotion.tint : SkeuMotion.pressSwell,
                       value: livePressed)
            .padding(SkeuToggle.padV * chromeScale)
            .frame(height: height)
            .skeuTrough(Capsule(), height: height)
            .background { liveBloom }
            // The gesture stays on the OUTSIDE so the whole channel remains
            // the target; only what it scales has moved inward.
            .contentShape(Rectangle())
            .onTapGesture { pressLive() }
            .accessibilityAddTraits(showLive ? [.isButton, .isSelected] : .isButton)
            .accessibilityLabel("Live")
    }

    /// Split out because the whole button in one expression put the type
    /// checker over its budget — SkeuKit's modifiers are generic enough that a
    /// chain this long stops resolving in reasonable time.
    ///
    /// ONE glyph, with the glass behind it rather than around it. It was two —
    /// a glass-wearing copy and a plain one, swapped by opacity — and the
    /// pulse sat on the copy that is invisible unless you are already ON the
    /// Live tab. So the bar only breathed where the news was least useful
    /// (founder bug report 2026-08-17).
    ///
    /// The pulse rides the MARK and the glass holds still, which is right:
    /// the glass says "you are here" and the breath says "something is on
    /// air". Two different pieces of news should not move together.
    private func liveMark(pill: CGFloat) -> some View {
        LiveGlyph(tint: skeu.ink, lineWidth: 1.7 * chromeScale)
            .frame(width: pill * 0.5, height: pill * 0.5)
            .skeuPulse(store.liveNote()?.isPinned == true)
            .frame(width: pill, height: pill)
            .background {
                if showLive {
                    Capsule().fill(.clear)
                        .skeuGlass(Capsule(), height: pill, prominent: true)
                }
            }
    }

    private var liveBloom: some View {
        Capsule()
            .fill(LinearGradient(colors: [skeu.materialTop, skeu.recess],
                                 startPoint: .top, endPoint: .bottom))
            .padding(-SkeuToggle.bloomOverhang * chromeScale)
            .blur(radius: SkeuToggle.bloomBlur)
            .allowsHitTesting(false)
    }

    private var bucketTabs: some View {
        // The shared toggle — the same construction every settings option row
        // uses. See SkeuSegmented for why it lives in one place: a settings
        // toggle that differs from this bar reads as a different control.
        SkeuSegmentedTrough {
            ForEach(Bucket.line, id: \.self) { line in
                SkeuSegment(isSelected: !showLive && bucket == line,
                            namespace: tabPillNS,
                            geometryID: "tabPill") {
                    // ABBREVIATED rather than shrunk once the row gets tight
                    // — see AppSettings.tabLabel. The accessibility label
                    // below still says the whole word.
                    Text(settings.tabLabel(for: line, textScale: textScale))
                        .skeuSegmentLabel(textScale)
                        .foregroundStyle(skeu.ink)
                }
                .skeuPress(haptic: false) { select(line) }
                // The FULL name is the label even when the visible text is
                // short, and selection
                // is a trait rather than something you have to see (FR-016).
                .accessibilityAddTraits(!showLive && bucket == line ? [.isButton, .isSelected]
                                                                   : .isButton)
                .accessibilityLabel(settings.name(for: line))
            }
        }
    }

    /// `SkeuPress.swell` by hand: out, held, and back on the same timing every
    /// other control in the app uses.
    private func pressLive() {
        livePressed = true
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(260))
            livePressed = false
        }
        selectLive()
    }

    /// Live comes in from the LEFT, because that is where its frame is.
    private func selectLive() {
        guard !showLive else { return }
        SkeuHaptic.selection()
        goingRight = false
        withAnimation(SkeuMotion.layout) { showLive = true }
    }

    /// A section's name, and the control that folds it shut.
    ///
    /// The accent rule that used to sit above each heading is gone: the band
    /// already says where one section ends and the next begins, and two
    /// devices for one boundary is one too many (founder direction
    /// 2026-08-17).
    private func sectionHeading(_ title: String, day: Date?) -> some View {
        let collapsed = settings.isCollapsed(day)
        let shape = RoundedRectangle(cornerRadius: SkeuRadius.md, style: .continuous)

        // Set ABOVE the task text, not below it. A heading that names a run of
        // tasks has to outrank them, and this was an eyebrow in `inkFaint` —
        // the quietest type in the look — which left the day a task belonged
        // to harder to read than the task (founder direction 2026-08-17).
        return HStack(spacing: SkeuSpace.sm) {
            Text(title)
                .font(SkeuFont.at(labelSize * 1.32, weight: .semibold))
                .foregroundStyle(skeu.ink)

            Spacer(minLength: 0)

            Image(systemName: "chevron.right")
                .font(SkeuFont.at(labelSize, weight: .semibold))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(skeu.inkMuted)
                .rotationEffect(.degrees(collapsed ? 0 : 90))
                .animation(SkeuMotion.layout, value: collapsed)
        }
        .padding(.horizontal, SkeuSpace.md)
        .padding(.vertical, SkeuSpace.sm)
        .frame(minHeight: SkeuControl.minTouch)
        // A band, so a heading is not just larger text but a different KIND of
        // thing from the rows under it (founder direction 2026-08-17). A TINT,
        // not a surface: the accent at low strength, the same device the
        // selected segment uses. A lit slat here would read as a pill.
        .background { shape.fill(skeu.accent.opacity(0.12)) }
        .contentShape(shape)
        .skeuPress {
            withAnimation(SkeuMotion.layout) { settings.toggleCollapsed(day) }
        }
        .accessibilityAddTraits(.isButton)
        .accessibilityLabel("\(title), \(collapsed ? "collapsed" : "expanded")")
        .padding(.horizontal, SkeuSpace.xs)
        .padding(.top, SkeuSpace.xl)
        .padding(.bottom, SkeuSpace.xs)
    }

    /// One scheduled day's name.
    private func dayHeading(_ day: Date) -> some View {
        sectionHeading(DayHeading.label(for: day, calendar: .current), day: day)
    }

    /// Resolves the slide direction BEFORE the selection moves, so the
    /// outgoing and incoming lists agree on which way they are travelling.
    private func select(_ line: Bucket) {
        // Coming back from Live always travels right — Live sits left of them
        // all, so any bucket is forward from it.
        if showLive {
            SkeuHaptic.selection()
            goingRight = true
            withAnimation(SkeuMotion.layout) {
                showLive = false
                bucket = line
            }
            return
        }
        guard line != bucket,
              let from = Bucket.line.firstIndex(of: bucket),
              let to = Bucket.line.firstIndex(of: line) else { return }
        SkeuHaptic.selection()
        goingRight = to > from
        withAnimation(SkeuMotion.layout) { bucket = line }
    }

    // MARK: Pieces

    /// The channel both bars are cut into, with the soft bloom that seats it
    /// in the ground: light over dark, opposite the trough's own fill, so the
    /// bar sits in a shallow dish rather than on flat paint.
    private func trough<C: View>(height: CGFloat,
                                 spacing: CGFloat,
                                 symmetric: Bool = false,
                                 @ViewBuilder content: () -> C) -> some View {
        HStack(spacing: spacing) {
            content()
        }
        .padding(.leading, symmetric ? (F.padLead + F.padTrail) / 2 : F.padLead)
        .padding(.trailing, symmetric ? (F.padLead + F.padTrail) / 2 : F.padTrail)
        .frame(height: height)
        .skeuTrough(Capsule(), height: height)
        .background {
            Capsule()
                .fill(LinearGradient(colors: [skeu.recessBottom, skeu.recess],
                                     startPoint: .top, endPoint: .bottom))
                .padding(-F.bloomOverhang)
                .blur(radius: F.bloomBlur)
                .allowsHitTesting(false)
        }
    }

    // `plainLabel` / `glassLabel` lived here until 2026-08-14. The workspace
    // bar stopped using them when it became a dropdown, and the tab bar
    // stopped when its glass moved into a background layer so the text could
    // hold still — at which point a "selected" and an "unselected" spelling
    // of the same label were the very thing causing the drift.

    /// Points the store's queries at the selected workspace.
    private func syncWorkspaceScope() {
        let all = store.workspaces()
        let ids = Set(all.compactMap(\.taskStampID))
        if store.knownWorkspaceIDs != ids { store.knownWorkspaceIDs = ids }
        if !all.contains(where: { $0.id == settings.currentWorkspaceID }) {
            settings.currentWorkspaceID = Workspace.defaultID
        }
        let stamp = all.first { $0.id == settings.currentWorkspaceID }?.taskStampID
        if store.workspaceID != stamp { store.workspaceID = stamp }
    }
}

// MARK: - Workspace switcher

/// The workspace switcher: a title, a ▼ and a short menu, in this look's own
/// vocabulary rather than as a floating panel — the CURRENT workspace stays
/// living in the glass pill, and tapping
/// it or the chevron grows that same pill straight down into a short list of
/// the others (founder direction 2026-08-14). Nothing detaches from the
/// control; the pill itself is the menu.
///
/// A separate STRUCT, not a helper property on SkeuRootView, and that is
/// load-bearing — the same lesson SkeuTaskRow records. The open/closed flag
/// used to be `@State` on the ROOT, so every toggle invalidated the root's
/// whole body: `store.tasks(in:)` re-ran (a fetch, a sort, three filters),
/// `store.workspaces()` re-ran (a fetch, a dedup, a sort), and every task row
/// was rebuilt — all to expand one pill. That is what made opening the menu
/// crawl (founder bug report 2026-08-14). Owning the flag here keeps the
/// invalidation inside this small subtree.
private struct SkeuWorkspacePill: View {
    @Environment(\.skeu) private var skeu
    @Environment(AppSettings.self) private var settings
    @Environment(TaskStore.self) private var store
    @Environment(\.skeuTextScale) private var textScale
    @Environment(\.skeuChromeScale) private var chromeScale

    @State private var isOpen = false
    /// The swell, held HERE rather than by `.skeuPress`.
    ///
    /// The modifier scales whatever it wraps, and what it wrapped was the
    /// label row — the glass is on the outer container, because it has to
    /// cover the open list too. So the name grew and the pill around it
    /// didn't (founder bug report 2026-08-17). The gesture still belongs to
    /// the header alone; only the scale is lifted to the whole thing.
    @State private var swollen = false

    var body: some View {
        let workspaces = store.workspaces()
        let current = workspaces.first { $0.id == settings.currentWorkspaceID }
        let others = workspaces.filter { $0.id != settings.currentWorkspaceID }
        // Everything in here rides the same +20% as the gear, font included,
        // so the pill grows as one piece instead of a bigger box around
        // unchanged text. Dynamic Type layers on top of that.
        let scale = F.topControlScale
        let label = F.label * scale * textScale
        let rowHeight = (F.topHeight - F.glassPadV * 2) * scale * chromeScale

        return VStack(alignment: .leading, spacing: 0) {
            // No Button: it would take the touch before the press could see
            // it, which is what kept the sheet ✕ from swelling.
            Group {
                HStack(spacing: F.glassGap * scale) {
                    // CHROME: the workspace name is the app naming where you
                    // are, not something you are reading — see TextRole.
                    Text(current?.name ?? "")
                        .font(SkeuFont.at(label, role: .chrome))
                        .tracking(-0.02 * label)
                        .lineLimit(1)
                        // Shrink rather than pin: a long workspace name at
                        // large Dynamic Type used to push the settings gear
                        // clean off the screen.
                        .minimumScaleFactor(0.6)
                        // And a CEILING, because shrinking alone has a floor:
                        // past it the text grows the pill again and carries
                        // the gear off the edge with it (founder bug report
                        // 2026-08-17). Names are bounded now, but the bar
                        // should not depend on that to stay on screen.
                        .frame(maxWidth: 200 * scale)

                    // Two strokes, nothing else — no circle, no glass of its
                    // own. It rides inside the pill it controls.
                    // Only when there is somewhere to go. One workspace means
                    // nothing to pick, and an arrow onto an empty list is a
                    // promise the app cannot keep (founder direction
                    // 2026-08-17).
                    if !others.isEmpty {
                        ChevronGlyph()
                            .stroke(skeu.ink,
                                    style: StrokeStyle(lineWidth: 1.6 * scale, lineCap: .round))
                            .frame(width: label * 0.55, height: label * 0.32)
                            .rotationEffect(.degrees(isOpen ? 180 : 0))
                    }
                }
                .foregroundStyle(skeu.ink)
                .frame(height: rowHeight)
            }
            .contentShape(Rectangle())
            .onTapGesture {
                swell()
                SkeuHaptic.selection()
                // Nothing to choose from: no chevron turn, no list. The pill
                // still swells — it reads as a control that is simply already
                // where it can be (founder direction 2026-08-17).
                guard !others.isEmpty else { return }
                withAnimation(SkeuMotion.layout) { isOpen.toggle() }
            }
            .accessibilityAddTraits(.isButton)
            .accessibilityLabel("Workspace: \(current?.name ?? "")")
            .accessibilityHint("Opens the workspace list")

            if isOpen {
                ForEach(others, id: \.id) { workspace in
                    Text(workspace.name)
                        .font(SkeuFont.at(label, role: .chrome))
                        .tracking(-0.02 * label)
                        .foregroundStyle(skeu.inkMuted)
                        .lineLimit(1)
                        // Full pill width, not `.fixedSize()` — the row has to
                        // be tappable across the whole pill, not just where
                        // the glyphs happen to fall.
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .frame(height: rowHeight)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            SkeuHaptic.selection()
                            withAnimation(SkeuMotion.layout) {
                                settings.currentWorkspaceID = workspace.id
                                isOpen = false
                            }
                        }
                        .accessibilityAddTraits(.isButton)
                        .transition(.opacity.combined(with: .move(edge: .top)))
                }
            }
        }
        .padding(.horizontal, F.glassPadH * scale)
        .frame(minWidth: SkeuControl.minTouch * 1.6, alignment: .leading)
        .fixedSize(horizontal: true, vertical: false)
        .skeuGlass(RoundedRectangle(cornerRadius: rowHeight / 2, style: .continuous),
                   height: rowHeight)
        // The whole pill, glass and all — the app's press, applied where the
        // object actually is. Same numbers as `.skeuPress`.
        .scaleEffect(swollen ? SkeuMotion.pressGrow : 1)
        .animation(SkeuMotion.pressSwell, value: swollen)
    }

    private func swell() {
        swollen = true
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(260))
            swollen = false
        }
    }
}

// MARK: - Demonstrations for How to use

//  The two controls that never announce themselves, shown DOING the thing the
//  page describes rather than drawn as a pictogram beside it (founder
//  direction 2026-09-01).
//
//  They live in THIS file, next to the controls they mirror, because the real
//  ones are built out of `F` and `ChevronGlyph`, both private here. Moving the
//  demos to the How to use screen would mean copying those values across a
//  file boundary, and a picture of a control that drifts from the control is
//  worse than no picture — the whole point is that the reader recognises what
//  they are about to touch.
//
//  Both are decoration and both are inert: no gestures, no store writes, and
//  hidden from VoiceOver, which reads the block's own words instead.

/// The workspace pill, opening and changing workspace on a loop.
///
/// Four beats: sit closed, grow open with the other name under it, commit to
/// that name and close, and round again from the other side. It uses the same
/// `SkeuMotion.layout` spring the real pill does, so the demonstration and the
/// thing demonstrated move alike.
///
/// Reduce Motion holds it closed rather than slowing it down — the loop is
/// decoration, and that setting turns decoration off (§8.5).
struct SkeuWorkspacePillDemo: View {
    @Environment(\.skeu) private var skeu
    @Environment(\.skeuTextScale) private var textScale
    @Environment(\.skeuChromeScale) private var chromeScale
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// Two names. The caller hands over the reader's OWN workspaces when they
    /// have two to spare, so the picture is of their app rather than of an
    /// example app.
    let names: [String]

    @State private var index = 0
    @State private var isOpen = false
    /// The swell of the tap being demonstrated — the real pill swells on every
    /// press, and a demo that opened without one read as opening by itself
    /// (founder bug report 2026-09-01).
    @State private var pressed = false

    var body: some View {
        let scale = F.topControlScale
        let label = F.label * scale * textScale
        let rowHeight = (F.topHeight - F.glassPadV * 2) * scale * chromeScale
        let shown = names.isEmpty ? "" : names[index % names.count]
        let other = names.count < 2 ? "" : names[(index + 1) % names.count]

        return VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: F.glassGap * scale) {
                Text(shown)
                    .font(SkeuFont.at(label, role: .chrome))
                    .tracking(-0.02 * label)
                    .lineLimit(1)
                    // A HARD swap, not a dissolve. A changing string inside a
                    // `withAnimation` cross-fades by default, so at the moment
                    // the demo committed to the other workspace both names
                    // were drawn over each other and the pill read as a smear
                    // (caught on the first run). Selecting a workspace is a
                    // commitment; the name should simply be the new one.
                    .contentTransition(.identity)

                ChevronGlyph()
                    .stroke(skeu.ink,
                            style: StrokeStyle(lineWidth: 1.6 * scale, lineCap: .round))
                    .frame(width: label * 0.55, height: label * 0.32)
                    .rotationEffect(.degrees(isOpen ? 180 : 0))
            }
            .foregroundStyle(skeu.ink)
            .frame(height: rowHeight)

            if isOpen {
                Text(other)
                    .font(SkeuFont.at(label, role: .chrome))
                    .tracking(-0.02 * label)
                    .foregroundStyle(skeu.inkMuted)
                    .lineLimit(1)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .frame(height: rowHeight)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(.horizontal, F.glassPadH * scale)
        .frame(minWidth: SkeuControl.minTouch * 1.6, alignment: .leading)
        .fixedSize(horizontal: true, vertical: false)
        .skeuGlass(RoundedRectangle(cornerRadius: rowHeight / 2, style: .continuous),
                   height: rowHeight)
        // The real pill scales the WHOLE thing, glass and open list included —
        // see SkeuWorkspacePill, which lifts the swell off its label row for
        // exactly this reason. Same figures.
        .scaleEffect(reduceMotion ? 1 : (pressed ? SkeuMotion.pressGrow : 1))
        .animation(reduceMotion ? SkeuMotion.tint : SkeuMotion.pressSwell,
                   value: pressed)
        // ROOM HELD OPEN, always. The pill grows downward when it opens, and
        // letting that push the block's frame taller made the whole card
        // breathe in and out around it — the page moved when nothing on the
        // page had changed (founder direction 2026-09-01). Reserving the open
        // height up front means the list unfolds into space that was already
        // there, and only the pill moves.
        .frame(height: rowHeight * 2, alignment: .topLeading)
        .accessibilityHidden(true)
        .task(id: reduceMotion) { await run() }
    }

    /// One demonstrated tap: the swell starts with the action, as `SkeuPress`
    /// does, and is released on the same 260ms.
    private func press(_ action: () -> Void) async {
        pressed = true
        action()
        try? await Task.sleep(for: .milliseconds(260))
        pressed = false
    }

    private func run() async {
        guard !reduceMotion, names.count > 1 else {
            isOpen = false
            return
        }
        // A beat of stillness at each end: a loop with no rest reads as a
        // fidget rather than as an action being performed. HALF the original
        // pace (founder direction 2026-09-01) — at 1.2s a beat the pill
        // demanded attention from the corner of the eye while the reader was
        // still on the paragraph above it.
        while !Task.isCancelled {
            try? await Task.sleep(for: .milliseconds(2400))
            guard !Task.isCancelled else { return }
            // Tap one: the pill swells and opens on the same beat.
            await press { withAnimation(SkeuMotion.layout) { isOpen = true } }

            try? await Task.sleep(for: .milliseconds(2400))
            guard !Task.isCancelled else { return }
            // Tap two: choosing the other workspace. The list folding away is
            // the animated part; the name it leaves behind is not — see
            // `contentTransition` above.
            await press {
                index = (index + 1) % names.count
                withAnimation(SkeuMotion.layout) { isOpen = false }
            }
        }
    }
}

/// One task row, shoving itself sideways on a loop.
///
/// BUILT, not filmed (founder question 2026-09-01). A screen recording would
/// be one fixed pixel grid, and this app has four themes in light and dark,
/// two typefaces and the whole Dynamic Type range behind it — sixteen-odd
/// clips to cover what one live row covers by simply being drawn in whatever
/// look is current. A recording also goes stale the moment the row changes,
/// and this file's history is mostly the row changing.
///
/// The checkbox is the real glass circle at the real `F.check`, and the title
/// sits at the real `F.label`, so the picture is the row the reader is about
/// to touch rather than a sketch of it.
///
/// Two rows and ONE sequence between them, rather than two rows each looping
/// on their own — see `run()`.
struct SkeuSwipeSequenceDemo: View {
    @Environment(\.skeu) private var skeu
    @Environment(\.skeuTextScale) private var textScale
    @Environment(\.skeuChromeScale) private var chromeScale
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    // The row's own figures, not approximations of them — see SkeuTaskRow.
    private var labelSize: CGFloat { F.label * textScale }
    private var rowH: CGFloat { F.rowHeight * chromeScale }
    private var checkSize: CGFloat { F.check * chromeScale }
    private var glyphSize: CGFloat { F.plusIcon * chromeScale }
    /// SkeuTaskRow.firstLineInset, verbatim: what puts the tick, the title,
    /// the chip and the grip on one band.
    private var firstLineInset: CGFloat {
        max(0, (rowH - UIFont.systemFont(ofSize: labelSize).lineHeight) / 2)
    }

    /// Measured, so "off screen" means off THIS card rather than some figure
    /// guessed at build time.
    @State private var width: CGFloat = 360

    @State private var topOffset: CGFloat = 0
    @State private var bottomOffset: CGFloat = 0
    @State private var topCollapsed = false
    @State private var topMarked = false
    @State private var bottomMarked = false
    @State private var visible = true

    var body: some View {
        VStack(alignment: .leading, spacing: SkeuSpace.xs) {
            face("call the dentist", chip: "Tue", marked: topMarked)
                .offset(x: topOffset)
                // Its slot closing is what lifts the row beneath it. Height
                // rather than a removal transition: the one below has to RISE,
                // and a row that is simply taken out of the stack pops.
                .frame(height: topCollapsed ? 0 : nil, alignment: .top)
                .opacity(topCollapsed ? 0 : 1)
                .clipped()

            face("pick up the parcel", chip: "Thu", marked: bottomMarked)
                .offset(x: bottomOffset)
        }
        .opacity(visible ? 1 : 0)
        .background {
            GeometryReader { proxy in
                Color.clear.task { width = proxy.size.width }
            }
        }
        // ROOM HELD OPEN, for the same reason the workspace pill holds it: the
        // card must not breathe while the rows leave and close up.
        .frame(height: rowH * 2 + SkeuSpace.xs, alignment: .top)
        .accessibilityHidden(true)
        .task(id: reduceMotion) { await run() }
    }

    /// `SkeuTaskRow.mainLine` with the interactive parts taken out: the same
    /// checkbox, title, day chip and grip, in the same order, at the same
    /// sizes, with the same padding — and the same lit slat behind it that the
    /// real row wears while it is being slid.
    private func face(_ title: String, chip: String, marked: Bool) -> some View {
        HStack(alignment: .top, spacing: F.glassGap) {
            Circle().fill(.clear)
                .frame(width: checkSize, height: checkSize)
                .skeuGlass(Circle(), height: checkSize, prominent: false)
                .frame(width: SkeuControl.minTouch, height: SkeuControl.minTouch)
                .frame(height: rowH)

            Text(title)
                .font(SkeuFont.at(labelSize))
                .tracking(-0.02 * F.label)
                .foregroundStyle(skeu.ink)
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.top, firstLineInset)
                .frame(minHeight: rowH, alignment: .top)

            Text(chip)
                .font(SkeuFont.at(labelSize * 0.85, weight: .medium))
                .foregroundStyle(skeu.inkFaint)
                .padding(.top, firstLineInset)
                .frame(minHeight: rowH, alignment: .top)

            ReorderGrip(isActive: false, size: glyphSize, bandHeight: rowH)
                .allowsHitTesting(false)
        }
        .padding(.leading, max(0, SkeuSpace.xs - F.edgeNudge))
        .padding(.trailing, max(0, F.padTrail - F.edgeNudge))
        .frame(minHeight: rowH)
        // STRONGER than the row's own 0.55/0.35, and it has to be. On the list
        // the mark sits on the page; here it sits inside a well, whose floor is
        // already lifted away from the page — so the same opacity bought far
        // less separation and the slid row barely read as marked (founder bug
        // report 2026-09-01). The well's own lift is what these numbers are
        // paying back.
        .background {
            RoundedRectangle(cornerRadius: SkeuRadius.md, style: .continuous)
                .fill(skeu.isDark ? skeu.materialTop : skeu.recess)
                .opacity(marked ? (skeu.isDark ? 0.95 : 0.6) : 0)
                .animation(SkeuMotion.tint, value: marked)
        }
    }

    /// One story, told in order (founder direction 2026-09-01): the top task is
    /// shoved off to the left, the one under it rises into the space, and then
    /// that one is shoved off to the right.
    ///
    /// It replaced two rows each looping on their own, which moved together
    /// and only travelled far enough to twitch. A task leaving the list is the
    /// POINT of the gesture — a swipe that stops halfway is one you changed
    /// your mind about.
    private func run() async {
        // The WAITS are doubled, the shoves are not (founder direction
        // 2026-09-01). A swipe is a fast thing and slowing it would misdescribe
        // the gesture; what was hurried was the pause between the two, which
        // gave no time to read what had just happened before the next one
        // started.
        guard !reduceMotion else { return }
        while !Task.isCancelled {
            try? await Task.sleep(for: .milliseconds(2800))
            guard !Task.isCancelled else { return }

            // 1. The top one goes, all the way out to the left.
            withAnimation(SkeuMotion.tint) { topMarked = true }
            withAnimation(.easeIn(duration: 0.42)) { topOffset = -(width + 80) }
            try? await Task.sleep(for: .milliseconds(560))
            guard !Task.isCancelled else { return }

            // 2. Its place closes, and the one below rises into it.
            withAnimation(SkeuMotion.layout) { topCollapsed = true }
            try? await Task.sleep(for: .milliseconds(2000))
            guard !Task.isCancelled else { return }

            // 3. And that one goes too, the other way.
            withAnimation(SkeuMotion.tint) { bottomMarked = true }
            withAnimation(.easeIn(duration: 0.42)) { bottomOffset = width + 80 }
            try? await Task.sleep(for: .milliseconds(1400))
            guard !Task.isCancelled else { return }

            // 4. Fade the empty stage out, put everything back where it was
            //    while nothing is visible, and fade back in. Sliding them home
            //    would undo the story just told.
            withAnimation(.easeOut(duration: 0.28)) { visible = false }
            try? await Task.sleep(for: .milliseconds(300))
            guard !Task.isCancelled else { return }
            topOffset = 0
            bottomOffset = 0
            topCollapsed = false
            topMarked = false
            bottomMarked = false
            withAnimation(.easeIn(duration: 0.32)) { visible = true }
        }
    }
}

/// A bare ⌄ — two strokes meeting at a point, drawn rather than pulled from
/// SF Symbols so it reads as exactly two lines and nothing rounder.
private struct ChevronGlyph: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.midX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        return path
    }
}

// MARK: - Task row

/// See the comment at `taskRow(_:)` for why this is its own view.
///
/// The touch layer is RowGestureView, a UIKit state machine that carries the
/// swipe physics. It is look-agnostic; two things differ here: no
/// pixel-grid snapping of the drag (the skeu look has no pixel grid), and the
/// press reads as the skeu scale-down rather than a tint.
private struct SkeuTaskRow: View {
    /// The tick follows the typeface (see SkeuChromeGlyph), so the row has to
    /// observe it.
    @Environment(AppSettings.self) private var settings
    @Environment(\.skeu) private var skeu
    @Environment(TaskStore.self) private var store
    @Environment(MenuCoordinator.self) private var menu
    @Environment(EditingCoordinator.self) private var editing
    @Environment(ReorderCoordinator.self) private var reorder
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.skeuTextScale) private var textScale
    @Environment(\.skeuChromeScale) private var chromeScale
    let task: TaskItem
    /// The rows this one can be dragged among: its own block, in the order it
    /// is drawn. Handed in rather than looked up, because only the list knows
    /// which block a row belongs to — Soon draws one per day.
    let siblings: [TaskItem]
    /// True for the COPY that floats above the list while this task is being
    /// carried. It is a picture of a row, not a row: it takes no touches, owns
    /// no gestures, and the real one is hidden underneath it.
    ///
    /// A copy is needed because `zIndex` does not order the children of a
    /// `LazyVStack` — measured on 2026-08-23, at 1 and again at 1000, with the
    /// row being passed drawing over the row doing the passing either way. So
    /// the carried row leaves the stack entirely for the length of the drag,
    /// which is also how UIKit has always done it.
    var carried = false

    // Dynamic Type (FR-015): text on the full curve, chrome at half — see
    // SkeuTypeScale for why the two differ.
    private var labelSize: CGFloat { F.label * textScale }
    private var rowH: CGFloat { F.rowHeight * chromeScale }
    private var checkSize: CGFloat { F.check * chromeScale }
    /// How far down the FIRST LINE of the title starts.
    ///
    /// Everything on a row's first-line band — the tick, the day chip, the
    /// grip — centres at `rowH / 2`. A one-line title did too, because its
    /// `minHeight` centred it there; a wrapped one did not, because a title
    /// taller than the band simply began at the top. So the tick read six
    /// points high beside a short task and twelve low beside a long one
    /// (founder bug report 2026-08-23, measured off both).
    ///
    /// Insetting the title by half the leftover puts its first line in the
    /// same band whatever it is worth in lines, which is the one figure that
    /// makes all four agree.
    private var firstLineInset: CGFloat {
        max(0, (rowH - UIFont.systemFont(ofSize: labelSize).lineHeight) / 2)
    }
    private var glyphSize: CGFloat { F.plusIcon * chromeScale }
    private var glyphBox: CGFloat { F.plus * chromeScale }

    @State private var isPressing = false
    @State private var dragOffset: CGFloat = 0
    @State private var rubberBandBuzzed = false
    /// True while the swipe is past the point where letting go commits — see
    /// `swipeChanged`. Kept so the tick fires on the crossing, not every frame.
    @State private var passedThreshold = false
    /// Not @State — see RowFrameBox.
    @State private var frames = RowFrameBox()
    @State private var rowWidth: CGFloat = 390

    // Inline edit
    @State private var isEditing = false
    @State private var draft = ""
    @FocusState private var editFocused: Bool

    // Photos
    @State private var showPhotoPicker = false
    @State private var showCamera = false
    @State private var showSourceChoice = false
    @State private var pickedItem: PhotosPickerItem?
    /// Index into task.allPhotos of the photo open in the viewer.
    @State private var viewerIndex: Int?
    /// Which thumbnail is mid press-in (the tiny open animation).
    @State private var pressedThumb: Int?
    /// The photo waiting on a yes — see the viewer's bin.
    @State private var pendingPhotoDelete: Int?
    /// True while the day list is up.
    @State private var showDayPicker = false
    /// One photo per edit session: the camera retires after a pick and returns
    /// the next time the row enters edit mode.
    @State private var addedPhotoThisEdit = false

    // Swipe commit thresholds — TaskRowView's values verbatim; they are
    // interaction physics, not styling, and the two looks must FEEL identical.
    private static let commitFraction: CGFloat = 0.22
    private static let runwayFraction: CGFloat = 0.5
    private static let commitVelocity: CGFloat = 300
    private static let rubberResistance: CGFloat = 0.3

    /// Held, sliding, holding an open menu, being EDITED, or being DRAGGED to
    /// a new place — the states in which this row is the one being acted on.
    ///
    /// Editing was the odd one out: the row with the caret in it was the only
    /// one you could be working on that did not say so, while a row merely
    /// held down did (founder direction 2026-08-17). Reordering joined the
    /// list on 2026-08-23 for the same reason, and for one of its own — see
    /// the ground below.
    private var isMarked: Bool {
        isPressing || dragOffset != 0 || isEditing
            || menu.request?.taskID == task.id || reorder.isDragging(task.id)
    }

    var body: some View {
        row
            // §8.5: Reduce Motion drops the SCALE but keeps the depth cue —
            // the depth change is the affordance, not decoration. The swipe's
            // own translation is the gesture itself and always follows.
            .scaleEffect(reduceMotion ? 1 : (isPressing ? 0.97 : 1), anchor: .center)
            .animation(reduceMotion ? SkeuMotion.tint : SkeuMotion.press, value: isPressing)
            // The whole row lifts in tone while it is HELD, while it is being
            // SLID, and for as long as its menu is open (founder direction
            // 2026-08-17). Toward the light in the dark and toward the dark in
            // the light — either way it moves away from the page, so the row
            // reads as picked up rather than merely smaller.
            //
            // The menu clause is the one worth naming: the mark used to leave
            // with the finger, so a menu sat open over a row that no longer
            // looked chosen. It is the row the menu belongs to; it stays lit
            // until the menu closes.
            //
            // Behind the content and in front of the catcher: the gesture
            // machine must keep receiving the touch that caused this.
            .background {
                RoundedRectangle(cornerRadius: SkeuRadius.md, style: .continuous)
                    .fill(skeu.isDark ? skeu.materialTop : skeu.recess)
                    .opacity(isMarked ? (skeu.isDark ? 0.55 : 0.35) : 0)
                    .animation(SkeuMotion.tint, value: isMarked)
                    .allowsHitTesting(false)
            }
            // OPAQUE, and only while the row is being carried.
            //
            // A task is plain text on the ground with nothing behind it, which
            // is the whole look — and a row with nothing behind it cannot pass
            // over another one. Dragged, the two titles simply printed on top
            // of each other at the moment they crossed (caught on a frame of
            // the first working drag, 2026-08-23). It takes the page with it
            // for as long as it is off the page.
            .background {
                RoundedRectangle(cornerRadius: SkeuRadius.md, style: .continuous)
                    .fill(skeu.canvas)
                    .opacity(reorder.isDragging(task.id) ? 1 : 0)
                    .animation(ReorderCoordinator.lift, value: reorder.isDragging(task.id))
                    .allowsHitTesting(false)
            }
            // The SLIDE comes after the mark, so the mark slides with it.
            //
            // `offset` moves what is drawn, not the layout frame a background
            // is measured against, so a background attached after it stays
            // exactly where it was: the row travelled out from under its own
            // lit slat and left it standing (founder bug report 2026-08-17).
            // A flat row over a flat ground never needs this — there the row
            // and its ground are the same painted rectangle.
            //
            // The gesture catcher below DOES stay put, on purpose — the touch
            // area belongs to the row's place in the list, not to how far the
            // finger has carried it.
            .offset(x: dragOffset)
            // Touch sandwich: the catcher sits below the content, so the
            // checkbox's own tap gesture wins its touches and everything else
            // lands in the state machine.
            .background(RowGestureView(handlers: handlers))
            .background {
                GeometryReader { proxy in
                    Color.clear
                        .onAppear { rowWidth = proxy.size.width }
                        .onChange(of: proxy.frame(in: .global)) { _, frame in
                            frames.rect = frame
                            // What a row is worth in height is what the rows
                            // behind it close up by — see ReorderCoordinator.
                            reorder.heights.record(frame.height, for: task.id)
                        }
                        .task {
                            frames.rect = proxy.frame(in: .global)
                            reorder.heights.record(proxy.size.height, for: task.id)
                        }
                }
            }
            .onAppear {
                dragOffset = 0 // row identity survives tab switches
                // This row may BE the one that just moved into another day.
                // The old one handed the edit over on its way out; pick it up.
                if editing.reopenTaskID == task.id {
                    editing.reopenTaskID = nil
                    beginEditing()
                }
            }
            .sheet(isPresented: $showDayPicker) {
                SkeuDayPickerSheet(current: task.dueDate) { day in
                    showDayPicker = false
                    pickDay(day)
                }
            }
            .photosPicker(isPresented: $showPhotoPicker, selection: $pickedItem, matching: .images)
            .fullScreenCover(isPresented: $showCamera) {
                CameraPicker { data in
                    showCamera = false
                    guard let data, let prepared = ImageImport.prepare(data) else { return }
                    store.addPhoto(task, data: prepared)
                    addedPhotoThisEdit = true
                }
                .ignoresSafeArea()
            }
            .confirmationDialog("Add photo", isPresented: $showSourceChoice) {
                if UIImagePickerController.isSourceTypeAvailable(.camera) {
                    Button("Camera") { showCamera = true }
                }
                Button("Photo Library") { showPhotoPicker = true }
                Button("Cancel", role: .cancel) {}
            }
            .onChange(of: pickedItem) { _, item in
                guard let item else { return }
                Task { @MainActor in
                    if let data = try? await item.loadTransferable(type: Data.self),
                       let prepared = ImageImport.prepare(data) {
                        store.addPhoto(task, data: prepared)
                        addedPhotoThisEdit = true // the camera retires this session
                    }
                    pickedItem = nil
                }
            }
            .fullScreenCover(isPresented: Binding(
                get: { viewerIndex != nil },
                set: { if !$0 { viewerIndex = nil } }
            )) {
                if let index = viewerIndex, index < task.allPhotos.count {
                    SkeuPhotoViewer(
                        photos: task.allPhotos,
                        index: Binding(get: { viewerIndex ?? index },
                                       set: { viewerIndex = $0 })
                    ) { at in
                        // ASKED first. A photo cannot be recovered, and the
                        // bin sits a thumb's width from the ✕ (founder
                        // direction 2026-08-17).
                        pendingPhotoDelete = at
                    } onClose: {
                        viewerIndex = nil
                    }
                    .overlay {
                        if let at = pendingPhotoDelete {
                            SkeuPinReplaceDialog(
                                outgoing: "",
                                title: "Delete photo",
                                message: "This photo goes for good. The task itself is not touched.",
                                confirmLabel: "Delete",
                                confirmTint: skeu.critical
                            ) {
                                pendingPhotoDelete = nil
                                // Close first, then delete: the viewer is bound
                                // to an INDEX, and removing the photo under it
                                // would leave the binding past the end.
                                viewerIndex = nil
                                store.removePhoto(task, at: at)
                            } onCancel: {
                                pendingPhotoDelete = nil
                            }
                        }
                    }
                    // CLEAR, so what shows behind the photo as it travels off
                    // is the list it came from. A full-screen cover renders
                    // nothing underneath by default, so moving it exposed the
                    // void — the black flash the founder reported on closing
                    // (2026-08-23). The viewer paints its own canvas and takes
                    // it along; this is what it uncovers.
                    .presentationBackground(.clear)
                }
            }
            // VoiceOver (FR-016). The row's whole interaction vocabulary is
            // custom — a UIKit swipe and a press-and-hold menu, neither of
            // which VoiceOver can perform — so every move has to exist as a
            // named action too. Without this the skeu look was a dead end for
            // VoiceOver users: they could tick a task off and nothing more.
            //
            // Collapsed to ONE element only while resting. Doing it during an
            // edit would swallow the TextField and leave no way to reach the
            // caret — the row has to hand its children back the moment it
            // becomes an input.
            .accessibilityElement(children: isEditing ? .contain : .ignore)
            .accessibilityLabel(isEditing ? "" : accessibilityDescription)
            // The DEFAULT action, so a double-tap opens the row for typing the
            // way a tap does for everyone else. Tap-to-edit is routed through
            // the UIKit gesture catcher, which VoiceOver activation does not
            // drive — so without this a VoiceOver user could create a task and
            // delete it but never fix a typo in one (found in review
            // 2026-08-26).
            .accessibilityAction { if !isEditing { beginEditing() } }
            .accessibilityActions { if !isEditing { accessibilityMoveActions } }
    }

    private var currentBucket: Bucket {
        task.bucket(now: store.now(), calendar: store.calendar)
    }

    // MARK: VoiceOver

    private var accessibilityDescription: String {
        var parts = [task.title]
        if task.isImportant { parts.append("important") }
        if let chip = ChipFormat.label(dueDate: task.dueDate, isCompleted: task.isCompleted,
                                       now: store.now(), calendar: store.calendar) {
            parts.append("overdue since \(chip)")
        }
        if !task.allPhotos.isEmpty {
            parts.append(task.allPhotos.count == 1 ? "1 photo"
                                                   : "\(task.allPhotos.count) photos")
        }
        if task.isCompleted { parts.append("completed") }
        return parts.joined(separator: ", ")
    }

    @ViewBuilder
    private var accessibilityMoveActions: some View {
        Button(task.isCompleted ? "Uncomplete" : "Complete") { store.toggleCompleted(task) }
        if !task.isCompleted {
            if currentBucket.steppedOnce(.deferOne) != nil {
                Button("Defer one step") { _ = store.step(task, direction: .deferOne) }
            }
            if currentBucket.steppedOnce(.pullOne) != nil {
                Button("Pull forward one step") { _ = store.step(task, direction: .pullOne) }
            }
            ForEach(currentBucket.menuDestinations, id: \.label) { destination in
                Button("Move to \(destination.bucket.displayName)") {
                    store.move(task, to: destination.bucket)
                }
            }
            Button(task.isImportant ? "Unmark Important" : "Mark as Important") {
                store.toggleImportant(task)
            }
            // REORDERING, which is otherwise a drag on `ReorderGrip` and so
            // reachable by finger only. The grip's own accessibility label was
            // dead code — it renders only when the row is NOT being edited,
            // which is exactly when the row collapses its children away.
            if canMoveUp {
                Button("Move up") { moveByOne(up: true) }
            }
            if canMoveDown {
                Button("Move down") { moveByOne(up: false) }
            }
        }
        // The PHOTOS. The thumbnails are `.allowsHitTesting(false)` and opened
        // by hit arithmetic, so their labels promised a full-screen view that
        // no VoiceOver user could reach.
        ForEach(Array(task.allPhotos.enumerated()), id: \.offset) { index, _ in
            Button("Open photo \(index + 1)") { openViewer(index) }
        }
        Button("Delete") { store.delete(task) }
    }

    /// Where this row sits among the rows it can be reordered against. Nil
    /// when the list did not hand any down — a completed run, or the carried
    /// copy under the finger.
    private var siblingIndex: Int? {
        siblings.firstIndex { $0.id == task.id }
    }

    private var canMoveUp: Bool {
        guard let index = siblingIndex else { return false }
        return index > 0
    }

    private var canMoveDown: Bool {
        guard let index = siblingIndex else { return false }
        return index < siblings.count - 1
    }

    /// One place, in the given direction — the keyboard-and-VoiceOver
    /// equivalent of picking the row up by its grip. Expressed as "which two
    /// rows does it land between", which is what the store's reorder takes.
    private func moveByOne(up: Bool) {
        guard let index = siblingIndex else { return }
        let above: TaskItem?
        let below: TaskItem?
        if up {
            guard index > 0 else { return }
            above = index >= 2 ? siblings[index - 2] : nil
            below = siblings[index - 1]
        } else {
            guard index < siblings.count - 1 else { return }
            above = siblings[index + 1]
            below = index + 2 < siblings.count ? siblings[index + 2] : nil
        }
        withAnimation(SkeuMotion.layout) {
            store.reorder(task, between: above, and: below, visible: siblings)
        }
    }

    private var handlers: RowGestureHandlers {
        RowGestureHandlers(
            onPressChanged: { isPressing = $0 },
            onTap: handleTap,
            onHold: {
                guard !isEditing else { return }
                SkeuHaptic.press()
                menu.show(task: task, rowFrame: frames.rect)
            },
            onSwipeChanged: swipeChanged,
            onSwipeEnded: swipeEnded,
            onSwipeCancelled: swipeCancelled
        )
    }

    /// Routes a tap by WHERE it landed: a thumbnail opens the viewer, anything
    /// else starts an edit. Geometry rather than gestures — the thumbnails are
    /// hit-transparent on purpose, because a photo with its own tap gesture
    /// swallows the whole touch and swiping across it moves nothing.
    private func handleTap(at point: CGPoint) {
        let local = CGPoint(x: point.x - frames.rect.minX, y: point.y - frames.rect.minY)
        if let index = photoIndex(at: local) {
            openViewer(index)
            return
        }
        guard !task.isCompleted, !isEditing else { return }
        beginEditing()
    }

    /// Opens the row for typing. Split out of the tap handler because the row
    /// also opens itself when it arrives carrying a handed-over edit — see
    /// `reopenTaskID`.
    private func beginEditing() {
        draft = task.title
        isEditing = true
        addedPhotoThisEdit = false // fresh session, the camera returns
        // Tells the list where this field sits, so it can be lifted clear of
        // the keyboard if it opens underneath one.
        editing.begin(task.id.uuidString, bottom: frames.rect.maxY)
        // Focus must land AFTER the TextField exists — setting it in the same
        // pass that creates the field is a race.
        Task { @MainActor in editFocused = true }
    }

    /// A day chosen from the calendar while editing.
    ///
    /// Applied AT ONCE, whatever the day: the task appears under that heading
    /// while you are still typing into it, and the edit follows it there,
    /// handed over through `reopenTaskID`.
    ///
    /// Today and Tomorrow used to be HELD until the edit ended, on the
    /// reasoning that a row vanishing mid-word is not an edit continuing
    /// anywhere (founder direction 2026-08-17). That made the rule "the task
    /// moves at once" true only for the dates that happened to stay in Soon —
    /// pick tomorrow and the row sat there unchanged until Return, which is
    /// what the founder came back about (2026-08-22). It moves now, and the
    /// list travels to the tab it moved to rather than letting it vanish.
    /// Dragging the row by its grip.
    ///
    /// `minimumDistance: 0` on purpose: the handle lights up the moment the
    /// finger lands, before anything has moved. Waiting for a threshold would
    /// mean pressing a control that does not answer, which is the one thing a
    /// grip must never do.
    ///
    /// Nothing is written down until the finger lifts. The coordinator holds
    /// the order the list had when the drag began and works out where the row
    /// would land; the store hears about it once.
    private var dragToReorder: some Gesture {
        // GLOBAL space, belt and braces. A drag measured in the row's own
        // space is measured against something the drag itself can move — see
        // `ReorderCoordinator.offset(for:)` for the half-speed this caused.
        // The screen cannot be moved by dragging on it.
        DragGesture(minimumDistance: 0, coordinateSpace: .global)
            .onChanged { value in
                if !reorder.isDragging(task.id) {
                    reorder.begin(task, in: siblings.map(\.id), frame: frames.rect)
                }
                reorder.update(value.translation.height)
            }
            .onEnded { _ in
                let move = reorder.destination()
                let byID = Dictionary(siblings.map { ($0.id, $0) },
                                      uniquingKeysWith: { first, _ in first })
                // The copy flies to the slot FIRST and the real row is
                // uncovered once it is there. Writing the move and dropping
                // the copy in one breath would show the row twice for a frame
                // — once floating, once landed.
                SkeuHaptic.press()
                withAnimation(ReorderCoordinator.drop) { reorder.flyHome() }
                Task { @MainActor in
                    try? await Task.sleep(for: .seconds(ReorderCoordinator.flightTime))
                    if let move, let moved = byID[move.moved] {
                        store.reorder(moved,
                                      between: move.above.flatMap { byID[$0] },
                                      and: move.below.flatMap { byID[$0] },
                                      visible: siblings)
                    }
                    reorder.end()
                }
            }
    }

    private func pickDay(_ day: Date) {
        guard isEditing else {
            withAnimation(SkeuMotion.layout) { store.schedule(task, on: day) }
            return
        }
        let destination = DateEngine.bucket(for: store.calendar.startOfDay(for: day),
                                            now: store.now(), calendar: store.calendar)
        // The text first: the row is about to be rebuilt elsewhere, and its
        // draft does not travel.
        store.editTitle(task, to: draft)
        editing.reopenTaskID = task.id
        // Named unconditionally. The list knows which tab it is showing and
        // ignores a destination it is already on; the row does not.
        editing.followTo = destination
        withAnimation(SkeuMotion.layout) { store.schedule(task, on: day) }
    }

    private func commitEdit() {
        guard isEditing else { return }
        isEditing = false
        editing.end(task.id.uuidString)
        store.editTitle(task, to: draft) // empty draft → store reverts

    }

    /// Return commits instead of adding a line: a vertical-axis TextField
    /// inserts a newline rather than firing onSubmit, so it is intercepted in
    /// the binding — before it lands — and the focus change is deferred a
    /// runloop turn (inline it runs mid-update and SwiftUI drops it).
    private var returnCommitting: Binding<String> {
        Binding(
            get: { draft },
            set: { new in
                guard new.contains("\n") else { draft = new; return }
                draft = new.replacingOccurrences(of: "\n", with: "")
                Task { @MainActor in editFocused = false } // commit follows
            }
        )
    }

    private func chooseSource() {
        if UIImagePickerController.isSourceTypeAvailable(.camera) {
            showSourceChoice = true
        } else {
            showPhotoPicker = true
        }
    }

    /// Which thumbnail (if any) sits under a row-local point. The strip is a
    /// fixed grid — leading inset, square thumbs, even spacing — so this is
    /// arithmetic rather than a hit test.
    private func photoIndex(at local: CGPoint) -> Int? {
        guard !task.allPhotos.isEmpty else { return nil }
        let stripHeight = F.thumb + SkeuSpace.sm
        // The strip is always the bottom band, whatever height the title grew to.
        guard local.y > frames.rect.height - stripHeight else { return nil }

        let leading = SkeuControl.minTouch + F.glassGap
        guard local.x >= leading else { return nil }
        let index = Int((local.x - leading) / (F.thumb + SkeuSpace.sm))
        // Reject the gaps between thumbnails.
        let withinThumb = (local.x - leading)
            .truncatingRemainder(dividingBy: F.thumb + SkeuSpace.sm) <= F.thumb
        guard withinThumb, index >= 0, index < task.allPhotos.count else { return nil }
        return index
    }

    private func openViewer(_ index: Int) {
        pressedThumb = index
        Task { @MainActor in
            // Long enough to SEE the press, short enough to feel instant.
            try? await Task.sleep(for: .milliseconds(140))
            pressedThumb = nil
            var t = Transaction(); t.disablesAnimations = true
            withTransaction(t) { viewerIndex = index }
        }
    }

    /// Swipe left = pull forward (toward Today), right = defer (toward
    /// General) — content follows the finger, matching the tab bar's order.
    /// Swiping LEFT out of Today lands in Live.
    ///
    /// That end of the line used to rubber-band against nothing, and Live sits
    /// exactly there in the bar — one frame left of Today. So the gesture is
    /// already the right shape; it just had no destination until now (founder
    /// direction 2026-08-17).
    private var pullGoesLive: Bool { currentBucket == .today }

    /// A dead end only if the step is impossible AND Live is not the answer.
    private func isDeadEnd(_ direction: StepDirection) -> Bool {
        if direction == .pullOne, pullGoesLive { return false }
        return currentBucket.steppedOnce(direction) == nil
    }

    private func swipeChanged(_ dx: CGFloat) {
        guard !task.isCompleted else { return }
        let direction: StepDirection = dx < 0 ? .pullOne : .deferOne
        if isDeadEnd(direction) {
            // Dead end: rubber-band + one light haptic.
            dragOffset = dx * Self.rubberResistance
            if abs(dx) > 20, !rubberBandBuzzed {
                rubberBandBuzzed = true
                SkeuHaptic.press()
            }
        } else {
            dragOffset = dx
            // Passing the bar is the moment worth feeling — after this,
            // letting go commits. Fires once per crossing, not per frame.
            //
            // Measured against the row alone, not the runway `swipeEnded`
            // uses: the finger's start x is not carried into this handler, and
            // for a HAPTIC the exact bar matters far less than buzzing once,
            // near it, in both looks alike.
            let past = abs(dx) > rowWidth * Self.commitFraction
            if past != passedThreshold {
                passedThreshold = past
                if past { SkeuHaptic.threshold() }
            }
        }
    }

    private func swipeEnded(_ dx: CGFloat, velocity: CGFloat, startX: CGFloat) {
        rubberBandBuzzed = false
        passedThreshold = false
        guard !task.isCompleted else { return }

        let direction: StepDirection = dx < 0 ? .pullOne : .deferOne
        let runway = dx > 0 ? max(1, rowWidth - startX) : max(1, startX)
        let bar = min(rowWidth * Self.commitFraction, runway * Self.runwayFraction)
        let overThreshold = abs(dx) > bar || abs(velocity) > Self.commitVelocity
        let sameSign = (dx < 0) == (velocity < 0) || abs(velocity) < 50

        guard !isDeadEnd(direction), overThreshold, sameSign else {
            withAnimation(.spring(duration: 0.3)) { dragOffset = 0 }
            return
        }

        // Commit: slide off the edge, then the model moves and the list
        // closes the gap.
        SkeuHaptic.press()
        withAnimation(.easeOut(duration: 0.15)) {
            dragOffset = dx < 0 ? -rowWidth * 1.2 : rowWidth * 1.2
        }
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(150))
            withAnimation(.spring(duration: 0.25)) {
                if direction == .pullOne, pullGoesLive {
                    // Asks first when something already holds Live; if it is
                    // cancelled the row simply comes back, because the task
                    // never left Today.
                    menu.goLive(task, store: store)
                } else {
                    _ = store.step(task, direction: direction)
                }
            }
            dragOffset = 0 // row identity survives the move
        }
    }

    private func swipeCancelled() {
        rubberBandBuzzed = false
        guard dragOffset != 0 else { return }
        withAnimation(.spring(duration: 0.3)) { dragOffset = 0 }
    }

    private var row: some View {
        VStack(alignment: .leading, spacing: 0) {
            mainLine
            if !task.allPhotos.isEmpty {
                photoStrip
            }
        }
    }

    private var mainLine: some View {
        // .top: the checkbox belongs on the FIRST line of a wrapped task.
        HStack(alignment: .top, spacing: F.glassGap) {
            // onTapGesture rather than Button, deliberately: an UNCHECKED box
            // is an empty ZStack whose glass layers all carry
            // .allowsHitTesting(false), and a Button over that content never
            // fired on device even with an explicit contentShape (2026-08-13).
            // The tap gesture with its own contentShape is the pattern every
            // other tappable in this screen already uses.
            ZStack {
                if task.isCompleted {
                    // Pixel under Retro and Blend — the tick is furniture, and
                    // a vector one beside bitmap text is the mismatch Blend
                    // exists to avoid. See SkeuChromeGlyph.
                    SkeuChromeGlyph(kind: .check, face: settings.skeuFace,
                                    size: 11, tint: skeu.ink)
                }
            }
            .frame(width: checkSize, height: checkSize)
            .skeuGlass(Circle(), height: checkSize, prominent: task.isCompleted)
            // §3.3 minimum target: the gesture owns the full 44pt square.
            .frame(width: SkeuControl.minTouch, height: SkeuControl.minTouch)
            .contentShape(Rectangle())
            .onTapGesture {
                SkeuHaptic.toggle()
                withAnimation(SkeuMotion.press) { store.toggleCompleted(task) }
            }
            // The first-line band, so the tick centres on the line it belongs
            // to — see `firstLineInset`. The 44pt target above is untouched;
            // this only says where the square sits.
            .frame(height: rowH)
            .accessibilityLabel(task.isCompleted ? "Completed" : "Not completed")
            .accessibilityAddTraits(.isButton)

            if isEditing {
                // Wraps by itself as the text grows — the only way a task
                // gains a line. Return commits (intercepted in the binding).
                TextField("", text: returnCommitting, axis: .vertical)
                    // Semibold as well as red — see the resting title below.
                    .font(SkeuFont.at(labelSize, weight: task.isImportant ? .semibold : .regular))
                    .tracking(-0.02 * F.label)
                    // Important stays red while you edit it — the flag doesn't
                    // pause because the caret is in the field.
                    .foregroundStyle(task.isImportant ? skeu.critical : skeu.ink)
                    .lineLimit(1...6)
                    .focused($editFocused)
                    .submitLabel(.done)
                    // Return arrives EITHER as a "\n" in the binding or as a
                    // submit, depending on the iOS build — see
                    // AddRowView.returnCommitting. Both just drop focus;
                    // `onChange` is the single commit point.
                    .onSubmit { editFocused = false }
                    .onChange(of: editFocused) { _, focused in
                        if !focused { commitEdit() }
                    }
                    .padding(.top, firstLineInset)
                    .frame(minHeight: rowH, alignment: .top)
            } else {
                Text(task.title)
                    // WEIGHT carries importance too, not just hue. Red alone
                    // was the whole marker, so importance vanished entirely in
                    // greyscale and for a colour-blind reader — WCAG 1.4.1
                    // (found in review 2026-08-26). Semibold survives both.
                    .font(SkeuFont.at(labelSize,
                                      weight: task.isImportant && !task.isCompleted
                                          ? .semibold : .regular))
                    .tracking(-0.02 * F.label)
                    // Important stays red — colour carries exactly one
                    // meaning.
                    .foregroundStyle(task.isImportant && !task.isCompleted
                                     ? skeu.critical
                                     : (task.isCompleted ? skeu.inkMuted : skeu.ink))
                    .strikethrough(task.isCompleted, color: skeu.inkMuted)
                    .fixedSize(horizontal: false, vertical: true) // wraps, never truncates
                    .frame(maxWidth: .infinity, alignment: .leading)
                    // INSET first, then the band — see `firstLineInset`. The
                    // one-line case is unchanged; a wrapped title now starts
                    // its first line where a one-line title sits.
                    .padding(.top, firstLineInset)
                    .frame(minHeight: rowH, alignment: .top)
                    .allowsHitTesting(false) // the ROW owns tap-to-edit
            }

            // NO pin here any more. A task becomes live by being typed into
            // the Live section, and that is the only door (founder direction
            // 2026-08-17) — a second way in from every row made "the one
            // thing right now" something you could set by brushing past it.

            // Trailing column: the camera while editing, otherwise the overdue
            // chip. Pinned to the first line's band however tall the row grows.
            if isEditing && !addedPhotoThisEdit {
                // One photo per session.
                // Bare glyph, no glass circle — see the add row's camera.
                Image(systemName: "camera")
                    .font(SkeuFont.at(glyphSize, weight: .medium))
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(skeu.ink)
                    .frame(width: glyphBox, height: glyphBox)
                    .frame(width: SkeuControl.minTouch, height: rowH)
                    .contentShape(Rectangle())
                    .onTapGesture { chooseSource() }
                    .accessibilityLabel("Add photo")
            }

            // The calendar, only in Soon and only while editing (founder
            // direction 2026-08-17). Scheduling is what this tab is for; in
            // Today and Tomorrow the tab already IS the date.
            // Asked of the TASK, not the screen: a row does not know which
            // tab is showing, and its date already answers the question.
            if isEditing, task.bucket(now: store.now(), calendar: store.calendar) == .general {
                Image(systemName: "calendar")
                    .font(SkeuFont.at(glyphSize, weight: .medium))
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(skeu.ink)
                    .frame(width: glyphBox, height: glyphBox)
                    .frame(width: SkeuControl.minTouch, height: rowH)
                    .contentShape(Rectangle())
                    .onTapGesture { SkeuHaptic.press(); showDayPicker = true }
                    .accessibilityLabel("Schedule")
            }

            if !isEditing {
                dayChip
                grip
            }
        }
        // NO surface. A task is plain text on the ground (founder direction
        // 2026-08-13) — only the checkbox is an object. The troughs are reserved for chrome: bars, inputs, panels.
        .padding(.leading, max(0, SkeuSpace.xs - F.edgeNudge))
        .padding(.trailing, max(0, F.padTrail - F.edgeNudge))
        .frame(minHeight: rowH)
    }

    /// The day this task is for, when it has one to state.
    ///
    /// BARE TEXT — no glass, no frame (founder direction 2026-08-14). The chip
    /// states a fact; it is not a control, and a lens around it read as
    /// something you could press. Hit-transparent like the title and the
    /// thumbnails — the row owns the touch.
    @ViewBuilder
    private var dayChip: some View {
        if let chip = ChipFormat.label(dueDate: task.dueDate,
                                       isCompleted: task.isCompleted,
                                       now: store.now(),
                                       calendar: store.calendar) {
            Text(chip)
                .font(SkeuFont.at(labelSize * 0.85, weight: .medium))
                // The "add" placeholder's ink, matching the grip beside it
                // (founder direction 2026-09-01) — see ReorderGrip.
                //
                // It was `ink` at 0.72, chosen to keep the chip at 4.5:1
                // because it is the only place the list says when a task is
                // due. `inkFaint` is 3.4:1, so this trades a little of that
                // legibility for one grey shared by all three quiet things on
                // the row. Recorded in docs/qa-accessibility.md rather than
                // lost.
                .foregroundStyle(skeu.inkFaint)
                // LEADING only — the eight points on its right were the
                // first thing between it and the grip.
                //
                // The rest of that distance belongs to the grip's own touch
                // target. Measured off screen: the glyph is 18.3pt wide inside
                // a 44pt square, so 12.8pt of that square sits empty on its
                // left, and the stack's own 10.2pt gap comes before it — 23pt
                // all told. The founder asked for 40% off (2026-08-23), which
                // is the 9.2 below.
                //
                // NEGATIVE, because the space is not the chip's to give, and
                // AFTER the frame — applied before it, the height frame
                // re-measured and the pull was lost.
                .padding(.leading, SkeuSpace.sm)
                .frame(height: rowH)
                .padding(.trailing, -9.2)
                .allowsHitTesting(false)
                .accessibilityHidden(true) // the row's label already says it
        }
    }

    /// The handle, LAST so the day chip reads to its left (founder direction
    /// 2026-08-23).
    ///
    /// Only on ACTIVE tasks. Done ones are ordered by when they were ticked
    /// rather than by hand, so a handle there would be a control that does
    /// nothing.
    @ViewBuilder
    private var grip: some View {
        if !task.isCompleted {
            // The copy shows a grip that is already lit, and takes no touches:
            // the finger is still on the real one underneath.
            if carried {
                ReorderGrip(isActive: true, size: glyphSize, bandHeight: rowH)
                    .allowsHitTesting(false)
            } else {
                ReorderGrip(isActive: reorder.isDragging(task.id),
                            size: glyphSize, bandHeight: rowH)
                    .gesture(dragToReorder)
            }
        }
    }

    /// Thumbnails accumulate left to right in the order added. Tapping one
    /// presses it in briefly — you see the press — then the viewer opens.
    ///
    /// A plain HStack, NOT a horizontal ScrollView: a nested scroll view owns
    /// horizontal pans, so swiping across a photo would move nothing while
    /// swiping across the text moved the task.
    private var photoStrip: some View {
        HStack(spacing: SkeuSpace.sm) {
            ForEach(Array(task.allPhotos.enumerated()), id: \.offset) { index, data in
                if let image = PhotoCache.image(data) {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .frame(width: F.thumb, height: F.thumb)
                        .clipped()
                        .clipShape(RoundedRectangle(cornerRadius: SkeuRadius.sm,
                                                    style: .continuous))
                        .overlay {
                            // The photo is a carved-in inlay: the same inverted
                            // lighting the troughs use, so it reads as set into
                            // the ground rather than laid on it.
                            RoundedRectangle(cornerRadius: SkeuRadius.sm, style: .continuous)
                                .strokeBorder(
                                    LinearGradient(
                                        colors: [skeu.outline, skeu.outlineLit],
                                        startPoint: .top, endPoint: .bottom),
                                    lineWidth: 1.5)
                        }
                        .scaleEffect(pressedThumb == index ? 0.92 : 1)
                        .animation(.easeOut(duration: 0.1), value: pressedThumb)
                        // Hit-transparent, exactly like the title: a foreground
                        // view with its own tap gesture takes the whole touch,
                        // and swiping across a photo would move nothing. The
                        // catcher behind owns every touch; taps route by region.
                        .allowsHitTesting(false)
                        .accessibilityLabel("Photo \(index + 1), opens full screen")
                }
            }
            Spacer(minLength: 0)
        }
        .padding(.leading, SkeuControl.minTouch + F.glassGap)
        .padding(.trailing, F.padTrail)
        // A STATED gap above the strip. There was none: the space over a
        // photo was whatever the title's `minHeight` happened to leave, and a
        // title that wraps uses all of it — so a one-line task sat well clear
        // of its photo and a long one landed right on top of it (founder bug
        // report 2026-08-23).
        .padding(.top, SkeuSpace.sm)
        .padding(.bottom, SkeuSpace.sm)
    }
}

// MARK: - Photo viewer

/// Full-screen photo: it simply sits on the canvas with one glass ✕. There is
/// no window metaphor in this look to honour, so it gets no furniture.
private struct SkeuPhotoViewer: View {
    @Environment(\.skeu) private var skeu
    /// Dynamic Type — the viewer's controls scale with the rest of the chrome.
    @Environment(\.skeuChromeScale) private var chromeScale
    let photos: [Data]
    @Binding var index: Int
    /// Removing a photo was reachable from ONE viewer only — the other look's
    /// — so `store.removePhoto` had a single caller and a photo attached here
    /// could not be deleted without switching design (found in the 2026-08-16
    /// audit, control placed by founder direction).
    var onRemove: (Int) -> Void
    var onClose: () -> Void

    /// True once the reader has pinched in. The way out is a downward drag,
    /// and while zoomed that is how you look at the bottom of the picture.
    @State private var isZoomed = false

    var body: some View {
        ZStack {
            skeu.canvas.ignoresSafeArea()

            // A PAGER, not one photo. A task can carry several, and the strip
            // in the row is a poor place to go between them once they are
            // open (founder direction 2026-08-17). Dots only when there is
            // more than one — a single photo should not advertise a choice
            // that does not exist.
            //
            // A zoomable view — pinch, pan and Live Text selection. This was
            // a plain Image, so a photo of a receipt could be opened but
            // neither enlarged nor read from.
            //
            // FULL BLEED: no side padding. A photo is the content here, and
            // the canvas around it was frame for frame's sake.
            TabView(selection: $index) {
                ForEach(Array(photos.enumerated()), id: \.offset) { offset, data in
                    if let image = PhotoCache.image(data) {
                        ZoomableImageView(image: image) { zoomed in
                            isZoomed = zoomed
                        }
                        .tag(offset)
                    }
                }
            }
            .tabViewStyle(.page(indexDisplayMode: photos.count > 1 ? .automatic : .never))
            .ignoresSafeArea()

            HStack(spacing: SkeuSpace.sm) {
                control("trash", label: "Delete photo", tint: skeu.critical) {
                    SkeuHaptic.warning()
                    onRemove(index)
                }
                control("xmark", label: "Close photo", tint: skeu.ink) {
                    SkeuHaptic.press()
                    onClose()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
            .padding(SkeuSpace.xl)
        }
        // The same two ways out as every full-screen sheet, on the same
        // distances, the same curve and the same haptic (founder direction
        // 2026-08-23) — the ✕ was the only exit here.
        //
        // The band is the WHOLE screen rather than a header: there is no
        // scroll view under it to take a downward drag away from, and a swipe
        // down is already what a picture means.
        //
        // A CLEAR backdrop, unlike the sheets. Those travel over their own
        // canvas colour because that is what sits behind them; here what sits
        // behind is the list, and painting anything over it is the black
        // screen this was meant to avoid. See the cover's presentation
        // background.
        .swipeToDismiss(headerHeight: .infinity,
                        enabled: !isZoomed,
                        allowsEdge: index == 0,
                        backdrop: .clear,
                        onClose)
    }

    /// FROSTED, unlike every other glass piece in the app. These two sit on
    /// top of a photograph rather than on the app's own ground — clear glass
    /// let the picture read straight through the glyph, and a photo can be
    /// any colour at all, so no fixed tint would have held. Blurring the
    /// backdrop gives the glyph a stable ground whatever is behind it.
    private func control(_ symbol: String,
                         label: String,
                         tint: Color,
                         action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                // The SAME icon size as the gear and the sheet ✕ — the circles
                // already share one figure, and a glyph a third smaller inside
                // an identical circle reads as a different control (founder
                // bug report 2026-08-17).
                .font(SkeuFont.at(SkeuTopBar.icon * chromeScale, weight: .medium))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(tint)
                .frame(width: SkeuTopBar.control, height: SkeuTopBar.control)
                .skeuGlass(Circle(), height: SkeuTopBar.control, frosted: true)
                // The glass takes no hits, so without this only the glyph's own
                // ink is tappable.
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .frame(minWidth: SkeuControl.minTouch, minHeight: SkeuControl.minTouch)
        .accessibilityLabel(label)
    }
}


// MARK: - Day picker

/// The next four weeks, one row per day. See `DayPickerRange` for why a list
/// rather than a month grid, and why there is no "no date" row.
private struct SkeuDayPickerSheet: View {
    @Environment(\.skeu) private var skeu
    @Environment(\.skeuTextScale) private var textScale
    @Environment(\.skeuChromeScale) private var chromeScale
    @Environment(TaskStore.self) private var store
    /// Marked in the grid, so picking again is a change rather than a guess.
    let current: Date?
    let onPick: (Date) -> Void

    private var chosen: Date? { current.map { store.calendar.startOfDay(for: $0) } }
    private var today: Date { store.calendar.startOfDay(for: store.now()) }

    /// Which month is on show. The sheet pages rather than scrolls, so this is
    /// the only thing that moves — see DayPicker.swift.
    @State private var monthIndex = 0

    private var months: [Date] {
        DayPickerRange.monthStarts(now: today, calendar: store.calendar)
    }

    /// The sheet's own height, measured from what it holds. A `.medium` detent
    /// cut the last week off the month; `.large` fixed that by taking the whole
    /// screen, which is far more room than a month needs (founder direction
    /// 2026-08-17). Measured, the sheet is exactly as tall as the calendar.
    @State private var sheetHeight: CGFloat = 520

    var body: some View {
        ZStack(alignment: .top) {
            skeu.canvas.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: SkeuSpace.lg) {
                    shortcuts
                    if monthIndex < months.count {
                        monthBlock(months[monthIndex])
                    }
                }
                .padding(.horizontal, SkeuSpace.xl)
                .padding(.vertical, SkeuSpace.lg)
                // In a BACKGROUND, never as a wrapper: a GeometryReader that
                // wraps content lays it out rather than measuring it, which is
                // how four screens once lost their headers under the status bar.
                .background {
                    GeometryReader { proxy in
                        Color.clear
                            .task { sheetHeight = proxy.size.height + bottomSlack }
                            .onChange(of: proxy.size.height) { _, h in
                                sheetHeight = h + bottomSlack
                            }
                    }
                }
            }
            .scrollBounceBehavior(.basedOnSize)
        }
        .presentationDetents([.height(sheetHeight)])
    }

    /// Room under the grid for the home indicator, so the last week is not
    /// sitting on the bezel.
    private var bottomSlack: CGFloat { SkeuSpace.lg + 34 }

    /// Today and Tomorrow, above the grid. They are answers people give
    /// without thinking about dates, so they should not require finding one.
    ///
    /// Both carry the row menu's arrows, which say how far along the line the
    /// task travels: `<` one step toward Today, `<<` two. The picker only ever
    /// opens on a task in Soon, so Tomorrow is one step back and Today is two —
    /// the same grammar, and the same shove, as holding a row down.
    private var shortcuts: some View {
        let height = SkeuToggle.height * chromeScale
        let tomorrow = store.calendar.date(byAdding: .day, value: 1, to: today) ?? today

        return VStack(spacing: SkeuSpace.xs) {
            shortcut("<< Today", day: today, height: height)
            shortcut("< Tomorrow", day: tomorrow, height: height)
        }
    }

    private func shortcut(_ title: String, day: Date, height: CGFloat) -> some View {
        Text(title)
            .font(SkeuFont.at(SkeuToggle.label * textScale, weight: .medium))
            .foregroundStyle(skeu.ink)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, SkeuSpace.lg)
            .frame(height: height)
            .skeuGlass(Capsule(), height: height, prominent: day == chosen)
            .contentShape(Capsule())
            .skeuPress { onPick(day) }
            .accessibilityAddTraits(day == chosen ? [.isButton, .isSelected] : .isButton)
    }

    /// The month's name between two chevrons, holding still above the grid.
    private func monthHeader(_ month: Date) -> some View {
        HStack(spacing: 0) {
            chevron("chevron.left", enabled: monthIndex > 0) { monthIndex -= 1 }

            Text(DayPickerRange.title(for: month, calendar: store.calendar))
                .font(SkeuFont.at(SkeuToggle.label * textScale * 1.32, weight: .semibold))
                .foregroundStyle(skeu.ink)
                .lineLimit(1)
                .frame(maxWidth: .infinity)

            chevron("chevron.right",
                    enabled: monthIndex < DayPickerRange.months - 1) { monthIndex += 1 }
        }
    }

    /// Faded rather than hidden at the ends of the range: a control that
    /// vanishes moves the month's name, and the name is what you are reading.
    private func chevron(_ symbol: String, enabled: Bool,
                         step: @escaping () -> Void) -> some View {
        Image(systemName: symbol)
            .font(SkeuFont.at(SkeuToggle.label * textScale, weight: .medium))
            .symbolRenderingMode(.hierarchical)
            .foregroundStyle(skeu.ink)
            .frame(width: SkeuControl.minTouch, height: SkeuControl.minTouch)
            .opacity(enabled ? 1 : 0.25)
            .contentShape(Rectangle())
            .skeuPress { if enabled { step() } }
            .accessibilityLabel(symbol == "chevron.left" ? "Previous month" : "Next month")
    }

    private func monthBlock(_ month: Date) -> some View {
        VStack(alignment: .leading, spacing: SkeuSpace.sm) {
            monthHeader(month)

            HStack(spacing: 0) {
                ForEach(DayPickerRange.weekdayHeaders, id: \.self) { day in
                    Text(day)
                        .font(SkeuFont.at(SkeuToggle.label * textScale * 0.78))
                        .foregroundStyle(skeu.inkFaint)
                        .frame(maxWidth: .infinity)
                }
            }

            let cells = DayPickerRange.grid(for: month, calendar: store.calendar)
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 0), count: 7),
                      spacing: SkeuSpace.xs) {
                ForEach(Array(cells.enumerated()), id: \.offset) { _, day in
                    if let day { dayCell(day) } else { Color.clear.frame(height: 1) }
                }
            }
        }
    }

    private func dayCell(_ day: Date) -> some View {
        let size = 38 * chromeScale
        let isChosen = day == chosen
        // A day already gone is not a schedule, it is a mistake waiting to
        // happen — shown, so the month reads as a month, but not tappable.
        let isPast = day < today

        return Text("\(store.calendar.component(.day, from: day))")
            .font(SkeuFont.at(SkeuToggle.label * textScale, weight: isChosen ? .semibold : .regular))
            .foregroundStyle(isPast ? skeu.inkFaint : skeu.ink)
            .frame(width: size, height: size)
            .background {
                if isChosen {
                    Circle().fill(.clear).skeuGlass(Circle(), height: size, prominent: true)
                }
            }
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
            .skeuPress { if !isPast { onPick(day) } }
            .opacity(isPast ? 0.45 : 1)
            .accessibilityAddTraits(isChosen ? [.isButton, .isSelected] : .isButton)
    }
}
