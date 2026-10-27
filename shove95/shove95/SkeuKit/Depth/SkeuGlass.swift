//
//  SkeuGlass.swift
//  shove95
//
//  The glass pill, transcribed from the isolated component (shove95 file, node
//  4:882 — a 221.31 × 104.54 button). It has NO fill of its own. What makes it
//  read as a lens, outside in:
//
//    shadows   a five-stop ladder falling straight down
//              0/81.44/22.68 @0     · 0/52.57/20.62 @.01 · 0/29.90/17.53 @.05
//              0/13.40/13.40 @.09   · 0/3.09/7.22   @.10
//    rim       2.971 of white at 0.5 alpha, the whole way round
//    glow      an ELLIPTICAL white gradient centred BELOW the pill
//              (111.02, 125.83 in a 221.31 × 104.54 box → x 0.5, y 1.20),
//              blended plus-lighter at 0.5 — additive, so it brightens
//              without tinting
//    lenses    five stacked layers, each rgba(255,255,255,0.01), each inset
//              further than the last, the group blurred by 3.281
//
//  The lens stack is the part that is easy to get backwards. Each layer is
//  SMALLER than the one below it, so the alphas accumulate toward the MIDDLE:
//  ~5% at the centre, 1% at the rim. An earlier build had a rim-weighted
//  gradient instead — brightest at the edge — which is the exact inverse and
//  read as a chrome ring rather than as thickness.
//
//  In Figma each layer also carries a backdrop-blur (41 → 20.5 → 10.25 → 4.1 →
//  0.82), giving true progressive refraction. SwiftUI's only backdrop-blur
//  primitive is `Material`, whose radius is fixed and which tints neutral grey
//  — it drains the hue straight out of the lens, which was tried and rejected.
//  What is kept is the layer geometry and the group blur; on the near-flat
//  surfaces this sits on, there is nothing behind it to refract anyway.
//

import SwiftUI

struct SkeuGlass<S: InsettableShape>: ViewModifier {
    @Environment(\.skeu) private var skeu
    let shape: S
    /// Reference pill height (104.54 in the frame) — scales every figure below.
    var height: CGFloat = 44
    /// The two glass states of the settings reference (nodes 1:101 vs 1:87).
    /// Prominent — the active option: full rim, bottom glow, full shadows.
    /// Subdued — a resting option: rim and shadows at half strength, NO glow,
    /// and the caller dims its label. The lens stack is identical in both;
    /// what changes is only how much light the piece is catching.
    var prominent: Bool = true
    /// Frosts the backdrop instead of letting it read straight through
    /// (founder direction 2026-08-16, "so wie bei liquid glass").
    ///
    /// The lens stack is five 1%-white layers — thickness, not opacity — so a
    /// glass piece over busy content shows every bit of it and the label
    /// fights the backdrop. Frosting blurs what is behind and hands the label
    /// a stable ground.
    ///
    /// It is a MATERIAL plus a tint, not a material alone. `.ultraThinMaterial`
    /// on its own was tried early in this look and pulled all the hue out —
    /// warm brown went grey — which is why it was removed then. The tint puts
    /// the palette back over the blur, so the piece frosts without changing
    /// colour. Still no texture: a blur is a lens, not an image fill.
    var frosted: Bool = false
    /// Whether this piece carries the light-mode relief: a prominent one on a
    /// light page.
    ///
    /// In the dark the lit rim has all the room it needs and the buttons read
    /// as objects. In the light it has none — the material already sits near
    /// the top of the range — so a prominent piece was a pale shape on a pale
    /// page.
    ///
    /// The relief that answers that is drawn in the BAKED half; see
    /// `SkeuGlassBackground.innerRelief`, which records what it is and why it
    /// lives there rather than here. What it changes on THIS side is the rim:
    /// a third thicker, and its top stop lifted 30%, because with the shade
    /// off the top the rim is the only thing left saying where the light comes
    /// from.
    ///
    /// It was a flag on one control while the founder tuned it over five
    /// passes (2026-08-23). It is what light mode does now.
    private var shadesInward: Bool { !skeu.isDark && prominent }

    private var k: CGFloat { height / 104.54 }

    /// The five lens insets, (vertical, horizontal), in frame units.
    private let lenses: [(v: CGFloat, h: CGFloat)] = [
        (0, 0), (2.46, 1.70), (7.39, 5.09), (15.59, 10.74), (31.99, 22.03),
    ]

    func body(content: Content) -> some View {
        content
            .background {
                ZStack {
                    if frosted {
                        Rectangle().fill(.ultraThinMaterial)
                        // CANVAS, not material. A frosted piece should read as
                        // the ground seen through glass, so it takes the
                        // ground's own colour — tinting it with `material`
                        // made it lighter than everything around it and it
                        // read as a pale card laid on top (founder note
                        // 2026-08-16).
                        Rectangle().fill(skeu.canvas.opacity(skeu.isDark ? 0.62 : 0.55))
                    }
                    bakedLens
                    // NO GLOW when frosted. The glow's radius is a fraction of
                    // the SHAPE (0.62), not of `k` — on a pill that is a thin
                    // band along the bottom edge, but on a tall panel it
                    // washes out the lower half. It is also additive, and
                    // plus-lighter over arbitrary content behind frosted glass
                    // is not something that can be predicted.
                }
            }
            .overlay {
                shape.strokeBorder(rim, lineWidth: rimWidth)
            }
            .clipShape(shape)
            .shadow(color: drop(0.05), radius: 17.525 * k, y: 29.895 * k)
            .shadow(color: drop(0.09), radius: 13.401 * k, y: 13.401 * k)
            .shadow(color: drop(0.10), radius: 7.216 * k, y: 3.093 * k)
    }

    /// Halves every light the piece throws when it is at rest.
    private var strength: Double { prominent ? 1 : 0.5 }

    /// The lens stack, as a PICTURE where one can be made.
    ///
    /// Its shape never depended on the content behind it, so it is the same
    /// image for every object of a given size and palette — thirteen view
    /// nodes and a Gaussian blur, collapsed to one (founder direction
    /// 2026-08-22, and see SkeuGlassBakery for why building rather than
    /// drawing was the cost).
    ///
    /// Falls back to building it live when there is no size to bake at yet or
    /// the renderer declines, so this can only ever cost speed.
    @ViewBuilder
    private var bakedLens: some View {
        GeometryReader { proxy in
            let pad = SkeuGlassBakery.bleed(k: k)
            if let picture = SkeuGlassBakery.background(
                shape: shape, size: proxy.size, k: k,
                prominent: prominent && !frosted, skeu: skeu) {
                picture
                    .resizable()
                    .frame(width: proxy.size.width + pad * 2,
                           height: proxy.size.height + pad * 2)
                    .offset(x: -pad, y: -pad)
                    .allowsHitTesting(false)
            } else {
                SkeuGlassBackground(shape: shape, k: k,
                                    prominent: prominent && !frosted)
            }
        }
    }

    /// The rim: bright along the top and bottom edges, all but gone across the
    /// middle of the two ends.
    ///
    /// Figma's export states this as a flat `rgba(255,255,255,0.5)`, because it
    /// cannot represent a gradient stroke — the same flattening that hid the
    /// trough contour's gradient. Taken literally it lights the whole perimeter
    /// evenly, which turns the lens into a ring. Only the surfaces facing the
    /// key light should catch it; the sides are edge-on to it and stay dark.
    /// A rim is a HIGHLIGHT, and a highlight needs somewhere brighter to go.
    ///
    /// On a dark palette it has all the room in the world. On a light one it
    /// has none: the material already sits near the top of the range, so a
    /// white edge on a near-white surface is not an edge — and at RESTING
    /// strength, where everything is halved and there is no glow underneath
    /// either, it disappeared completely. That is what made the unchecked
    /// circles unreadable in light mode (founder bug report 2026-08-16).
    ///
    /// The palette already says what to do instead, in its own note beside
    /// `edgeShade`: "on a light material the rim has nowhere brighter to go,
    /// so the contact shade is what separates an object from the page". So a
    /// resting object on a light page gets a CONTACT edge rather than a lit
    /// one — dark along the lower arc, gone by the top, where the page is
    /// already brighter than the object is.
    ///
    /// Prominent glass keeps its lit rim in both directions: it has the glow
    /// and the full-strength stops to carry it, and that is the look as signed
    /// off.
    private var rim: LinearGradient {
        // Under the trial the TOP stop is lifted by 30% (founder direction
        // 2026-08-23, "die helligkeit oben ist nicht wirklich sichtbar").
        // With the shade inverted the top edge is the only thing left saying
        // where the light comes from, so it has to be seen.
        if shadesInward {
            return LinearGradient(
                stops: [.init(color: skeu.edgeLight.opacity(0.55 * 1.3 * strength), location: 0.0),
                        .init(color: skeu.edgeLight.opacity(0.05 * strength), location: 0.5),
                        .init(color: skeu.edgeLight.opacity(0.60 * strength), location: 1.0)],
                startPoint: .top, endPoint: .bottom)
        }
        guard !skeu.isDark, !prominent else {
            return LinearGradient(
                stops: [.init(color: skeu.edgeLight.opacity(0.55 * strength), location: 0.0),
                        .init(color: skeu.edgeLight.opacity(0.05 * strength), location: 0.5),
                        .init(color: skeu.edgeLight.opacity(0.60 * strength), location: 1.0)],
                startPoint: .top, endPoint: .bottom)
        }
        // Absolute, not scaled by `strength`: this branch only ever runs at
        // rest, and halving it again is what the bug was.
        return LinearGradient(
            stops: [.init(color: skeu.edgeShade.opacity(0.00), location: 0.0),
                    .init(color: skeu.edgeShade.opacity(0.14), location: 0.45),
                    .init(color: skeu.edgeShade.opacity(0.42), location: 1.0)],
            startPoint: .top, endPoint: .bottom)
    }

    /// The white line round the outside. A touch thicker under the trial
    /// (founder direction 2026-08-23) — the edge is doing more work on a light
    /// page, so it is given more to work with.
    private var rimWidth: CGFloat {
        max(0.8, 2.971 * k * (shadesInward ? 1.35 : 1))
    }

    private func drop(_ alpha: Double) -> Color {
        skeu.shadow.opacity(alpha * skeu.shadowIntensity * strength)
    }
}

extension View {
    /// The glass lens treatment. `height` scales every transcribed figure;
    /// `prominent: false` is the resting-option state of a settings panel.
    func skeuGlass<S: InsettableShape>(_ shape: S,
                                       height: CGFloat = 44,
                                       prominent: Bool = true,
                                       frosted: Bool = false) -> some View {
        modifier(SkeuGlass(shape: shape, height: height,
                           prominent: prominent, frosted: frosted))
    }
}
