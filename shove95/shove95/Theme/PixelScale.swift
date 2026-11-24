//
//  PixelScale.swift
//  shove95
//
//  The pixel unit, and the hex initialiser everything else builds colours with.
//
//  These two outlived the interface they were written for. The unit came from
//  the Windows 95 look, where the rule was that nothing hard-codes a point
//  value the spec expresses in 1995 pixels; that look was removed on
//  2026-08-22, but the launch mark is still drawn on its grid and still scales
//  with it. `Color(hex:)` is what every palette in the app is written in.
//

import SwiftUI

// MARK: - The pixel unit

extension EnvironmentValues {
    /// One 1995 pixel in points. 2 = default scale; 3/4 = stepped Dynamic Type.
    @Entry var pixel: CGFloat = 2
}

// MARK: - Stepped Dynamic Type (FR-015)

/// Whole-pixel steps, like changing the resolution on a CRT rather than
/// zooming. Whole multiples keep the bitmap-derived face crisp — continuous
/// scaling would land it on fractional sizes and turn it to mush.
struct PixelScale: ViewModifier {
    @Environment(\.dynamicTypeSize) private var typeSize

    private var pixel: CGFloat {
        switch typeSize {
        case .xSmall, .small, .medium, .large, .xLarge: 2
        case .xxLarge, .xxxLarge, .accessibility1, .accessibility2: 3
        default: 4 // accessibility3 and above
        }
    }

    func body(content: Content) -> some View {
        content.environment(\.pixel, pixel)
    }
}

// MARK: - Colours from hex

extension Color {
    /// The alpha parameter is SkeuKit's requirement (design system §2.7).
    init(hex: UInt32, alpha: Double = 1) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: alpha
        )
    }
}
