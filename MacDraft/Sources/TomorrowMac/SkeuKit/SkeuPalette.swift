//
//  SkeuPalette.swift
//  shove95
//
//  The complete colour contract of the skeuomorphic design system (§2.2).
//  Swapping the instance in the environment re-skins every screen — that is the
//  acceptance test for the whole system: if a screen needs editing to change
//  theme, the screen is wrong.
//
//  Roles are SEMANTIC (`material`, `recess`, `ink`, `accent`), never literal
//  (`brown`, `cream`). A component that wants "the light brown one" is reaching
//  past the contract.
//

import SwiftUI

struct SkeuPalette: Equatable, Sendable {

    // MARK: Ground

    /// The page behind everything. Always the DARKEST light-mode neutral among
    /// the surface roles, so raised material reads as lifted (Law 3).
    var canvas: Color
    /// Secondary ground for grouped/sectioned scenes.
    var canvasAlt: Color

    // MARK: Material (raised surfaces)

    /// Body colour of a raised object. The gradient stops derive from this.
    var material: Color
    /// Top stop of the material gradient (lighter).
    var materialTop: Color
    /// Bottom stop of the material gradient (darker).
    var materialBottom: Color

    // MARK: Recess (carved-in surfaces)

    /// Fill of wells, tracks, input fields, inset containers.
    var recess: Color
    /// Bottom stop of the recess gradient — LIGHTER, because light pools at the
    /// base of a cavity (§4.3).
    var recessBottom: Color

    // MARK: Edges

    /// Rim light on top edges. Applied at ≤ 0.60 alpha, never as a glow (Law 2).
    var edgeLight: Color
    /// Rim shade on bottom edges.
    var edgeShade: Color
    /// Hairline separating stacked material of the same elevation.
    var seam: Color
    /// Top stop of the contour around a carved-in element — the darkest value
    /// in the whole palette.
    ///
    /// The contour is a GRADIENT stroke, dark at the top and light at the
    /// bottom, and it is the last thing drawn (founder's construction order:
    /// bloom → trough → stroke). It was first built as a flat `#85141a`,
    /// because that is what Figma's code export reduces a gradient stroke to —
    /// the export cannot represent one. Flat, it reads as a drawn outline;
    /// graded, it reads as the lip of a channel catching light on its far side.
    var outline: Color
    /// Bottom stop of the contour — lighter, the lit far lip.
    var outlineBottom: Color
    /// The lit edge of a RAISED frame — its top, where the key light lands.
    ///
    /// Separate from `outlineBottom` because the two describe opposite
    /// geometries: a trough's lit lip is its FAR one at the bottom, sitting
    /// against `recessBottom`, while a card's is its NEAR one at the top,
    /// sitting against `materialTop`. One value cannot clear both — tuned for
    /// the card it turned the trough's lip into a hard white stripe (founder
    /// bug report 2026-08-16).
    var outlineLit: Color

    // MARK: Ink

    var ink: Color          // primary text/icons on material
    var inkMuted: Color     // secondary text, ≥ 4.5:1 required
    var inkFaint: Color     // decorative labels, ≥ 3:1 required
    var inkOnAccent: Color  // text on accent fills

    // MARK: Accent

    var accent: Color
    var accentTop: Color
    var accentBottom: Color

    // MARK: Semantic

    var positive: Color
    var caution: Color
    var critical: Color

    // MARK: Shadow

    /// Shadows are TINTED — a dark, saturated version of the material hue.
    /// Never black: a neutral shadow makes warm material look dirty (§5.4).
    var shadow: Color
    /// Global multiplier on every shadow alpha. Lower on dark themes.
    var shadowIntensity: Double

    /// Flips a few internal rules (rim-light strength, shadow intensity)
    /// without requiring a single component to branch.
    var isDark: Bool
}

// MARK: - The shipping default (§2.4)

extension SkeuPalette {

    /// Cream everywhere, caramel accent.
    ///
    /// ONE BASE COLOUR. `canvas`, `material` and `recess` are the same value —
    /// the page, the frames and the buttons are cut from a single piece of
    /// stock, and the ONLY thing that separates them is how the light falls
    /// (founder direction 2026-08-13, from the reference: the red bar and the
    /// leather behind it are the same red).
    ///
    /// This is a deliberate departure from §2.2, which puts canvas below
    /// material in brightness, and it moves the system toward the neumorphic
    /// edge §1.3 warns about. What keeps it out of that ditch is everything
    /// else staying in force: asymmetric directional shadows, a diagonal key
    /// light, and real rim shade. Flat-and-symmetric is what makes neumorphism
    /// mushy — sameness of hue is not.
    ///
    /// Consequence for anyone adding a surface: depth now comes ENTIRELY from
    /// `skeuSurface`. A view that skips it will vanish into the page, where
    /// before it merely looked wrong.
    ///
    /// Base hue pulled from 40° to 28° and desaturated a step — the earlier
    /// #EADFC9 read yellow (founder note 2026-08-13). Same warmth, no jaundice.
    ///
    /// The recess pair comes from the reference's own ratios rather than being
    /// invented: trough top at 0.76× the base brightness, trough floor at
    /// 0.955×, outline at 0.59× — the proportions between #aa171f, #d7434f and
    /// #85141a against that file's #e03d4a ground.
    /// Light brown, transposed hue-for-hue from the founder's main-screen frame
    /// (shove95 file, node 2:183). Every value below is that frame's red at
    /// hue 28° and 0.41 saturation, with the brightness and saturation RATIOS
    /// between roles preserved exactly:
    ///
    ///   role        frame      B ratio   S ratio
    ///   material    #e03d4a     1.000     1.000
    ///   canvas      #bf2c35     0.853     1.061
    ///   recess      #aa171f     0.760     1.191
    ///   recessBtm   #d7434f     0.960     0.954
    ///   outline     #85141a     0.594     1.171
    ///
    /// Note that canvas is DARKER than material here. The nav-bar reference had
    /// them equal, and that reading was carried over too eagerly — the finished
    /// screen puts its cards on a deeper ground, and the cards are what the
    /// white rim is drawn against.
    /// LIGHT means light (founder direction 2026-08-16). The values below used
    /// to be a mid-brown carrying white text — the frame this look was
    /// transcribed from is the DARK one, and the light half inherited its
    /// white-on-brown relationship at a slightly raised brightness. It read as
    /// a dimmer dark theme, and it measured 3.42:1 against a 4.5:1 bar.
    ///
    /// The base moves to 0.88 brightness and the ink to near-black. Every
    /// other role is the SAME multiplier of the base as before, so the ladder
    /// — near wall at 0.76×, floor at 0.955×, contour at 0.60×, lit lip at
    /// 1.02× — is unchanged. Only where the ladder stands has moved.
    ///
    /// Two things had to be re-thought rather than re-scaled, because light
    /// material does not behave like dark material:
    ///
    /// **The rim needs headroom.** `edgeLight` is white, and `materialTop` was
    /// `base × 1.10`. At a light base that clamps to white as well, and a
    /// white rim on a white surface is no rim at all. The top stop is held at
    /// 0.93 so the rim still out-shines what it sits on.
    ///
    /// **Shadow does the work now.** On a dark surface a bright rim carries
    /// the depth; on a light one there is nowhere brighter to go, so the
    /// contact shade and the drop shadow are what separate an object from the
    /// page. `edgeShade` and `shadow` therefore keep their strength instead of
    /// being lightened along with everything else.
    static let cream = SkeuPalette(
        canvas:         Color(hex: 0xD6C3B2), // the ground, a step under material
        canvasAlt:      Color(hex: 0xD6C3B2),

        material:       Color(hex: 0xE0CEBE),
        materialTop:    Color(hex: 0xEDDED1), // held off white — see above
        materialBottom: Color(hex: 0xC1AF9F),

        recess:         Color(hex: 0xAB937E), // trough top — the near wall, in shade
        recessBottom:   Color(hex: 0xD6C1AE), // trough floor — light pools here

        edgeLight:      .white,
        edgeShade:      Color(hex: 0x5E5145),
        seam:           Color(hex: 0xFFF8F2),
        outline:        Color(hex: 0x877260), // 0.60 brightness of material
        // Brighter than the material itself, but only just (1.02×). The far lip
        // is a highlight catching the key light, so it has to out-shine the
        // surface it is cut into — at 0.75× it read as a washed-out edge rather
        // than a lit one. 1.09× overshot and turned into a chrome piping.
        outlineBottom:  Color(hex: 0xE5D9CE),
        // Clear of `materialTop` (0xEDDED1). At the trough's 0xE5D9CE it sat
        // 0.031 BELOW the surface it borders, so a raised frame's top edge was
        // darker than the frame itself and the lift vanished.
        outlineLit:     Color(hex: 0xFCF5EF),

        // Black, warmed just enough not to read as a foreign neutral against
        // the material. 10.9:1 on `material` — the old white managed 3.42.
        ink:            Color(hex: 0x241D17),
        inkMuted:       Color(hex: 0x57493D), // 5.7:1
        inkFaint:       Color(hex: 0x806E5F), // 3.2:1
        inkOnAccent:    Color(hex: 0xFBF3EA), // white now — the accent went dark

        // Deepened with the base move. The old caramel was chosen against a
        // mid-brown material; on the light one it measured 1.9:1 and the pin
        // glyph all but vanished. 3.7:1 now — the bar for a graphic that
        // carries meaning. Still unmistakably caramel, just further down it.
        accent:         Color(hex: 0x9A6630),
        accentTop:      Color(hex: 0xB07A3F),
        accentBottom:   Color(hex: 0x7E5223),

        // Deepened for the same reason. These three are read as TEXT — an
        // overdue title is critical-coloured — so they answer to 4.5:1, not
        // 3:1. Critical was 3.58:1 against the light material and is 4.7 now.
        positive:       Color(hex: 0x46613C),
        caution:        Color(hex: 0x8A6320),
        critical:       Color(hex: 0x6B180D), // darkened to 4.6:1 — see the derived palette

        shadow:         Color(hex: 0x2E1F12),
        shadowIntensity: 1.0,
        isDark:         false
    )

    /// The dark half of Cream — WARM BROWN, not a neutral dark.
    ///
    /// Hand-written rather than derived. §2.3's dark ladder drops material to
    /// 20% brightness while cutting saturation to 0.72×, and Cream's seed is
    /// only lightly saturated to begin with; the product came out effectively
    /// grey (founder report). The whole point of the pair is that the app stays
    /// the same MATERIAL in the dark, only unlit, so the hue is held and the
    /// brightness alone falls away.
    /// Hue held at 25° to match the entgelbte light half — the dark was reading
    /// orange for the same reason the light was reading yellow.
    static let creamDark = SkeuPalette(
        canvas:         Color(hex: 0x2E2119),
        canvasAlt:      Color(hex: 0x2E2119),

        material:       Color(hex: 0x2E2119),
        materialTop:    Color(hex: 0x3E2E24),
        materialBottom: Color(hex: 0x241A13),

        recess:         Color(hex: 0x1A120D), // trough top
        recessBottom:   Color(hex: 0x362720), // trough floor

        edgeLight:      Color(hex: 0xFFEEE0),
        edgeShade:      Color(hex: 0x0A0705),
        seam:           Color(hex: 0x6F5B4C),
        outline:        Color(hex: 0x1A130D),
        outlineBottom:  Color(hex: 0x5E4634),
        outlineLit:     Color(hex: 0x6E5240),

        ink:            Color(hex: 0xF2E7DC),
        inkMuted:       Color(hex: 0xBFAC9E), // 6.4:1 on material
        inkFaint:       Color(hex: 0x8F7F72), // 3.4:1 — decorative only
        inkOnAccent:    Color(hex: 0x241812),

        accent:         Color(hex: 0xC08C6C),
        accentTop:      Color(hex: 0xD4A587),
        accentBottom:   Color(hex: 0x9C6B4E),

        positive:       Color(hex: 0x8AA37B),
        caution:        Color(hex: 0xD9A94E),
        critical:       Color(hex: 0xFF7866), // lifted to 5.2:1 — see the derived palette

        shadow:         Color(hex: 0x080503),
        shadowIntensity: 0.9,
        isDark:         true
    )
}
