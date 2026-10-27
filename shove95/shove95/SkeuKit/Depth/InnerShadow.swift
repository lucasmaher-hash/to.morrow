//
//  InnerShadow.swift
//  shove95
//
//  SwiftUI has no inner shadow, so one is built the standard way: stroke the
//  shape with a thick line, offset it, blur it, then mask it back to the shape
//  so only the part that falls INSIDE survives (§4.5).
//
//  COST, and why the plural version exists. Each of those is two offscreen
//  render passes — one for the blur, one for the mask — and a trough wants
//  FOUR inner shadows (lip, far wall, two diagonals). Applied one at a time
//  that is eight passes per trough, recomputed every frame the trough moves,
//  because a blur is not cached by SwiftUI on its own.
//
//  The settings sheet is where that bill comes due: it stands up roughly
//  eleven troughs and thirteen glass pills, against one or two troughs on the
//  home screen. Same scrolling, same data — the only difference was how many
//  of these stacks were live, which is why this sheet dropped frames while the
//  flat one that preceded it — no blur anywhere — never did.
//
//  So: mask ONCE for the whole set, and rasterise the result. These layers are
//  static for a given size and palette, so `drawingGroup` composites them into
//  a single texture that is then translated as the screen scrolls rather than
//  re-blurred.
//
//  Rasterising is safe HERE and nowhere else in this kit, for one reason:
//  `drawingGroup` renders a subtree at its LAYOUT BOUNDS, and the mask has
//  already confined these shadows to the shape. An effect that is meant to
//  spread past its own frame — the glass lens highlight, the segmented
//  trough's bloom overhang — comes back with a square cut at the edge if it is
//  grouped (founder bug report 2026-08-16). Check the bleed before reaching
//  for this.
//
//  Do NOT put a `Material` inside one of these either — a material has to
//  sample the backdrop and cannot do that from inside a rasterised group.
//

import SwiftUI

/// One cast shadow inside a shape's edge.
struct InnerShadowSpec {
    let color: Color
    let radius: CGFloat
    let offset: CGSize

    init(_ color: Color, radius: CGFloat, offset: CGSize) {
        self.color = color
        self.radius = radius
        self.offset = offset
    }
}

struct InnerShadows<S: Shape>: ViewModifier {
    let shape: S
    let specs: [InnerShadowSpec]

    func body(content: Content) -> some View {
        content.overlay {
            ZStack {
                ForEach(Array(specs.enumerated()), id: \.offset) { _, spec in
                    shape
                        .stroke(spec.color, lineWidth: spec.radius * 2)
                        .offset(x: spec.offset.width, y: spec.offset.height)
                        .blur(radius: spec.radius)
                }
            }
            .mask(shape.fill())
            .drawingGroup()
            .allowsHitTesting(false)
        }
    }
}

extension View {
    /// One inner shadow. Still a single mask and a single rasterised group —
    /// the plural form with one element.
    func innerShadow<S: Shape>(_ shape: S, color: Color,
                               radius: CGFloat, offset: CGSize) -> some View {
        innerShadows(shape, [InnerShadowSpec(color, radius: radius, offset: offset)])
    }

    /// Several inner shadows sharing one mask and one rasterised pass.
    func innerShadows<S: Shape>(_ shape: S, _ specs: [InnerShadowSpec]) -> some View {
        modifier(InnerShadows(shape: shape, specs: specs))
    }
}
