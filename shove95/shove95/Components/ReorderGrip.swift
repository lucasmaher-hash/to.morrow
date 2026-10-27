//
//  ReorderGrip.swift
//  shove95
//
//  Three lines at the right of a task: the handle you drag it by.
//
//  It is QUIET at rest and full strength under the finger (founder direction
//  2026-08-23). The resting strength is the day chip's, so the two things at
//  the right of a row are one weight rather than two — the chip lost a quarter
//  of its own opacity in the same pass, and this followed it down.
//
//  Pinned to the FIRST LINE, not centred on the row. A task that runs to five
//  lines is still one task, and a handle floating at its middle reads as
//  belonging to the words beside it rather than to the row.
//

import SwiftUI

struct ReorderGrip: View {
    @Environment(\.skeu) private var skeu
    /// True while this row is the one being dragged.
    let isActive: Bool
    /// The glyph's own size, and the height of the first line's band.
    let size: CGFloat
    let bandHeight: CGFloat

    // The two opacity constants that used to live here are gone with the
    // move to `inkFaint` (founder direction 2026-09-01): the grip sat at 0.58
    // over `ink` and the day chip at 0.72, and neither has a caller now.
    //
    // Worth keeping the finding they carried, since it is the reason nobody
    // should reach for a DIMMED `inkFaint` here: dimming the muted token
    // compounds two reductions, and at the 0.45 once asked for it measured
    // 1.90:1 — roughly half the floor, effectively invisible in daylight
    // (measured in review 2026-08-26). `inkFaint` at FULL strength is 3.4:1
    // and fine; `inkFaint` faded is not.

    var body: some View {
        // Apple's own mark for this, and the one every reader already knows
        // from a list they can rearrange.
        Image(systemName: "line.3.horizontal")
            .font(SkeuFont.at(size, weight: .medium))
            .symbolRenderingMode(.hierarchical)
            // THE "add" PLACEHOLDER'S INK, exactly (founder direction
            // 2026-09-01). It was `ink` dimmed to `restingOpacity`, which
            // landed near this but not on it, so the grip and the day chip
            // read as a slightly different grey from the "add" row a few
            // lines below them — three quiet things in a list, none of them
            // quiet in the same way. `inkFaint` is one token, so they now
            // match in every theme and in both light and dark by
            // construction rather than by coincidence.
            //
            // Still 3.4:1, which clears the 3:1 WCAG 1.4.11 asks of a
            // control's affordance.
            .foregroundStyle(isActive ? skeu.ink : skeu.inkFaint)
            // A 44pt target around a small glyph: this is the one control on
            // the row you have to find without looking, because your eye is on
            // where the task is going.
            .frame(width: SkeuControl.minTouch, height: bandHeight)
            .contentShape(Rectangle())
            .accessibilityLabel("Reorder")
            .accessibilityHint("Drag to move this task up or down")
    }
}
