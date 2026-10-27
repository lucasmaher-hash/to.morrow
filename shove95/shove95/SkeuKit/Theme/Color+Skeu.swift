//
//  Color+Skeu.swift
//  shove95
//
//  Colour utilities the design system requires (SKEUOMORPHIC_DESIGN_SYSTEM §2.7).
//
//  `Color(hex:alpha:)` is NOT redeclared here — Theme/PixelScale.swift owns it.
//  One hex initialiser for the whole app; two would be ambiguous at every call
//  site.
//

import SwiftUI
import UIKit

extension Color {
    /// HSB constructor. Every component is clamped, so derivation maths can
    /// overshoot without producing an invalid colour.
    init(h: Double, s: Double, b: Double, opacity: Double = 1) {
        self.init(hue: h.clamped01, saturation: s.clamped01,
                  brightness: b.clamped01, opacity: opacity)
    }

    /// HSB decomposition. Bridges through UIColor, so it is not free — the
    /// palettes cache their results in stored properties rather than calling
    /// this per frame.
    var hsb: (h: Double, s: Double, b: Double) {
        var h: CGFloat = 0, s: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        UIColor(self).getHue(&h, saturation: &s, brightness: &b, alpha: &a)
        return (Double(h), Double(s), Double(b))
    }

    /// Nudges a colour in HSB space. Used by `skeuSurface(tint:)` to derive the
    /// ±8% gradient of a tinted surface without inventing new palette roles.
    func shifted(sat: Double = 0, bri: Double = 0, hue: Double = 0) -> Color {
        let c = hsb
        return Color(h: c.h + hue, s: c.s + sat, b: c.b + bri)
    }
}

extension Double {
    var clamped01: Double { min(max(self, 0), 1) }
}
