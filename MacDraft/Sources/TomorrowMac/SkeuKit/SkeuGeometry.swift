//
//  SkeuGeometry.swift
//  shove95
//
//  Geometry tokens (§3): radius, stroke, control height, spacing.
//

import SwiftUI

// MARK: - Corner radius (§3.1)

/// ALWAYS `.continuous`. A `.circular` corner reads as cheap in this system.
enum SkeuRadius {
    static let xs: CGFloat = 8     // badges, tiny chips
    static let sm: CGFloat = 12    // inline controls, small wells
    static let md: CGFloat = 16    // buttons, list rows
    static let lg: CGFloat = 22    // cards, panels
    static let xl: CGFloat = 28    // sheets, large tiles
    static let xxl: CGFloat = 40   // hero tiles, app-icon-like objects
    static let pill: CGFloat = 999 // capsules
}

/// The nesting law: a child inside a padded parent takes the parent's radius
/// minus that padding. Concentric corners are mandatory — getting this wrong is
/// the single most visible amateur tell in the whole system.
func nestedRadius(_ parent: CGFloat, inset: CGFloat) -> CGFloat {
    max(parent - inset, SkeuRadius.xs)
}

/// Convenience for the shape every surface uses.
///
/// `pill` resolves to a real `Capsule`, not a 999pt rounded rectangle: a
/// continuous corner that large renders with visible straight-edge artefacts
/// where the curve overruns the box (seen on the accent button, 2026-08-13).
func skeuShape(_ radius: CGFloat) -> AnyShape {
    radius >= SkeuRadius.pill
        ? AnyShape(Capsule())
        : AnyShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
}

// MARK: - Strokes (§3.2)

enum SkeuStroke {
    static let rim: CGFloat = 1.0       // rim light / rim shade
    static let rimThick: CGFloat = 1.5  // on ≥ 28pt radius surfaces
    static let focus: CGFloat = 2.5     // keyboard / VoiceOver focus ring
}

// MARK: - Control heights (§3.3)

enum SkeuControl {
    static let xs: CGFloat = 28
    static let sm: CGFloat = 36
    static let md: CGFloat = 44 // default — matches the HIG minimum
    static let lg: CGFloat = 54
    static let xl: CGFloat = 64

    /// Minimum tap target regardless of visual size. Expand with
    /// `.contentShape(Rectangle())` rather than by growing the artwork.
    static let minTouch: CGFloat = 44
}

// MARK: - Top-bar control

/// The round control in the top-right corner: the gear on the main screen, the
/// ✕ on every sheet. Shared rather than defined twice, because the two are the
/// same button in two states — a sheet opens from the gear and closes back to
/// it, so any drift in size or position reads as the button jumping (founder
/// direction 2026-08-14).
///
/// Multiply by the chrome scale at the call site for Dynamic Type.
enum SkeuTopBar {
    /// 37 × 1.2 — the frame's round button at the top bar's own +20%.
    static let control: CGFloat = 44.4
    /// 18.5 × 1.2 — its glyph.
    static let icon: CGFloat = 22.2
    /// Distance below the safe area. Matches the main screen's top bar.
    static let inset: CGFloat = 6.0
    /// Page-edge inset, horizontal.
    static let margin: CGFloat = 21.5
}

// MARK: - Spacing (§7)

enum SkeuSpace {
    static let xxs: CGFloat = 2
    static let xs: CGFloat = 4
    static let sm: CGFloat = 8
    static let md: CGFloat = 12
    static let lg: CGFloat = 16
    static let xl: CGFloat = 20
    static let xxl: CGFloat = 28
    static let xxxl: CGFloat = 40

    /// Screen horizontal margin.
    static let screenMargin: CGFloat = xl
}
