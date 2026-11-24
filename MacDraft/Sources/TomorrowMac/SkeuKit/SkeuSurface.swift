//
//  SkeuSurface.swift
//  shove95
//
//  The core modifier (§4.5). EVERY visible object goes through this — a bare
//  `.background(Color…)` plus `.shadow(…)` is non-compliant by definition
//  (Law 3: every object has thickness).
//
//  A raised surface is five layers, bottom to top:
//    1. body gradient      materialTop → materialBottom, x-offset for the light
//    2. sheen              top-biased white, ≤ 0.10α
//    3. rim light          top arc only
//    4. rim shade          bottom arc only, drawn AFTER the rim light
//    5. content
//  …plus two shadows below: ambient (wide, soft) and contact (tight, dark).
//
//  Recessed surfaces invert it: the cavity's near wall shades the top, light
//  pools at the bottom, and nothing is cast outward.
//

import SwiftUI

struct SkeuSurface<S: Shape>: ViewModifier {
    @Environment(\.skeu) private var skeu
    let shape: S
    let depth: SkeuDepth
    /// `nil` = material. Pass `skeu.accent` for actions; the gradient is
    /// derived at ±8% brightness rather than by swapping palette roles (§5.3).
    let tint: Color?
    let sheen: Bool
    /// Glass treatment: a brighter sheen and a rim that wraps the WHOLE
    /// perimeter instead of the top arc alone. This is what separates the
    /// pressable pill in the reference from a plain raised slab.
    var glass: Bool = false
    /// Rim stroke width BEFORE clipping. `.stroke` centres on the path and the
    /// surface is clipped to that same path, so half of every stroke is thrown
    /// away — the value is doubled on the way in so 1 means 1.
    var rimWidth: CGFloat = SkeuStroke.rim

    func body(content: Content) -> some View {
        content
            .background { fill }
            .overlay { sheenLayer }
            .overlay { rimLight }
            .overlay { rimShade }
            .modifier(InnerLayer(shape: shape, depth: depth))
            .clipShape(shape)
            .modifier(OuterShadows(depth: depth))
    }

    // 1. Body gradient. The x-offset between the start and end points is what
    //    encodes the 10 o'clock key light. Never a flat fill.
    private var fill: some View {
        let top: Color
        let bottom: Color
        switch (depth, tint) {
        case (_, .some(let t)):
            top = t.shifted(bri: +0.08)
            bottom = t.shifted(bri: -0.08)
        case (.carved, _), (.recessed, _):
            top = skeu.recess
            bottom = skeu.recessBottom
        default:
            top = skeu.materialTop
            bottom = skeu.materialBottom
        }
        return shape.fill(
            LinearGradient(colors: [top, bottom],
                           startPoint: UnitPoint(x: 0.35, y: 0),
                           endPoint: UnitPoint(x: 0.65, y: 1))
        )
    }

    // 2. Sheen — optional below 40pt tall, mandatory above 80pt. Glass surfaces
    //    carry a stronger one that reaches further down the face.
    @ViewBuilder private var sheenLayer: some View {
        if sheen && depth.rawValue >= SkeuDepth.flush.rawValue {
            shape.fill(
                LinearGradient(
                    stops: [.init(color: .white.opacity(glass ? 0.22 : 0.10), location: 0),
                            .init(color: .white.opacity(glass ? 0.06 : 0.00), location: 0.42),
                            .init(color: .clear, location: glass ? 0.75 : 0.55)],
                    startPoint: .top, endPoint: .bottom)
            )
            .allowsHitTesting(false)
        }
    }

    // 3. Rim light. The gradient runs topLeading → bottomTrailing, not straight
    //    down: Law 1 puts the key light at 10 o'clock, so the lit edge is the
    //    top AND the leading one. Running it vertically was why the earlier
    //    build read flat — the left/right cue was simply missing.
    //
    //    Raised: lit top-left. Recessed: the light pools in the far corner,
    //    bottom-right. Dark palettes halve it — a bright rim on dark material
    //    reads as chrome, which this system does not want.
    private var rimLight: some View {
        let a = skeu.isDark ? depth.rimLight * 0.5 : depth.rimLight
        let low = depth.isRecessed
        // Glass keeps a live rim all the way round rather than fading to nothing.
        let tail = glass ? a * 0.45 : 0
        return shape.stroke(
            LinearGradient(
                stops: [.init(color: skeu.edgeLight.opacity(low ? tail : a), location: 0),
                        .init(color: skeu.edgeLight.opacity(tail), location: 0.5),
                        .init(color: skeu.edgeLight.opacity(low ? a : tail), location: 1)],
                startPoint: .topLeading, endPoint: .bottomTrailing),
            lineWidth: rimWidth * 2
        )
        .allowsHitTesting(false)
    }

    // 4. Rim shade — the mirror of the rim light, on the same diagonal.
    private var rimShade: some View {
        let a = depth.rimShade
        let low = depth.isRecessed
        return shape.stroke(
            LinearGradient(
                stops: [.init(color: skeu.edgeShade.opacity(low ? a : 0), location: 0),
                        .init(color: .clear, location: 0.45),
                        .init(color: skeu.edgeShade.opacity(low ? 0 : a), location: 1)],
                startPoint: .topLeading, endPoint: .bottomTrailing),
            lineWidth: rimWidth * 2
        )
        .allowsHitTesting(false)
    }

    /// The cavity: a shadow cast inward from the top edge, and a soft light
    /// pooling along the bottom.
    private struct InnerLayer: ViewModifier {
        @Environment(\.skeu) private var skeu
        let shape: S
        let depth: SkeuDepth

        func body(content: Content) -> some View {
            guard let inner = depth.inner else { return AnyView(content) }
            return AnyView(
                content
                    .innerShadow(shape,
                                 color: skeu.shadow.opacity(inner.alpha * skeu.shadowIntensity),
                                 radius: inner.radius,
                                 offset: CGSize(width: 0, height: inner.y))
                    .innerShadow(shape,
                                 color: skeu.edgeLight.opacity(depth.rimLight),
                                 radius: 2,
                                 offset: CGSize(width: 0, height: -1))
            )
        }
    }

    /// Ambient then contact. Both tinted with `skeu.shadow`, never black (§5.4).
    private struct OuterShadows: ViewModifier {
        @Environment(\.skeu) private var skeu
        let depth: SkeuDepth

        func body(content: Content) -> some View {
            var view = AnyView(content)
            if let ambient = depth.ambient {
                view = AnyView(view.shadow(
                    color: skeu.shadow.opacity(ambient.alpha * skeu.shadowIntensity),
                    radius: ambient.radius, x: 0, y: ambient.y))
            }
            if let contact = depth.contact {
                view = AnyView(view.shadow(
                    color: skeu.shadow.opacity(contact.alpha * skeu.shadowIntensity),
                    radius: contact.radius, x: 0, y: contact.y))
            }
            return view
        }
    }
}

extension View {
    /// The one entry point for depth. Every visible object uses this.
    func skeuSurface<S: Shape>(_ shape: S,
                               depth: SkeuDepth = .raised,
                               tint: Color? = nil,
                               sheen: Bool = true,
                               glass: Bool = false,
                               rimWidth: CGFloat = SkeuStroke.rim) -> some View {
        modifier(SkeuSurface(shape: shape, depth: depth, tint: tint,
                             sheen: sheen, glass: glass, rimWidth: rimWidth))
    }

    /// Convenience for the 95% case — a continuous rounded rectangle. Large
    /// radii take the thicker rim (§3.2): on a 28pt corner a 1pt rim is too
    /// fine to carry the edge.
    func skeuSurface(radius: CGFloat = SkeuRadius.lg,
                     depth: SkeuDepth = .raised,
                     tint: Color? = nil,
                     sheen: Bool = true,
                     glass: Bool = false) -> some View {
        skeuSurface(skeuShape(radius), depth: depth, tint: tint,
                    sheen: sheen, glass: glass,
                    rimWidth: radius >= SkeuRadius.xl ? SkeuStroke.rimThick : SkeuStroke.rim)
    }
}
