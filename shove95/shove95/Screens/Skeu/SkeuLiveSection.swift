//
//  SkeuLiveSection.swift
//  shove95
//
//  The Live tab's own screen: one box, one line of text.
//
//  It is not a list (founder direction 2026-08-17). The other three tabs
//  divide the date line between them and each holds however many tasks fall in
//  its range; this holds exactly one thing, the thing you are doing, and it
//  shows it the size that deserves.
//
//  The live note lives HERE and in no tab — see `TaskItem.isLiveNote`. Typing
//  it puts it on the Lock Screen straight away, because that is the whole
//  point of typing it. The switch afterwards controls only whether it is still
//  showing there; the text stays in this box either way. The bin is what
//  deletes.
//
//  There is no tick. Finishing a live task is something you do from the Lock
//  Screen without opening the app — that is what makes it worth putting there
//  — and a second tick in here would be a second place to look.
//

import SwiftUI
import Shove95Kit

struct SkeuLiveSection: View {
    @Environment(\.skeu) private var skeu
    @Environment(\.skeuTextScale) private var textScale
    @Environment(\.skeuChromeScale) private var chromeScale
    @Environment(TaskStore.self) private var store
    /// Asked of the coordinator so the ROOT draws the dialog — see
    /// `MenuCoordinator.pendingLiveDelete`.
    @Environment(MenuCoordinator.self) private var menu

    /// What is being typed before it becomes the note. Empty when a note
    /// already exists — the box shows that instead.
    @State private var draft = ""

    @FocusState private var focused: Bool

    /// How far the keyboard eats into this screen, and the curve it travels
    /// on — read off the keyboard's own notification, see `KeyboardDock`.
    ///
    /// The tab bar and the workspace bar are furniture and deliberately hold
    /// still under the keyboard, which is why the screen around them ignores
    /// the keyboard safe area entirely. That leaves this box knowing nothing
    /// about the keyboard: it stayed its resting size with the keyboard drawn
    /// over the bottom of it (founder direction 2026-08-22, against MonoNote,
    /// where the field takes the whole space above the keys).
    @State private var keyboardOverlap: CGFloat = 0
    /// This screen's own clearance from the bottom of the display, so the
    /// keyboard is not counted twice — see `KeyboardDock.read`.
    @State private var bottomGap: CGFloat = 0
    /// The last duration the keyboard actually named.
    ///
    /// It names one on the way UP and reports ZERO on the way down — measured
    /// 0.383 then 0.000 (2026-08-23). A keyboard dismissed from code rather
    /// than by a finger apparently has nothing to say about how long it will
    /// take, and the box was reading that zero as "do not animate": the whole
    /// reason the glide shut never appeared however the curve was written.
    /// The trip back is timed by the trip out.
    @State private var lastDuration: Double = 0.32

    /// Whether the box is filling the space above the keyboard.
    ///
    /// Keyed on the KEYBOARD rather than on focus, so growing and the keys
    /// arriving are one movement on one curve. Focus alone would snap the box
    /// open while the keyboard was still sliding, and with a hardware keyboard
    /// there is no space above anything to fill.
    private var isExpanded: Bool { keyboardOverlap > 0 }

    private var note: TaskItem? { store.liveNote() }
    private var textSize: CGFloat { 22 * textScale }
    /// Every control down here is the height of the ✕ and the gear.
    ///
    /// The bin is a circle at exactly their size, so the three round controls
    /// in the app are one family; the pills beside it take the same height so
    /// the row has a single baseline (founder direction 2026-08-17).
    private var buttonH: CGFloat { SkeuTopBar.control * chromeScale }
    private var binIcon: CGFloat { SkeuTopBar.icon * chromeScale }

    var body: some View {
        // The height is COMPUTED from the space this screen was handed, not
        // asked for with `.infinity` and a bottom padding. That first attempt
        // fed back on itself: the box's own growth pushed the frame it was
        // measuring its clearance from, which shrank the clearance, which
        // asked for more growth — until it had climbed over the workspace bar
        // and the gear, which the founder wants left where they are
        // (2026-08-22). A slot cannot be moved by what is put in it.
        GeometryReader { geo in
            VStack(spacing: SkeuSpace.lg) {
                box(height: boxHeight(in: geo))
                // Directly under the box, not pushed to the floor (founder
                // direction 2026-08-17). They act on what is IN the box, and a
                // control parked at the far end of the screen reads as
                // belonging to the screen instead.
                controls
            }
            // Everything that moves is a NUMBER — this lead and the box's
            // height. It was a pair of spacers and a top/centre alignment
            // flip, and neither of those is a value SwiftUI can travel
            // through: the layout arrived at its destination in one frame
            // whatever animation it was given, which is what the founder saw
            // on the way shut (2026-08-22).
            .padding(.top, SkeuSpace.xl + topLead(in: geo))
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .padding(.bottom, SkeuSpace.xl)
            .bottomGapToScreen($bottomGap)
            .onReceive(NotificationCenter.default.publisher(
                for: UIResponder.keyboardWillChangeFrameNotification)) { note in
                guard let change = KeyboardDock.read(note, clearance: bottomGap) else { return }
                if change.duration > 0 { lastDuration = change.duration }
                withAnimation(motion(for: change)) { keyboardOverlap = change.overlap }
            }
        // A downward drag anywhere puts the keyboard away, which is the
        // gesture every reader already has in their hand. There is no scroll
        // view here to hand that job to.
        .contentShape(Rectangle())
        .simultaneousGesture(
            DragGesture(minimumDistance: 24)
                .onEnded { value in
                    if value.translation.height > 40 { focused = false }
                }
        )
        } // GeometryReader
    }

    /// How the box travels, which is not the same going each way (founder
    /// direction 2026-08-22).
    ///
    /// Opening SPRINGS with some bounce: the box is being thrown open by the
    /// keys arriving under it, and a little overshoot is what that reads as.
    /// Closing EASES OUT, so the box settles back rather than being back —
    /// the founder's complaint was that it simply reappeared at its resting
    /// size.
    ///
    /// It ran at 1.45× the keyboard's own duration and was cut by 30% at the
    /// founder's word once it could be seen at all (2026-08-23). What is left
    /// is 1.015 — near enough the keyboard's own time, which is a reasonable
    /// place for it to have landed: the box arrives as the keys do.
    ///
    /// Both take the keyboard's own DURATION as their base, so neither drifts
    /// away from the keys it is moving with — and when it names none, the one
    /// it named last time. See `lastDuration` for why that is not a detail.
    private func motion(for change: KeyboardDock.Change) -> Animation {
        let base = change.duration > 0 ? change.duration : lastDuration
        if change.overlap > 0 {
            return .spring(response: base, dampingFraction: 0.62)
        }
        return .easeOut(duration: base * 1.015)
    }

    /// The box's resting size: one line, shown at the size it deserves.
    private var restingHeight: CGFloat { 260 * chromeScale }

    /// How far down the stack starts.
    ///
    /// Zero when expanded — the box begins right under the workspace bar and
    /// runs to the keys. At rest it is whatever centres the stack, computed
    /// rather than left to a spacer so the two positions are one number with
    /// two values and the trip between them can be animated.
    private func topLead(in geo: GeometryProxy) -> CGFloat {
        guard !isExpanded else { return 0 }
        let room = geo.size.height - SkeuSpace.xl * 2
        let content = restingHeight + SkeuSpace.lg + buttonH
        return max(0, (room - content) / 2)
    }

    /// How tall the box may grow, given the space this screen was handed.
    ///
    /// Everything that has to keep its room is subtracted by name, so the sum
    /// can be read rather than trusted. Never below the resting size: on a
    /// short screen under a tall keyboard the box holds its size and the
    /// keyboard covers what it covers, which is what it did before any of
    /// this.
    private func boxHeight(in geo: GeometryProxy) -> CGFloat {
        guard isExpanded else { return restingHeight }
        let spokenFor = SkeuSpace.xl * 2   // this screen's own top and bottom
                      + SkeuSpace.lg       // the gap down to the controls
                      + buttonH            // the controls themselves
                      + keyboardOverlap    // and the keys
        return max(restingHeight, geo.size.height - spokenFor)
    }

    // MARK: The box

    /// A trough, not a card: this is a place a thing SITS, cut into the page,
    /// which is the same reading every field in the app gets.
    private func box(height: CGFloat) -> some View {
        let shape = RoundedRectangle(cornerRadius: SkeuRadius.lg, style: .continuous)

        return TextField("", text: $draft,
                         prompt: Text("What are you doing?")
                            .foregroundStyle(skeu.inkFaint),
                         axis: .vertical)
            .font(SkeuFont.at(textSize, weight: .medium))
            .foregroundStyle(skeu.ink)
            .multilineTextAlignment(.center)
            .focused($focused)
            // Return CLOSES the field, having written what is in it. The
            // keyboard's blue key is the way out of a box that is otherwise
            // always open (founder direction 2026-08-17).
            .submitLabel(.done)
            .onSubmit { commit(); focused = false }
            // RETURN, caught by hand. A field on the vertical axis treats the
            // blue key as a newline and never calls `onSubmit`, so the only
            // way out of the keyboard was to leave the tab (founder bug report
            // 2026-08-17). Wrapping is worth keeping — a live note can run to
            // two lines — so the newline is intercepted rather than the axis
            // given up.
            .onChange(of: draft) { _, new in
                guard new.contains("\n") else { return }
                draft = new.replacingOccurrences(of: "\n", with: " ")
                    .trimmingCharacters(in: .whitespaces)
                commit()
                focused = false
            }
            // Leaving by any other route writes too — tapping away from a
            // half-typed thought should not throw it away.
            .onChange(of: focused) { _, isFocused in
                if !isFocused { commit() }
            }
            // The box shows what IS live whenever you are not the one
            // changing it, so a note arriving from another device lands here.
            .task(id: note?.id) { if !focused { draft = note?.title ?? "" } }
            .onChange(of: note?.title) { _, new in
                if !focused { draft = new ?? "" }
            }
        .frame(maxWidth: .infinity)
        .padding(SkeuSpace.xl)
        // STATED, both ways. This was a `minHeight` with the ceiling left off
        // at rest, and an absent ceiling is not a value: SwiftUI had nothing
        // to travel from, so the box arrived back at its resting size in a
        // single frame however it was animated — measured at two frames on the
        // way shut, against roughly twenty for the same trip now (2026-08-22).
        // 260pt over a 22pt line is six lines of room, so nothing that belongs
        // in this box needs the ceiling lifted.
        .frame(height: height)
        // The rim is stated at CONTROL size, not at the box's own.
        //
        // `skeuTrough` scales every inset by `height / 148.2`, so handing it
        // the real 260 drew the channel at nearly twice weight and the box
        // read as a thick picture frame (founder bug report 2026-08-17). The
        // depth of a channel does not grow with the thing sitting in it.
        // The ramp finishes in the top quarter and the floor tone holds the
        // rest, and the inner shadows come down to two thirds. At full weight
        // over 260pt the upper half read as gloom rather than a lip (founder
        // bug report 2026-08-17).
        .skeuTrough(shape, height: 64, fillStop: 0.26, shadeScale: 0.65,
                    fillLift: 0.55)
        // The whole trough is the field. The text line is one line in a box a
        // few hundred points tall, and a tap on the empty ground under it did
        // nothing (founder direction 2026-08-17). The TextField still wins
        // taps on the text itself; this catches the rest of the box.
        .contentShape(shape)
        .onTapGesture { focused = true }
        .padding(.horizontal, SkeuSpace.xl)
    }

    // MARK: The controls

    @ViewBuilder
    private var controls: some View {
        HStack(spacing: SkeuSpace.md) {
            if note != nil {
                // Live or merely held in the box — the switch says which.
                liveSwitch(on: note?.isPinned ?? false) {
                    withAnimation(SkeuMotion.tint) {
                        store.setLiveOnLockScreen(!(note?.isPinned ?? false))
                    }
                }
            } else if !draft.isEmpty {
                // The field is always open, so this is not "start typing" any
                // more — it is "send what I typed".
                pill(label: "Go", filled: true) { commit(); focused = false }
            } else {
                // NOTHING is live, so the control says exactly that (founder
                // bug report 2026-09-01). It used to read "Go Live" here,
                // which is the one state where the app had no live note at
                // all: a fresh install opened on a button promising a thing
                // rather than a switch reporting one, and the word never seen
                // on first launch was the true one. Same switch, same muted
                // contents; tapping it puts the cursor in the box, which is
                // the only way to reach the on state from here.
                liveSwitch(on: false) { focused = true }
            }

            // ALWAYS present now. It used to appear only alongside a note, so
            // the row's shape changed as you typed and the two controls jumped
            // width (founder direction 2026-09-01). It greys out instead.
            bin
        }
        // TWO THIRDS of the screen, centred. Run edge to edge these two read
        // as a bar across the bottom of the section rather than as the pair of
        // controls belonging to the box above them (founder direction
        // 2026-08-17).
        .containerRelativeFrame(.horizontal, alignment: .center) { width, _ in
            width * 0.68
        }
        .animation(SkeuMotion.layout, value: note?.id)
    }

    /// Reads as what it CONTROLS, not as what it will do: lit when the note is
    /// on the Lock Screen, dark when it is only in this box — and dark, saying
    /// "Off air", when there is no note at all.
    ///
    /// Takes its state and its action rather than reading `note` itself, so
    /// the empty screen can wear the same control. The alternative was a
    /// second view that looked identical and would drift.
    private func liveSwitch(on: Bool, action: @escaping () -> Void) -> some View {
        HStack(spacing: SkeuSpace.sm) {
            LiveGlyph(tint: on ? skeu.accent : skeu.inkMuted,
                      lineWidth: 1.7 * chromeScale)
                .frame(width: buttonH * 0.42, height: buttonH * 0.42)
            Text(on ? "Live" : "Off air")
                .font(SkeuFont.at(SkeuToggle.label * textScale, weight: .medium))
                .foregroundStyle(on ? skeu.ink : skeu.inkMuted)
        }
        // The MARK and the WORD breathe together, the same breath the tab
        // shows (founder direction 2026-08-17). The glass holds still: the
        // button is not what is on air, its contents are what say so.
        .skeuPulse(on)
        // Off air, the CONTENTS recede — mark and word together. Applied here
        // rather than to the finished control, so the glass keeps its full
        // strength: the capsule is the button, and fading it made the whole
        // thing read as disabled (founder direction 2026-08-17).
        .opacity(on ? 1 : 0.55)
        .animation(SkeuMotion.tint, value: on)
        .padding(.horizontal, SkeuSpace.lg)
        .frame(height: buttonH)
        .frame(maxWidth: .infinity)
        // Prominent in BOTH states. `prominent: on` drew the capsule itself at
        // a weaker glass step when off air, so the frame washed out alongside
        // its label even after the opacity was moved off it (founder bug
        // report 2026-08-17). The state is carried entirely by the mark and
        // the word now; the button looks like a button either way.
        .skeuGlass(Capsule(), height: buttonH, prominent: true)
        .contentShape(Capsule())
        .skeuPress { action() }
        .accessibilityAddTraits(on ? [.isButton, .isSelected] : .isButton)
        .accessibilityLabel(on ? "Showing on the Lock Screen" : "Not on the Lock Screen")
    }

    /// Whether there is anything in the box to throw away.
    ///
    /// Asked of the DRAFT rather than of `note`, because the bin answers to
    /// what is written in front of you: text cleared but not yet committed
    /// reads as an empty box, and a live bin beside an empty box is a control
    /// with nothing to act on.
    private var hasText: Bool {
        !draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var bin: some View {
        Image(systemName: "trash")
            .font(.system(size: binIcon * 0.72))
            .foregroundStyle(skeu.ink)
            // GREYED when the box is empty, at exactly the weight the off-air
            // switch beside it uses, and inert with it (founder direction
            // 2026-09-01).
            //
            // Its own note from 2026-08-17 argued the opposite — full ink
            // always, so it would not be mistaken for the muted "not on air"
            // state next to it. That held while the bin only ever appeared
            // beside a note, when there was always something to delete. Now it
            // is always on screen, and half the time there is nothing: the
            // grey is no longer borrowing the switch's meaning, it is stating
            // its own.
            .opacity(hasText ? 1 : 0.55)
            .animation(SkeuMotion.tint, value: hasText)
            .frame(width: buttonH, height: buttonH)
            .skeuGlass(Circle(), height: buttonH)
            // A filled Circle is hittable only where the ink lands.
            .contentShape(Circle())
            .skeuPress { if hasText { menu.pendingLiveDelete = true } }
            // The press animation is part of the affordance, so the whole
            // control stops taking touches rather than swallowing them and
            // looking alive.
            .allowsHitTesting(hasText)
            .accessibilityAddTraits(.isButton)
            .accessibilityLabel("Delete")
            .accessibilityHidden(!hasText)
    }

    private func pill(label: String, filled: Bool,
                      action: @escaping () -> Void) -> some View {
        HStack(spacing: SkeuSpace.sm) {
            LiveGlyph(tint: skeu.ink, lineWidth: 1.7 * chromeScale)
                .frame(width: buttonH * 0.42, height: buttonH * 0.42)
            Text(label)
                .font(SkeuFont.at(SkeuToggle.label * textScale, weight: .medium))
                .foregroundStyle(skeu.ink)
        }
        .padding(.horizontal, SkeuSpace.xl)
        .frame(height: buttonH)
        .skeuGlass(Capsule(), height: buttonH, prominent: filled)
        .contentShape(Capsule())
        .skeuPress(action)
        .accessibilityAddTraits(.isButton)
    }

    private func commit() {
        let text = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else {
            // EMPTYING THE BOX ENDS THE NOTE (founder bug report 2026-09-01).
            //
            // This used to return here, which left the note exactly as it was:
            // still live, still on the Lock Screen, still carrying the words
            // you had just rubbed out. The box in front of you and the card on
            // the Lock Screen disagreed, and the box was the one you had told
            // the truth to.
            //
            // At COMMIT rather than on every keystroke — clearing the line to
            // retype it is an ordinary thing to do mid-edit, and ending the
            // note under the cursor would be its own bug. Leaving the field,
            // or pressing Return, is the point at which an empty box means it.
            if note != nil {
                SkeuHaptic.warning()
                withAnimation(SkeuMotion.layout) { store.clearLiveNote() }
            }
            return
        }
        // Renames what is there rather than replacing it, so editing the text
        // of something already live does not flick it off the Lock Screen and
        // back on. Silent when nothing changed.
        guard text != note?.title else { return }
        SkeuHaptic.success()
        withAnimation(SkeuMotion.layout) { _ = store.writeLiveNote(text) }
    }
}

// MARK: - Demonstration for How to use

/// The Live switch alone, changing state on a loop.
///
/// It lives HERE, next to the control it mirrors, for the reason the other two
/// demos live next to theirs: it is built out of this file's `buttonH` and the
/// same tokens as `liveSwitch`, and a picture of a control that drifts from
/// the control is worse than no picture.
///
/// The round Live TAB stood beside it until 2026-09-01, pulsing in step. It
/// went at the founder's word: the block is about going live, and the tab is
/// how you reach the screen rather than part of the thing being explained —
/// two round marks side by side asked the reader to tell apart two controls
/// where the page only names one.
///
/// Inert and hidden from VoiceOver: the block's own words carry the meaning.
struct SkeuGoLiveDemo: View {
    @Environment(\.skeu) private var skeu
    @Environment(\.skeuTextScale) private var textScale
    @Environment(\.skeuChromeScale) private var chromeScale
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// STARTS LIT (founder direction 2026-09-01). The block is called "Go
    /// live" and its words describe a task reaching the Lock Screen, so the
    /// first thing a reader sees should be the state that describes — and
    /// "Off air" as the opening frame answered a question nobody had asked
    /// yet.
    @State private var on = true
    /// The swell of the tap that is being demonstrated. A control that
    /// changed state without ever appearing to be pressed read as changing by
    /// itself, which is not what the block is describing (founder bug report
    /// 2026-09-01).
    @State private var pressed = false

    private var buttonH: CGFloat { SkeuTopBar.control * chromeScale }

    var body: some View {
        liveSwitch
            .accessibilityHidden(true)
            .task(id: reduceMotion) { await run() }
    }

    /// The switch above, minus its gesture — same mark, same word, same
    /// recede-when-off treatment on the contents rather than on the glass.
    private var liveSwitch: some View {
        HStack(spacing: SkeuSpace.sm) {
            LiveGlyph(tint: on ? skeu.accent : skeu.inkMuted,
                      lineWidth: 1.7 * chromeScale)
                .frame(width: buttonH * 0.42, height: buttonH * 0.42)

            // The longer word RESERVES the width, so the pill is one size in
            // both states (founder direction 2026-09-01). On the home screen
            // this control is `maxWidth: .infinity` inside a fixed container,
            // so it never moves; hugging its text here made it grow and shrink
            // on every toggle, which the real one never does. Measured from
            // the word rather than hard-coded, so it still follows Dynamic
            // Type.
            ZStack {
                Text("Off air").hidden()
                Text(on ? "Live" : "Off air")
                    .foregroundStyle(on ? skeu.ink : skeu.inkMuted)
                    // A hard swap: a cross-fade draws both words at once.
                    .contentTransition(.identity)
            }
            .font(SkeuFont.at(SkeuToggle.label * textScale, weight: .medium))
        }
        .skeuPulse(on)
        .opacity(on ? 1 : 0.55)
        .animation(SkeuMotion.tint, value: on)
        .padding(.horizontal, SkeuSpace.lg)
        .frame(height: buttonH)
        .skeuGlass(Capsule(), height: buttonH, prominent: true)
        .fixedSize()
        // `SkeuPress`'s own figures, so the demonstrated tap and a real one
        // are the same movement.
        .scaleEffect(reduceMotion ? 1 : (pressed ? SkeuMotion.pressGrow : 1))
        .animation(reduceMotion ? SkeuMotion.tint : SkeuMotion.pressSwell,
                   value: pressed)
    }

    private func run() async {
        // Reduce Motion holds it OFF rather than slowing the cycle: the loop is
        // decoration, and "Off air" is the state the words below describe
        // reaching from.
        // Reduce Motion holds it on the state it STARTED in, which is now
        // the lit one — the loop is decoration, and turning decoration off
        // should not also change which state is being illustrated.
        guard !reduceMotion else { return }
        // DOUBLE the first pace (founder direction 2026-09-01). Each state is
        // a thing to read, not a flicker to watch: 2.4s a side was a control
        // changing its mind while you were still on the sentence below it.
        while !Task.isCancelled {
            try? await Task.sleep(for: .milliseconds(4800))
            guard !Task.isCancelled else { return }
            // The swell and the state change happen TOGETHER, exactly as a
            // real tap does: `SkeuPress` fires its action on the same touch
            // that starts the swell.
            pressed = true
            withAnimation(SkeuMotion.tint) { on.toggle() }
            try? await Task.sleep(for: .milliseconds(260))
            guard !Task.isCancelled else { return }
            pressed = false
        }
    }
}
