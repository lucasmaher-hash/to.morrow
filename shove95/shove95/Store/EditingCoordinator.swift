//
//  EditingCoordinator.swift
//  shove95
//
//  Which field currently holds the keyboard, hoisted out of the rows so the
//  LIST can react to it. A row knows it is being edited; only the list can
//  scroll it clear of the keyboard.
//

import SwiftUI
import Shove95Kit

@Observable @MainActor
final class EditingCoordinator {
    /// The task being edited, the add row (`addRowID`), or nil.
    var focused: String?

    /// The focused field's bottom edge in global coordinates. The list needs
    /// it to answer the only question that matters: is this field actually
    /// under the keyboard? A field already in the clear must not be yanked.
    var focusedBottom: CGFloat = 0

    /// Scroll identity for the permanent capture row at the bottom of a list.
    static let addRowID = "add-row"

    /// Scroll identity for one section's capture row. Soon carries an add row
    /// under General and under every day rather than one at the foot of the
    /// list, so the ids have to tell them apart (founder direction
    /// 2026-08-17). A nil day is the undated section, and keeps the plain id
    /// so every other tab's single row is unchanged.
    static func addRowID(for day: Date?) -> String {
        guard let day else { return addRowID }
        return "\(addRowID)-\(Int(day.timeIntervalSinceReferenceDate))"
    }

    /// The add row that last committed a task. The list follows its add row
    /// down as the list grows — with one row per section, "its" means the one
    /// that was just typed into, not the one at the bottom.
    var lastAddRowID: String?

    /// A task whose editing should resume the moment its row next appears.
    ///
    /// Giving a task a day in Soon moves it into that day's block, and a row
    /// that changes block is not the same view any more: SwiftUI tears the old
    /// one down and builds a fresh one, taking the edit with it. Rather than
    /// hoist every scrap of a row's editing state up here to survive that, the
    /// row hands over one id on its way out and the new row picks the edit up
    /// on the way in (founder direction 2026-08-17).
    ///
    /// The LIST watches this too, and scrolls to the id. It has to: the list
    /// is lazy, so a task sent to a day below the fold has no row to appear
    /// and no `onAppear` to fire — the handover was simply dropped, and the
    /// task moved with the edit silently ending (founder bug report
    /// 2026-08-22, "es klappt immer noch nicht"). Scrolling there is what
    /// builds the row that then picks the edit up.
    var reopenTaskID: UUID?

    /// A tab the list should travel to, because a task just took the edit
    /// there.
    ///
    /// Giving a task today's or tomorrow's date moves it out of Soon
    /// altogether, and `reopenTaskID` alone cannot follow it — the row's new
    /// home is on a tab that is not on screen. The row names the destination
    /// and the list goes there, which is what makes "the task moves at once"
    /// true for every date rather than only for the ones that happen to stay
    /// put (founder direction 2026-08-22).
    var followTo: Bucket?

    func begin(_ id: String, bottom: CGFloat) {
        focused = id
        focusedBottom = bottom
    }

    /// Only the field that claimed focus may release it — a stale row losing
    /// focus after another has taken it must not clear the new one.
    func end(_ id: String) {
        if focused == id {
            focused = nil
            focusedBottom = 0
        }
    }
}
