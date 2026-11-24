//
//  SkeuPalette+Derived.swift
//  shove95
//
//  Derivation (§2.3): any single seed colour generates a compliant palette.
//  This is the interchange mechanism — a designer hands over ONE colour and the
//  system computes the other twenty-odd roles, so no palette can drift out of
//  contract by hand-picking a stop.
//

import SwiftUI

extension SkeuPalette {

    /// Builds a full palette from one material seed.
    /// - Parameters:
    ///   - seed: the body colour of raised surfaces
    ///   - accentSeed: optional action colour; defaults to a deepened, more
    ///     saturated seed
    ///   - dark: build the dark-mode variant
    ///
    /// There was a `metallic` flag here, which widened the gradient between a
    /// surface's top and bottom stops and pulled almost all the colour out of
    /// it — metal being a RANGE rather than a hue. It existed for Silver, and
    /// went with it when the palette was cut to four (2026-08-22).
    static func derived(from seed: Color,
                        accent accentSeed: Color? = nil,
                        dark: Bool = false) -> SkeuPalette {

        let s = seed.hsb
        let acc = (accentSeed ?? seed.shifted(sat: +0.22, bri: -0.24)).hsb

        // Light ladder. ONE BASE HUE: canvas, material and recess are all the
        // same colour at different brightnesses — see `SkeuPalette.cream` for
        // why every object IS the page, lit differently.
        if !dark {
            // LIGHT means light (founder direction 2026-08-16). The seeds are
            // mid-tones — they were being used as the material directly, which
            // made every light theme a dimmed version of its dark half rather
            // than the opposite of it. The base is lifted and desaturated
            // here, once, so every derived theme moves with the others and
            // keeps its hue: a light Moss is still Moss.
            //
            // 0.88 is a ceiling, not a target: a seed already brighter than
            // that would otherwise be pushed into white, where the rim light
            // has nowhere left to go.
            let b = min(s.b * 1.22, 0.88)
            let sat = s.s * 0.62
            // The sheen: how far a surface travels from its top stop to its
            // bottom one. A painted surface barely moves.
            let lift = 1.06
            let fall = 0.86

            return SkeuPalette(
                canvas:         Color(h: s.h, s: min(sat * 1.15, 1), b: b * 0.955),
                canvasAlt:      Color(h: s.h, s: min(sat * 1.15, 1), b: b * 0.955),

                material:       Color(h: s.h, s: sat, b: b),
                // Held off white deliberately. `edgeLight` is white, and the
                // old `× 1.10` clamped this stop to white as well at a light
                // base — a white rim on a white surface is not a rim.
                materialTop:    Color(h: s.h, s: sat * 0.78, b: min(b * lift, 0.94)),
                materialBottom: Color(h: s.h, s: min(sat * 1.18, 1), b: b * fall),

                // Trough BRIGHTNESS ratios come from the reference: near wall at
                // 0.76× the base, floor at 0.955×, contour at 0.59×.
                //
                // The saturation multipliers do NOT — the reference's 1.18× is
                // tuned for a red already at 0.73 saturation. Applied to a pale
                // seed it yields grey, so they are pushed much harder here and
                // scale with how unsaturated the seed is.
                recess:         Color(h: s.h, s: min(sat * 1.75, 1), b: b * 0.76),
                recessBottom:   Color(h: s.h, s: min(sat * 1.25, 1), b: min(b * 0.955, 1.0)),

                edgeLight:      .white,
                // NOT lightened with the rest. On a light material the rim has
                // nowhere brighter to go, so the contact shade is what
                // separates an object from the page — weaken it and everything
                // flattens.
                edgeShade:      Color(h: s.h, s: min(s.s * 1.8, 1), b: s.b * 0.42),
                seam:           Color(h: s.h, s: sat * 0.35, b: min(b * 1.14, 1)),
                // The contour is a gradient: dark near lip, LIT far lip. The
                // far one has to go brighter than the material AT THAT EDGE,
                // which is `materialTop` — not `material`.
                //
                // It was × 1.02 against a `materialTop` of × 1.06, so on every
                // light theme the lit lip came out 0.035 DARKER than the
                // surface it borders. A raised card's top edge therefore had
                // no highlight at all; the stroke read as a plain outline and
                // the frame lost its lift (founder bug report 2026-08-16,
                // confirmed by computing the two stops for all five seeds).
                //
                // × 1.16 clears `materialTop` by ~0.06 for every seed,
                // including one already at the 0.88 ceiling, and the
                // saturation drop keeps it reading as LIGHT rather than as a
                // paler tint of the hue.
                outline:        Color(h: s.h, s: min(sat * 1.9, 1), b: b * 0.60),
                outlineBottom:  Color(h: s.h, s: sat * 0.68, b: min(b * 1.02, 0.97)),
                // × 1.16 clears `materialTop` (× 1.06) by ~0.06 for every
                // seed, including one already at the 0.88 ceiling. The
                // saturation drop keeps it reading as LIGHT rather than as a
                // paler tint of the hue.
                outlineLit:     Color(h: s.h, s: sat * 0.55, b: min(b * 1.16, 0.995)),

                // ABSOLUTE, not a ratio of the base. As a ratio these tracked
                // the base upward and got lighter exactly when the surface did,
                // which is the wrong direction: the lighter the page, the
                // darker its text has to be. Fixed stops give every seed the
                // same black.
                ink:            Color(h: s.h, s: min(s.s * 0.9, 1), b: 0.14),
                inkMuted:       Color(h: s.h, s: min(s.s * 0.8, 1), b: 0.34),
                inkFaint:       Color(h: s.h, s: s.s * 0.7,         b: 0.50),
                inkOnAccent:    Color(h: acc.h, s: acc.s * 0.10, b: 0.99),

                accent:         Color(h: acc.h, s: acc.s, b: acc.b),
                accentTop:      Color(h: acc.h, s: acc.s * 0.88, b: min(acc.b * 1.14, 1)),
                accentBottom:   Color(h: acc.h, s: min(acc.s * 1.10, 1), b: acc.b * 0.84),

                // Read as TEXT on a light page — an overdue title is
                // critical-coloured — so they answer to 4.5:1, not 3:1. The
                // old stops were mid-tones tuned against a mid-tone material.
                positive:       Color(h: 0.35, s: 0.52, b: 0.42),
                caution:        Color(h: 0.10, s: 0.72, b: 0.52),
                // DARK, and deliberately so, reversing the 2026-08-17
                // direction that kept it bright because "important has to
                // shout". It shouted at 2.66:1 against the cream canvas and
                // 1.76:1 against rose — colour-only signalling, under half the
                // 4.5:1 text floor, so the one thing that had to shout was the
                // one thing a low-vision reader could not hear (measured in
                // review 2026-08-26). 0.42 clears 4.5:1 on all four canvases.
                // The shout now comes from WEIGHT as well as hue — an
                // important title is semibold — which is what makes the marker
                // survive greyscale at all (founder direction 2026-08-26).
                critical:       Color(h: 0.02, s: 0.88, b: 0.42),

                // Also absolute, and also on purpose: shadow carries the
                // depth on a light theme, so it must not lift with the base.
                shadow:         Color(h: s.h, s: min(s.s * 1.5, 1), b: 0.16),
                shadowIntensity: 1.0,
                isDark:         false
            )
        }

        // Dark ladder: material sits ABOVE canvas in brightness, shadows soften,
        // rim light weakens, rim shade strengthens. A bright rim on dark
        // material reads as chrome, which this system does not want.
        //
        // Saturation is pushed UP rather than down as the doc's draft had it.
        // Cutting it while also dropping brightness to 0.20 produced a neutral
        // grey for any lightly-saturated seed — the app has to stay the same
        // MATERIAL in the dark, merely unlit, so the hue survives the fall.
        return SkeuPalette(
            canvas:         Color(h: s.h, s: min(s.s * 1.25, 1), b: 0.19),
            canvasAlt:      Color(h: s.h, s: min(s.s * 1.25, 1), b: 0.19),

            material:       Color(h: s.h, s: min(s.s * 1.25, 1), b: 0.19),
            materialTop:    Color(h: s.h, s: min(s.s * 1.10, 1), b: 0.26),
            materialBottom: Color(h: s.h, s: min(s.s * 1.35, 1), b: 0.14),

            recess:         Color(h: s.h, s: min(s.s * 1.40, 1), b: 0.11),
            recessBottom:   Color(h: s.h, s: min(s.s * 1.15, 1), b: 0.23),

            edgeLight:      Color(h: s.h, s: 0.16, b: 1.0),
            // §5.4 holds in the dark too: a neutral black edge against warm
            // material reads as soot.
            edgeShade:      Color(h: s.h, s: min(s.s * 1.5, 1), b: 0.03),
            seam:           Color(h: s.h, s: s.s * 0.7, b: 0.36),
            outline:        Color(h: s.h, s: min(s.s * 1.5, 1), b: 0.09),
            outlineBottom:  Color(h: s.h, s: s.s * 0.9, b: 0.34),
            // Already clears the dark `materialTop` of 0.26; lifted a little
            // further so a raised edge reads as lit rather than merely paler.
            outlineLit:     Color(h: s.h, s: s.s * 0.8, b: 0.42),

            ink:            Color(h: s.h, s: 0.10, b: 0.96),
            inkMuted:       Color(h: s.h, s: 0.16, b: 0.74),
            inkFaint:       Color(h: s.h, s: 0.20, b: 0.55),
            inkOnAccent:    Color(h: acc.h, s: 0.08, b: 0.99),

            accent:         Color(h: acc.h, s: acc.s * 0.95, b: min(acc.b * 1.25, 0.86)),
            accentTop:      Color(h: acc.h, s: acc.s * 0.85, b: min(acc.b * 1.45, 0.95)),
            accentBottom:   Color(h: acc.h, s: acc.s,        b: min(acc.b * 1.05, 0.70)),

            positive:       Color(h: 0.35, s: 0.42, b: 0.72),
            caution:        Color(h: 0.10, s: 0.60, b: 0.86),
            // Saturation, not brightness, is what was missing here. At 0.55
            // the dark-mode strike came out coral — bright enough and not RED
            // enough, which is the half of the complaint the light branch did
            // not answer (founder direction 2026-08-17).
            critical:       Color(h: 0.02, s: 0.60, b: 1.00),

            shadow:         Color(h: s.h, s: min(s.s * 1.5, 1), b: 0.04),
            shadowIntensity: 0.9,
            isDark:         true
        )
    }
}
