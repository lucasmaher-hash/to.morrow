//
//  SkeuTheme.swift
//  shove95
//
//  A named light/dark PAIR of palettes — the unit the theme picker deals in:
//  an id for persistence, a display name, and the colours.
//
//  Cream is spelled out by hand (§2.4 ships exact hexes); the rest are derived
//  from one seed each (§2.5), which is the point — theming has to be provably
//  real, not a set of hand-tuned specials.
//
//  FOUR of them, chosen by the founder from the six that were here
//  (2026-08-22): Slate, Cream, Moss and a rose that is new. Clay and Ember
//  both sat in the warm half beside Cream, and Silver needed machinery of its
//  own to stop reading as Slate.
//
//  The ORDER below is what the picker shows, and it is the founder's — blue
//  first (2026-08-22). Nothing reads a theme by its position any more, so this
//  list can be rearranged freely; see `AppSettings.storedThemeID`.
//

import SwiftUI

struct SkeuTheme: Identifiable, Equatable, Sendable {
    let id: String
    let name: String
    let light: SkeuPalette
    let dark: SkeuPalette

    func palette(dark isDark: Bool) -> SkeuPalette { isDark ? dark : light }

    // MARK: Presets

    /// Both halves are written out by hand — see `SkeuPalette.creamDark` for
    /// why the derived dark came out grey.
    static let cream = SkeuTheme(
        id: "cream", name: "Cream",
        light: .cream,
        dark: .creamDark)

    static let moss = SkeuTheme(
        id: "moss", name: "Moss",
        light: .derived(from: Color(hex: 0xA8B79A), accent: Color(hex: 0x4E6B45)),
        dark: .derived(from: Color(hex: 0xA8B79A), accent: Color(hex: 0x4E6B45), dark: true))

    static let slate = SkeuTheme(
        id: "slate", name: "Slate",
        light: .derived(from: Color(hex: 0xB4BAC4), accent: Color(hex: 0x3F5670)),
        dark: .derived(from: Color(hex: 0xB4BAC4), accent: Color(hex: 0x3F5670), dark: true))

    /// Rose, added when the palette was cut to four (founder direction
    /// 2026-08-22).
    ///
    /// It started at Moss's saturation, on the reasoning that these are
    /// SURFACES and the swatch shows the seed at more than double strength
    /// anyway. Too quiet: the founder asked for it stronger in both lightings
    /// the same day. At 0.33 it is the most saturated seed in the palette by
    /// some way, which is the point — the other three are near-neutrals and
    /// this is the one that is a colour.

    /// The colour this theme shows in the PICKER.
    ///
    /// Not `light.material` — that is the surface the app is painted in, and
    /// at 0.62 of the seed's saturation it is deliberately quiet. Quiet
    /// surfaces side by side read as greys with a hint of something
    /// (founder direction 2026-08-17). The swatch says what the theme IS, so
    /// it takes the seed at full strength; nothing the app paints changes.
    var swatch: Color {
        let s = light.material.hsb
        return Color(h: s.h, s: min(s.s * 2.1, 0.82), b: min(s.b * 1.02, 0.94))
    }

    /// What the picker actually paints. Flat, and it stays a style rather
    /// than a `Color` because the segment takes one: Silver painted a raked
    /// gradient here until it was cut (2026-08-22), a single tone at a neutral
    /// hue being grey no matter how it is tuned.
    var swatchStyle: AnyShapeStyle { AnyShapeStyle(swatch) }

    static let rose = SkeuTheme(
        id: "rose", name: "Rose",
        light: .derived(from: Color(hex: 0xD48DA2), accent: Color(hex: 0x9E3F5D)),
        dark: .derived(from: Color(hex: 0xD48DA2), accent: Color(hex: 0x9E3F5D), dark: true))

    /// Blue first (founder direction 2026-08-22).
    static let all: [SkeuTheme] = [slate, cream, moss, rose]

    static func named(_ id: String) -> SkeuTheme {
        all.first { $0.id == id } ?? cream
    }
}
