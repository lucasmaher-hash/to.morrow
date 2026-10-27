//
//  LiveGlyph.swift
//  shove95
//
//  The mark on the Live tab: a ring with a filled core.
//
//  It carries no word (founder direction 2026-08-17). A label would repeat
//  what the shape already says, and the frame is a square — there is room for
//  one or the other, not both.
//
//  A record button is the right borrowing here. Every phone owner already
//  reads ring-around-a-dot as "this is on the air", which is exactly what the
//  Live section means: one thing, showing on the Lock Screen, right now.
//

import SwiftUI

/// Skeu's drawing: two true circles, stroked and filled.
struct LiveGlyph: View {
    let tint: Color
    let lineWidth: CGFloat

    var body: some View {
        Circle()
            .strokeBorder(tint, lineWidth: lineWidth)
            // 0.42 of the diameter. Smaller and the core reads as a speck in
            // an empty ring; larger and the gap closes and the two shapes
            // merge into one blob at tab size.
            .overlay { Circle().fill(tint).scaleEffect(0.42) }
    }
}

/// The same mark on a pixel grid.
///
/// Not the soft one re-tinted — a true circle stroked at 1.7pt lands on
/// fractional pixels at every scale step, which a pixel grid does not bend on.
/// Drawn on an 11×11 grid instead, as a ring of whole cells around a 3×3 core.
struct PixelLiveGlyph: View {
    let pixel: CGFloat
    let tint: Color

    /// Filled cells. The ring is a circle quantised to the grid; the core is
    /// the middle 3×3 with a clear cell all the way round it.
    private static let cells: [(Int, Int)] = {
        var c: [(Int, Int)] = []
        let centre = 5.0
        for y in 0...10 {
            for x in 0...10 {
                let d = ((Double(x) - centre) * (Double(x) - centre)
                       + (Double(y) - centre) * (Double(y) - centre)).squareRoot()
                if d > 3.6 && d < 5.2 { c.append((x, y)) }      // the ring
                if d < 1.6 { c.append((x, y)) }                 // the core
            }
        }
        return c
    }()

    var body: some View {
        ZStack(alignment: .topLeading) {
            Color.clear
            ForEach(Array(Self.cells.enumerated()), id: \.offset) { _, cell in
                Rectangle()
                    .fill(tint)
                    .frame(width: pixel, height: pixel)
                    .offset(x: CGFloat(cell.0) * pixel, y: CGFloat(cell.1) * pixel)
            }
        }
        .frame(width: 11 * pixel, height: 11 * pixel)
    }
}
