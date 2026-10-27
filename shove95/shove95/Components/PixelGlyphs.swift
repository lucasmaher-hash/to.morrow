//
//  PixelGlyphs.swift
//  shove95
//
//  The three pixel marks the Retro face still needs.
//
//  They were drawn for the Windows 95 interface and lived in its chrome; that
//  interface was removed on 2026-08-22, but these outlived it.
//  `SkeuChromeGlyph` swaps an SF Symbol for one of these whenever the reader
//  has chosen the Retro typeface, so the gear and the ✕ match the lettering
//  beside them rather than sitting in two different centuries.
//
//  Drawn on a unit grid rather than lettered: SF Symbols are a system face, and
//  a pixel mark has to land on whole pixels at 2×, 3× and 4× alike.
//

import SwiftUI

/// Pixel cog on a 12×12 grid: a hollow two-unit ring, four square teeth and
/// four corner nubs. Solid bodies turn to mush at 24pt — the hole is what makes
/// it read as a gear.
/// Shared with the skeu look: under Retro or Blend its top bar takes these
/// pixel glyphs instead of SF Symbols, so the chrome matches the type.
struct GearGlyph: Shape {
    func path(in rect: CGRect) -> Path {
        let u = rect.width / 12
        func block(_ x: CGFloat, _ y: CGFloat, _ w: CGFloat, _ h: CGFloat) -> CGRect {
            CGRect(x: x * u, y: y * u, width: w * u, height: h * u)
        }
        var path = Path()
        // Ring — two units thick, hollow centre at cols/rows 4...7.
        path.addRect(block(2, 2, 8, 2)) // top
        path.addRect(block(2, 8, 8, 2)) // bottom
        path.addRect(block(2, 2, 2, 8)) // left
        path.addRect(block(8, 2, 2, 8)) // right
        // Teeth
        path.addRect(block(5, 0, 2, 2))  // N
        path.addRect(block(5, 10, 2, 2)) // S
        path.addRect(block(0, 5, 2, 2))  // W
        path.addRect(block(10, 5, 2, 2)) // E
        // Corner nubs
        path.addRect(block(1, 1, 1, 1))
        path.addRect(block(10, 1, 1, 1))
        path.addRect(block(1, 10, 1, 1))
        path.addRect(block(10, 10, 1, 1))
        return path
    }
}

/// Pixel ✕ for window close controls.
struct CloseGlyph: Shape {
    func path(in rect: CGRect) -> Path {
        let u = rect.width / 8
        var path = Path()
        for i in 0..<6 {
            path.addRect(CGRect(x: CGFloat(i + 1) * u, y: CGFloat(i + 1) * u, width: u, height: u))
            path.addRect(CGRect(x: CGFloat(6 - i) * u, y: CGFloat(i + 1) * u, width: u, height: u))
        }
        return path
    }
}

/// The checkmark drawn as pixel blocks on a 12×12 grid — no SF Symbols
/// (design.md §9 prohibits them).
///
/// Shared with the skeu look: under Retro or Blend its tick takes this shape
/// instead of the system symbol, so a ticked task matches the type beside it.
struct CheckmarkGlyph: Shape {
    func path(in rect: CGRect) -> Path {
        let u = rect.width / 12 // one 1995 pixel
        // (column, row) blocks, each 1×2 pixels, forming the classic tick.
        let blocks: [(CGFloat, CGFloat)] = [
            (2, 5), (2, 6),
            (3, 6), (3, 7),
            (4, 7), (4, 8),
            (5, 6), (5, 7),
            (6, 5), (6, 6),
            (7, 4), (7, 5),
            (8, 3), (8, 4),
        ]
        var path = Path()
        for (col, row) in blocks {
            path.addRect(CGRect(x: col * u, y: row * u, width: u, height: u))
        }
        return path
    }
}
