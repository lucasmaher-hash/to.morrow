import Foundation

/// Placement-on-event ordering (PRD §3 placement table).
///
/// Tiers decide where a task is INSERTED — on creation, arrival, flagging, and
/// the day-rollover pass. After that, the user's manual order wins and nothing
/// ever moves on its own (locked decision Q17-B). These functions are pure:
/// they compute sortOrder values; the store applies them.
///
/// All `visible` arrays are the destination tab's *visible incomplete* tasks,
/// sorted ascending by `sortOrder`.
public enum Placement {

    // MARK: - Insertion values

    /// New task via the add row → bottom of the incomplete section.
    ///
    /// `allInBucket` is EVERY task currently mapping to the bucket — including
    /// completed ones. Completed tasks keep their sortOrder (that's how
    /// unticking restores the exact position), so the bottom anchor must clear
    /// them too. Anchoring only on visible actives can hand a new task the
    /// same sortOrder as a ticked task; when that task is unticked the tie
    /// resolves arbitrarily and it lands at the bottom instead of its old spot
    /// (bug report 2026-08-04).
    public static func sortOrderForNewTask(allInBucket: [TaskItem]) -> Double {
        (allInBucket.map(\.sortOrder).max() ?? 0) + 1
    }

    /// A moved task always arrives at the very top, regardless of importance
    /// (founder update 2026-10-25, replacing Q16). Include completed tasks in
    /// the anchor so unticking one cannot collide with the arriving task.
    public static func sortOrderForArrival(
        isImportant _: Bool, visible _: [TaskItem], allInBucket: [TaskItem]
    ) -> Double {
        (allInBucket.map(\.sortOrder).min() ?? 0) - 1
    }

    /// Flagging Important → jumps to the very top of the tab (locked Q17).
    /// Unflagging assigns nothing — the task stays where it is.
    public static func sortOrderForFlagImportant(visible: [TaskItem]) -> Double {
        (visible.first?.sortOrder ?? 0) - 1
    }

    /// Drag-reorder between two neighbors (either may be absent at the ends).
    public static func sortOrder(between above: Double?, and below: Double?) -> Double {
        switch (above, below) {
        case let (a?, b?): midpoint(a, b)
        case let (a?, nil): a + 1
        case let (nil, b?): b - 1
        case (nil, nil): 0
        }
    }

    // MARK: - Day-rollover pass (PRD §3)

    /// Positions for tasks that have newly become overdue: non-important,
    /// `isOverdue && !overduePlaced`, ordered by (dueDate, sortOrder). They are
    /// inserted after the important block and any previously placed overdue
    /// tasks, before today's normal tasks. Tasks the user has since dragged
    /// (`overduePlaced == true`) are never touched again. Important tasks are
    /// skipped — they already live in the top tier by their own placement.
    ///
    /// `visibleToday`: Today's visible incomplete tasks, ascending sortOrder.
    /// Returns (task, newSortOrder) pairs; the store applies them and sets
    /// `overduePlaced = true` on every newly-overdue task (important included).
    public static func rolloverPlacements(
        visibleToday: [TaskItem], now: Date, calendar: Calendar
    ) -> [(task: TaskItem, sortOrder: Double)] {
        let newlyOverdue = visibleToday
            .filter {
                !$0.isImportant && !$0.overduePlaced
                    && $0.isOverdue(now: now, calendar: calendar)
            }
            .sorted {
                let a = ($0.dueDate ?? .distantPast, $0.sortOrder)
                let b = ($1.dueDate ?? .distantPast, $1.sortOrder)
                return a < b
            }
        guard !newlyOverdue.isEmpty else { return [] }

        // Upper boundary: last task of the existing top block
        // (importants + already-placed overdue).
        let topBlock = visibleToday.filter { $0.isImportant || $0.overduePlaced }
        // Lower boundary: first normal task (not important, not placed-overdue,
        // not itself newly overdue).
        let newlyIDs = Set(newlyOverdue.map(\.persistentModelID))
        let firstNormal = visibleToday.first {
            !$0.isImportant && !$0.overduePlaced && !newlyIDs.contains($0.persistentModelID)
        }

        let low = topBlock.last?.sortOrder
        let high = firstNormal?.sortOrder
        let slots = evenlySpaced(count: newlyOverdue.count, above: low, below: high)
        return zip(newlyOverdue, slots).map { (task: $0, sortOrder: $1) }
    }

    // MARK: - Fractional-order hygiene

    public static func midpoint(_ a: Double, _ b: Double) -> Double {
        (a + b) / 2
    }

    /// True when neighbor gaps have collapsed below usable precision.
    public static func needsRenormalization(visible: [TaskItem]) -> Bool {
        for (a, b) in zip(visible, visible.dropFirst()) where abs(b.sortOrder - a.sortOrder) < 1e-9 {
            return true
        }
        return false
    }

    /// Fresh integer sortOrders preserving relative order.
    public static func renormalized(visible: [TaskItem]) -> [(task: TaskItem, sortOrder: Double)] {
        visible.enumerated().map { (task: $1, sortOrder: Double($0)) }
    }

    // MARK: - Helpers

    /// `count` values strictly between the optional bounds.
    private static func evenlySpaced(count: Int, above low: Double?, below high: Double?) -> [Double] {
        switch (low, high) {
        case let (l?, h?):
            let step = (h - l) / Double(count + 1)
            return (1...count).map { l + step * Double($0) }
        case let (l?, nil):
            return (1...count).map { l + Double($0) }
        case let (nil, h?):
            return (1...count).map { h - Double(count + 1 - $0) }
        case (nil, nil):
            return (0..<count).map(Double.init)
        }
    }
}
