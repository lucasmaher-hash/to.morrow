//
//  SwipeToDismiss.swift
//  shove95
//
//  Two ways out of a full-screen sheet: in from the left edge, or down from
//  the header.
//
//  Settings, About, How to use and Archive all cover the whole screen, and a
//  full-screen cover has no system dismiss gesture of its own — the ✕ was the
//  only exit. Both looks now take the two gestures people already have in
//  their hands (founder direction 2026-08-17).
//
//  THE LEFT EDGE, not anywhere. A horizontal drag in the middle of a settings
//  screen is a swipe on a task row everywhere else in this app; only a drag
//  that BEGINS at the screen's edge means "back", which is also what iOS
//  itself has taught.
//
//  THE HEADER, not the whole page. A downward drag lower down is a scroll, and
//  a sheet that closes when you try to scroll it is worse than one with no
//  gesture at all.
//
//  Two things the first version got wrong, both worth keeping written down:
//
//  1. It compared the drag's start against a header height measured from the
//     sheet's own top, while `startLocation` is in GLOBAL space and counts the
//     status bar. The band therefore sat above the title rather than on it,
//     and dragging the header did nothing. The safe-area inset is added now,
//     and the band is measured to include the title AND its button.
//
//  2. Offsetting the sheet revealed BLACK. Nothing is behind a full-screen
//     cover — the screen it came from is not rendered underneath — so moving
//     it exposes the void. Asking for a clear presentation background gets
//     the real screen back; these covers sit on their own canvas colour, which
//     is what is behind them anyway.
//
//  3. A committed drag used to dismiss on the spot and spring the offset back
//     to zero, so the sheet snapped to the middle and then dropped — the hand
//     threw it one way and the screen answered by throwing it another. It now
//     leaves along the line the drag was already on.
//

import SwiftUI

struct SwipeToDismiss: ViewModifier {
    /// Height of the band, measured from below the safe area, in which a
    /// downward drag dismisses — the header and its button, nothing lower.
    ///
    /// `.infinity` makes it the whole screen. That is right only where there
    /// is nothing underneath that a downward drag already means something to:
    /// the photo viewer has no scroll view, and a swipe down is what people
    /// already do to put a picture away.
    let headerHeight: CGFloat
    /// Whether the gesture is listening at all.
    ///
    /// The photo viewer stands it down while the picture is zoomed, where a
    /// downward drag is how you look at the bottom of the photo rather than a
    /// way out of it (2026-08-23).
    var enabled: Bool = true
    /// Whether the LEFT-EDGE drag is listening, separately from the downward
    /// one.
    ///
    /// The photo viewer pages sideways between a task's photos, and a drag
    /// that both turns the page and closes the viewer is one gesture doing two
    /// things. It is allowed only on the first photo, where turning back has
    /// nothing to turn to (2026-08-23).
    var allowsEdge: Bool = true
    /// What shows through while the sheet travels. The sheet's own ground.
    let backdrop: Color
    let onDismiss: () -> Void

    /// How far a drag has to travel before it counts. Generous: it competes
    /// with scrolling and with the row gestures, so a hesitant drag should do
    /// nothing rather than something surprising.
    private static let distance: CGFloat = 70
    /// A flick counts sooner than a drag.
    private static let velocity: CGFloat = 320
    /// How near the leading edge a horizontal drag must start.
    private static let edge: CGFloat = 24
    /// Extra reach BELOW the header, on top of its measured height.
    ///
    /// A header's own height is where the gesture belongs in principle, and in
    /// the hand it is too mean — the thumb lands where it lands, and a band
    /// that ends exactly at the title means half the attempts do nothing
    /// (founder, twice, 2026-08-17). This much further down still sits above
    /// any content worth scrolling, so nothing is taken from the scroll view.
    private static let reach: CGFloat = 72
    /// How long the sheet takes to leave. Short — this is the tail of a
    /// gesture that has already happened, not an animation in its own right.
    private static let exitDuration: TimeInterval = 0.26

    @State private var offset: CGSize = .zero
    /// True once the gesture has committed and the sheet is on its way out.
    /// The backdrop goes with it — left behind, it would hold a flat colour
    /// on screen after the sheet had gone.
    @State private var leaving = false
    /// The full screen, measured alongside the inset. The sheet has to travel
    /// far enough to actually clear it, and that distance is not a guess.
    @State private var canvas: CGSize = .zero
    /// The status-bar inset, measured rather than assumed. `startLocation` is
    /// global and counts it; the header band is stated from below it.
    @State private var topInset: CGFloat = 0

    func body(content: Content) -> some View {
        ZStack {
            backdrop.ignoresSafeArea().opacity(leaving ? 0 : 1)
            content.offset(x: offset.width, y: offset.height)
        }
        // The measurement lives in a BACKGROUND, not around the content.
        // Wrapping the content in an ignoresSafeArea GeometryReader pulled
        // every sheet up under the status bar — the header slid off the top on
        // all four screens in both looks (founder bug report 2026-08-17).
        // A background reader takes no layout part and reports the real inset.
        .background {
            GeometryReader { proxy in
                Color.clear
                    .onAppear {
                        topInset = proxy.safeAreaInsets.top
                        canvas = proxy.size
                    }
                    .onChange(of: proxy.safeAreaInsets.top) { _, new in topInset = new }
                    .onChange(of: proxy.size) { _, new in canvas = new }
            }
            .ignoresSafeArea()
        }
        .simultaneousGesture(
            DragGesture(minimumDistance: 12, coordinateSpace: .global)
                .onChanged { value in
                    switch mode(for: value) {
                    case .horizontal:
                        offset = CGSize(width: max(0, value.translation.width), height: 0)
                    case .vertical:
                        offset = CGSize(width: 0, height: max(0, value.translation.height))
                    case .none:
                        offset = .zero
                    }
                }
                .onEnded { value in
                    let mode = mode(for: value)
                    let travelled = mode == .horizontal
                        ? value.translation.width : value.translation.height
                    let speed = mode == .horizontal
                        ? value.predictedEndTranslation.width - value.translation.width
                        : value.predictedEndTranslation.height - value.translation.height
                    let committed = mode != .none
                        && (travelled > Self.distance || speed > Self.velocity)

                    guard committed else {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
                            offset = .zero
                        }
                        return
                    }

                    // OUT, not back. Dismissing on the spot snapped the sheet
                    // to the middle and then dropped it — the hand threw it
                    // one way and the screen answered by throwing it another
                    // (founder bug report 2026-08-17). It leaves along the
                    // line the drag was already on: a sideways throw carries
                    // down and to the right, a downward one keeps going down.
                    SkeuHaptic.press()
                    let exit = mode == .horizontal
                        ? CGSize(width: canvas.width, height: canvas.height * 0.55)
                        : CGSize(width: 0, height: canvas.height)
                    withAnimation(.easeIn(duration: Self.exitDuration)) {
                        offset = exit
                        leaving = true
                    }
                    // Told to close just BEFORE it lands, so the cover's own
                    // dismissal is already under way by the time the sheet is
                    // off the edge and there is no still frame between them.
                    Task { @MainActor in
                        try? await Task.sleep(for: .seconds(Self.exitDuration - 0.04))
                        onDismiss()
                    }
                }
        )
    }

    private enum Mode { case horizontal, vertical, none }

    private func mode(for value: DragGesture.Value) -> Mode {
        guard enabled else { return .none }
        let band = topInset + headerHeight + Self.reach
        let dx = value.translation.width, dy = value.translation.height
        // Started at the leading edge and travelling right — "back".
        if allowsEdge, value.startLocation.x <= Self.edge, dx > abs(dy) { return .horizontal }
        // Started anywhere in the header band and travelling down.
        if value.startLocation.y <= band, dy > abs(dx) { return .vertical }
        return .none
    }
}

extension View {
    /// Closes this full-screen sheet on a drag in from the left edge, or down
    /// from its header. See `SwipeToDismiss`.
    func swipeToDismiss(headerHeight: CGFloat,
                        enabled: Bool = true,
                        allowsEdge: Bool = true,
                        backdrop: Color,
                        _ onDismiss: @escaping () -> Void) -> some View {
        modifier(SwipeToDismiss(headerHeight: headerHeight,
                                enabled: enabled,
                                allowsEdge: allowsEdge,
                                backdrop: backdrop,
                                onDismiss: onDismiss))
    }
}
