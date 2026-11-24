//
//  SkeuEdgeFade.swift
//  shove95
//
//  Where scrolling content passes behind something that stays put.
//
//  This look docks three things — the top bar's workspace pill and gear, the
//  tab bar at the bottom, the settings sheet's title and ✕ — and content runs
//  underneath all of them. Cut at a hard line, a row is simply gone from one
//  frame to the next, which reads as clipping rather than as depth. Faded, it
//  goes the way a thing goes when it passes under something: gradually, and
//  from the edge inward (founder direction 2026-08-16).
//
//  A MASK, not a gradient overlay. An overlay would have to be painted in the
//  canvas colour, which pins it to one palette and shows as a band the moment
//  anything but the canvas is behind it. A mask takes the pixels out, so it is
//  right in every theme and over anything.
//
//  The Windows 95 look never got this. Its content was clipped by a sunken
//  well with a drawn border, and an edge that dissolves is the opposite of
//  what a bevel says — there the hard line WAS the design.
//

import SwiftUI

struct SkeuEdgeFade: ViewModifier {
    /// Fade heights in points. Zero on an edge leaves it hard.
    let top: CGFloat
    let bottom: CGFloat

    func body(content: Content) -> some View {
        content.mask {
            VStack(spacing: 0) {
                if top > 0 {
                    LinearGradient(colors: [.clear, .black],
                                   startPoint: .top, endPoint: .bottom)
                        .frame(height: top)
                }
                // The middle is fully opaque and takes whatever height is
                // left, so the two fades stay at their stated point size on
                // any screen instead of scaling with it.
                Rectangle().fill(.black)
                if bottom > 0 {
                    LinearGradient(colors: [.black, .clear],
                                   startPoint: .top, endPoint: .bottom)
                        .frame(height: bottom)
                }
            }
        }
    }
}

extension View {
    /// Softens the edges where this view's content disappears under docked
    /// chrome. Heights are in points; pass 0 to leave an edge hard.
    func skeuEdgeFade(top: CGFloat = 0, bottom: CGFloat = 0) -> some View {
        modifier(SkeuEdgeFade(top: top, bottom: bottom))
    }

    /// The scroll-aware form, and the one to reach for on a scroll view.
    ///
    /// A fade has to mean "there is more, and it is going under here". Applied
    /// unconditionally it means nothing, and it dims the top row of a list
    /// that has not been scrolled at all — the founder caught exactly that on
    /// a one-row tab, where the only row sat there greyed for no reason. So
    /// each edge fades in only once there is content past it.
    /// `edges` names which ends actually have something docked over them. The
    /// settings sheet docks only its header; its bottom edge is the screen,
    /// and content reaching the screen's edge is not passing under anything.
    func skeuScrollEdgeFade(_ amount: CGFloat,
                            edges: Edge.Set = [.top, .bottom]) -> some View {
        modifier(SkeuScrollEdgeFade(amount: amount, edges: edges))
    }
}

/// Applies `SkeuEdgeFade` to a scroll view, with each edge switched on only
/// when something has actually scrolled past it.
struct SkeuScrollEdgeFade: ViewModifier {
    let amount: CGFloat
    let edges: Edge.Set

    @State private var strength = Strength()

    func body(content: Content) -> some View {
        content
            // The RAMPED value is what is stored, not the raw offset.
            //
            // `onScrollGeometryChange` only calls its action when the value it
            // computes actually CHANGES, so what that value is decides how
            // often this modifier does any work at all. It used to hand back
            // the raw scroll offset — which changes on every single frame of
            // every scroll, for the whole length of the list. The fade itself
            // saturates after `amount` points and looks identical from then
            // on, so every frame past that was a state write, a body re-run,
            // and a fresh full-screen mask for a picture that did not change
            // (device trace 2026-08-22: the GPU sat at 5% while this churned).
            //
            // Quantised on top, because the ramp is a fade a reader cannot
            // resolve to more than a few dozen steps — sub-step changes are
            // work with nothing to show for it.
            .onScrollGeometryChange(for: Strength.self) { geometry in
                let offset = geometry.contentOffset.y + geometry.contentInsets.top
                let overflow = geometry.contentSize.height
                    - geometry.containerSize.height
                    + geometry.contentInsets.top
                    + geometry.contentInsets.bottom
                return Strength(top: ramp(offset), bottom: ramp(overflow - offset))
            } action: { _, new in
                strength = new
            }
            // Ramped over the fade's own height rather than switched on: a
            // fade that appeared at full strength the instant you moved would
            // be its own hard edge.
            .skeuEdgeFade(top: edges.contains(.top) ? amount * strength.top : 0,
                          bottom: edges.contains(.bottom) ? amount * strength.bottom : 0)
    }

    /// 0…1, quantised to `steps` so the value settles instead of drifting.
    private func ramp(_ hidden: CGFloat) -> CGFloat {
        let steps: CGFloat = 32
        let raw = max(0, min(1, hidden / max(amount, 1)))
        return (raw * steps).rounded() / steps
    }

    private struct Strength: Equatable {
        var top: CGFloat = 0
        var bottom: CGFloat = 0
    }
}
