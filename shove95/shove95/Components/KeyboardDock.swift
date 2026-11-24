//
//  KeyboardDock.swift
//  shove95
//
//  Reading the keyboard's OWN animation off its notification, so a list
//  getting out of its way travels WITH it rather than beside it.
//
//  Both looks dock a focused field the same way and were doing the same
//  arithmetic twice, each animating on a hand-picked `easeOut(0.25)` that had
//  nothing to do with what the keyboard was actually doing. UIKit posts both a
//  duration and a curve; matched, the inset, the lift and the keyboard are one
//  movement instead of three that happen to overlap (founder bug report
//  2026-08-17).
//

import SwiftUI

enum KeyboardDock {
    struct Change {
        /// The keyboard's top edge in global coordinates; `.infinity` when it
        /// is not on screen, so a "is this field covered" test is just a
        /// comparison and needs no special case.
        let top: CGFloat
        /// How far the keyboard eats into the LIST, once the chrome already
        /// parked at the bottom is discounted — the keyboard covers that
        /// first, and the list must not inset itself for it twice.
        let overlap: CGFloat
        /// The keyboard's own animation, for everything that moves with it.
        let animation: Animation
        /// That animation's DURATION, on its own.
        ///
        /// For the few places that want their own curve — a spring with some
        /// bounce on the way open, a longer glide on the way shut — but still
        /// want to travel with the keys rather than beside them. Taking the
        /// duration and leaving the curve is the smallest way to stay in step.
        let duration: Double
    }

    /// `clearance` is how far the LIST's bottom edge already sits above the
    /// screen's — see `bottomGapToScreen`. The keyboard is measured from the
    /// screen, the inset is applied to the list, and the difference between
    /// those two edges is the only thing that reconciles them.
    ///
    /// This used to be a hand-computed `chrome` constant — the bar's height
    /// plus a margin — and it was wrong in BOTH looks then shipping, in
    /// opposite directions: one over-counted by 9pt so a docked field sat that
    /// far under the keyboard, the other under-counted by 10pt so it floated
    /// that far above (measured 2026-08-17, founder bug report "etwas zu
    /// niedrig"). Measured,
    /// it is right at every type size and on every device.
    static func read(_ note: Notification, clearance: CGFloat) -> Change? {
        guard let frame = note.userInfo?[UIResponder.keyboardFrameEndUserInfoKey]
                as? CGRect else { return nil }

        let screenHeight = (note.object as? UIScreen)?.bounds.height
            ?? Self.screenHeight ?? frame.maxY

        let covered = max(0, screenHeight - frame.origin.y)
        return Change(top: covered > 0 ? frame.origin.y : .infinity,
                      overlap: max(0, covered - clearance),
                      animation: animation(from: note),
                      duration: duration(from: note))
    }

    private static var screenHeight: CGFloat? {
        UIApplication.shared.connectedScenes
            .compactMap { ($0 as? UIWindowScene)?.screen.bounds.height }
            .first
    }

    /// How far this view's bottom edge sits above the screen's bottom.
    static func gapToScreenBottom(_ proxy: GeometryProxy) -> CGFloat {
        guard let screenHeight else { return 0 }
        return max(0, screenHeight - proxy.frame(in: .global).maxY)
    }

    /// The curve arrives as a RAW `UIView.AnimationCurve` value, and for
    /// keyboards it is almost always 7 — a private ease with no public case
    /// and no SwiftUI equivalent. `easeInOut` is its closest relative and is
    /// what the default branch is for; the named curves are handled anyway
    /// because a hardware keyboard attaching does send them.
    private static func duration(from note: Notification) -> Double {
        note.userInfo?[UIResponder.keyboardAnimationDurationUserInfoKey]
            as? Double ?? 0.25
    }

    private static func animation(from note: Notification) -> Animation {
        let duration = duration(from: note)
        // Zero means "do not animate": a hardware keyboard connecting, or a
        // frame change with nothing to show for it.
        guard duration > 0 else { return .linear(duration: 0) }

        let raw = note.userInfo?[UIResponder.keyboardAnimationCurveUserInfoKey] as? Int
        switch raw.flatMap(UIView.AnimationCurve.init(rawValue:)) {
        case .easeIn:  return .easeIn(duration: duration)
        case .easeOut: return .easeOut(duration: duration)
        case .linear:  return .linear(duration: duration)
        default:       return .easeInOut(duration: duration)
        }
    }
}

extension View {
    /// Reports this view's clearance from the bottom of the screen, for
    /// `KeyboardDock.read`. In a BACKGROUND, never as a wrapper: a
    /// GeometryReader that wraps content lays it out rather than measuring it.
    func bottomGapToScreen(_ gap: Binding<CGFloat>) -> some View {
        background {
            GeometryReader { proxy in
                Color.clear
                    .task { gap.wrappedValue = KeyboardDock.gapToScreenBottom(proxy) }
                    .onChange(of: proxy.frame(in: .global)) { _, _ in
                        gap.wrappedValue = KeyboardDock.gapToScreenBottom(proxy)
                    }
            }
        }
    }
}
