//
//  SkeuTypeScale.swift
//  shove95
//
//  Dynamic Type (FR-015).
//
//  `PixelScale` scales by redefining a `pixel` unit in whole steps, which
//  works only where every value is expressed in 1995 pixels. These sizes come
//  from a Figma frame and have no such unit, so they need their own mechanism:
//  ONE multiplier in the environment that the size tokens read.
//
//  Why a multiplier rather than `@ScaledMetric` at each call site:
//
//  · The tokens are static constants on a private `enum F`, consumed in ~40
//    places across rows, bars, pills and glyphs. `@ScaledMetric` is a property
//    wrapper and cannot live on a static, so adopting it would mean threading
//    forty stored properties through every view.
//  · The bars are FIXED-HEIGHT chrome. Text inside them has to grow, but the
//    trough cannot grow without breaking the layout it was transcribed from.
//    A single multiplier lets type and geometry scale on different curves —
//    see `text` versus `chrome` below.
//
//  Capped deliberately. Beyond ~1.6× the four tab labels stop fitting a phone
//  width at any sane truncation, so the ladder flattens rather than shipping a
//  bar that reads "Tod… Tom… We… Gen…". The accessibility sizes still gain a
//  lot over the default; they just stop short of destroying the layout.
//

import SwiftUI

enum SkeuTypeScale {
    /// How much TEXT grows. The full accessibility ladder, capped at 1.6.
    static func text(for size: DynamicTypeSize) -> CGFloat {
        switch size {
        case .xSmall:  0.86
        case .small:   0.91
        case .medium:  0.95
        case .large:   1.00   // the design reference
        case .xLarge:  1.07
        case .xxLarge: 1.14
        case .xxxLarge: 1.22
        case .accessibility1: 1.34
        case .accessibility2: 1.44
        case .accessibility3: 1.52
        case .accessibility4: 1.56
        case .accessibility5: 1.60
        @unknown default: 1.00
        }
    }

    /// How much CHROME grows — bar heights, glass pills, tap targets. Tracks
    /// the text curve at roughly half strength: controls have to stay
    /// comfortably tappable and visually proportionate to their labels, but a
    /// tab bar that grows 60% eats the list it is meant to serve.
    static func chrome(for size: DynamicTypeSize) -> CGFloat {
        1 + (text(for: size) - 1) * 0.5
    }
}

extension EnvironmentValues {
    /// Multiplier for skeu TEXT sizes. Read by the size tokens.
    @Entry var skeuTextScale: CGFloat = 1
    /// Multiplier for skeu CHROME sizes (heights, paddings, glyph boxes).
    @Entry var skeuChromeScale: CGFloat = 1
}

/// Resolves the device's Dynamic Type setting into the two multipliers and
/// publishes them. Applied once, at the root of the skeu tree.
struct SkeuTypeScaling: ViewModifier {
    @Environment(\.dynamicTypeSize) private var typeSize

    func body(content: Content) -> some View {
        content
            .environment(\.skeuTextScale, SkeuTypeScale.text(for: typeSize))
            .environment(\.skeuChromeScale, SkeuTypeScale.chrome(for: typeSize))
    }
}

extension View {
    func skeuTypeScaling() -> some View {
        modifier(SkeuTypeScaling())
    }
}
