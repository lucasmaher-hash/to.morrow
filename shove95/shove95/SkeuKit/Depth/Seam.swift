//
//  Seam.swift
//  shove95
//
//  A seam is a 1pt inset hairline tracing a surface ~7pt inside its edge (§4.6).
//  It is the ONLY decorative detail the system permits, it is not a texture, and
//  it must be stroked — never drawn from an image.
//
//  Use on: large tiles, stacked cards, sheet headers.
//  Never on: buttons under 44pt, list rows, inputs.
//

import SwiftUI

struct Seam: ViewModifier {
    @Environment(\.skeu) private var skeu
    var radius: CGFloat
    var inset: CGFloat = 7
    var dashed: Bool = false
    var opacity: Double = 0.35

    func body(content: Content) -> some View {
        content.overlay {
            RoundedRectangle(cornerRadius: nestedRadius(radius, inset: inset),
                             style: .continuous)
                .strokeBorder(skeu.seam.opacity(opacity),
                              style: StrokeStyle(lineWidth: 1,
                                                 dash: dashed ? [4, 4] : []))
                .padding(inset)
                .allowsHitTesting(false)
        }
    }
}

extension View {
    func seam(radius: CGFloat, inset: CGFloat = 7,
              dashed: Bool = false, opacity: Double = 0.35) -> some View {
        modifier(Seam(radius: radius, inset: inset,
                      dashed: dashed, opacity: opacity))
    }
}
