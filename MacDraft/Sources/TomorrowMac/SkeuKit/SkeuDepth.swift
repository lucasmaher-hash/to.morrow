//
//  SkeuDepth.swift
//  shove95
//
//  The depth ladder (§4.1) and the numbers behind it (§4.4).
//
//  Law 4: depth is a LADDER, not a spectrum. A component picks exactly one rung.
//  There is no "a bit more shadow" — if a design needs an in-between value, the
//  ladder is wrong, not the component.
//

import SwiftUI

enum SkeuDepth: Int, CaseIterable {
    /// Cut deep into the ground — slider tracks, progress rails.
    case carved = 0
    /// Pressed inward — input fields, wells, pressed buttons, selected segments.
    case recessed
    /// Sitting on the surface — list rows inside a card, quiet chips.
    case flush
    /// Lifted and pressable — buttons, cards, tiles. THE default object.
    case raised
    /// Hovering above content — floating toolbars, FABs, popovers.
    case floating
    /// Detached from the page — sheets, modals, dialogs.
    case overlay
}

extension SkeuDepth {
    struct Shadow {
        let radius: CGFloat
        let y: CGFloat
        let alpha: Double
    }

    /// Wide and soft, offset down by roughly a third of its blur.
    var ambient: Shadow? {
        switch self {
        case .carved, .recessed: nil
        case .flush:    Shadow(radius: 6,  y: 2,  alpha: 0.10)
        case .raised:   Shadow(radius: 16, y: 7,  alpha: 0.22)
        case .floating: Shadow(radius: 28, y: 13, alpha: 0.28)
        case .overlay:  Shadow(radius: 46, y: 21, alpha: 0.34)
        }
    }

    /// Tight and darker. This is what grounds the object.
    var contact: Shadow? {
        switch self {
        case .carved, .recessed: nil
        case .flush:    Shadow(radius: 1, y: 1, alpha: 0.12)
        case .raised:   Shadow(radius: 3, y: 2, alpha: 0.26)
        case .floating: Shadow(radius: 5, y: 3, alpha: 0.28)
        case .overlay:  Shadow(radius: 7, y: 4, alpha: 0.30)
        }
    }

    /// Cast from the top edge downward. Recessed surfaces only — a recessed
    /// object never casts an OUTER shadow (§4.3).
    var inner: Shadow? {
        switch self {
        case .carved:   Shadow(radius: 7, y: 4, alpha: 0.55)
        case .recessed: Shadow(radius: 5, y: 3, alpha: 0.42)
        default:        nil
        }
    }

    /// Capped at 0.60 — Law 2's ceiling on any highlight in the system. The
    /// extra plasticity the founder asked for comes from the rim SHADE, the
    /// heavier shadows and the diagonal light, none of which are capped.
    var rimLight: Double {
        switch self {
        case .carved: 0.45; case .recessed: 0.38; case .flush: 0.40
        case .raised: 0.60; case .floating: 0.60; case .overlay: 0.60
        }
    }

    var rimShade: Double {
        switch self {
        case .carved: 0.40; case .recessed: 0.32; case .flush: 0.20
        case .raised: 0.42; case .floating: 0.46; case .overlay: 0.50
        }
    }

    /// One step down the ladder. Law 5: pressing COSTS depth.
    var pressed: SkeuDepth {
        switch self {
        case .carved, .recessed: .carved
        case .flush:    .recessed
        case .raised:   .recessed
        case .floating: .raised
        case .overlay:  .overlay
        }
    }

    /// True for the two rungs that sit below the plane.
    var isRecessed: Bool { rawValue <= SkeuDepth.recessed.rawValue }
}
