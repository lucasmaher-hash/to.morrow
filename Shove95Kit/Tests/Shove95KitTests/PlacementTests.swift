import Foundation
import Testing
@testable import Shove95Kit

/// TaskItem instances are created standalone (never inserted into a
/// ModelContext) — @Model classes work as plain objects for pure-logic tests.
private func task(
    _ title: String, sortOrder: Double, important: Bool = false,
    due: Date? = nil, overduePlaced: Bool = false, completed: Bool = false
) -> TaskItem {
    let t = TaskItem()
    t.title = title
    t.sortOrder = sortOrder
    t.isImportant = important
    t.dueDate = due
    t.overduePlaced = overduePlaced
    t.isCompleted = completed
    if completed { t.completedAt = Date(timeIntervalSince1970: 1_780_000_000) }
    return t
}

@Suite("Placement: creation and arrival")
struct PlacementInsertTests {
    @Test func newTaskGoesToBottom() {
        let all = [task("a", sortOrder: 1), task("b", sortOrder: 2)]
        #expect(Placement.sortOrderForNewTask(allInBucket: all) == 3)
    }

    @Test func newTaskInEmptyListStartsAtOne() {
        #expect(Placement.sortOrderForNewTask(allInBucket: []) == 1)
    }

    @Test func newTaskClearsCompletedTasksOrders() {
        // Bug report 2026-08-04: tick B (order 2), add C, untick B —
        // B must return ABOVE C. So C's order must clear B's even though
        // B is invisible while completed.
        let a = task("a", sortOrder: 1)
        let b = task("b", sortOrder: 2, completed: true)
        let order = Placement.sortOrderForNewTask(allInBucket: [a, b])
        #expect(order > 2)
    }

    @Test func normalArrivalGoesAboveExistingImportantTask() {
        let visible = [task("imp", sortOrder: 1, important: true), task("a", sortOrder: 2)]
        #expect(Placement.sortOrderForArrival(isImportant: false, visible: visible, allInBucket: visible) == 0)
    }

    @Test func arrivalAlsoClearsCompletedTasksOrders() {
        let visible = [task("a", sortOrder: 1)]
        let all = visible + [task("done", sortOrder: -4, completed: true)]
        #expect(Placement.sortOrderForArrival(isImportant: false, visible: visible, allInBucket: all) == -5)
    }

    @Test func importantArrivalGoesAboveExistingImportantBlock() {
        let visible = [
            task("imp1", sortOrder: 1, important: true),
            task("imp2", sortOrder: 2, important: true),
            task("normal", sortOrder: 3),
        ]
        let order = Placement.sortOrderForArrival(isImportant: true, visible: visible, allInBucket: visible)
        #expect(order < 1)
    }

    @Test func importantArrivalWithNoImportantsGoesToVeryTop() {
        let visible = [task("a", sortOrder: 5), task("b", sortOrder: 6)]
        let order = Placement.sortOrderForArrival(isImportant: true, visible: visible, allInBucket: visible)
        #expect(order < 5)
    }

    @Test func importantArrivalWhenAllImportantGoesToTop() {
        let visible = [task("imp1", sortOrder: 1, important: true), task("imp2", sortOrder: 2, important: true)]
        #expect(Placement.sortOrderForArrival(isImportant: true, visible: visible, allInBucket: visible) == 0)
    }

    @Test func importantArrivalIntoEmptyList() {
        #expect(Placement.sortOrderForArrival(isImportant: true, visible: [], allInBucket: []) == -1)
    }
}

@Suite("Placement: flagging")
struct PlacementFlagTests {
    @Test func flagJumpsAboveEverythingIncludingImportants() {
        // Locked Q17: flagging jumps to the very top of the tab.
        let visible = [task("imp", sortOrder: 1, important: true), task("a", sortOrder: 2)]
        #expect(Placement.sortOrderForFlagImportant(visible: visible) < 1)
    }
    // Unflagging has no placement function at all — the task stays put by design.
}

@Suite("Placement: drag reorder")
struct PlacementReorderTests {
    @Test func betweenNeighborsIsMidpoint() {
        #expect(Placement.sortOrder(between: 1, and: 2) == 1.5)
    }

    @Test func droppedAtEnds() {
        #expect(Placement.sortOrder(between: 7, and: nil) == 8)   // bottom
        #expect(Placement.sortOrder(between: nil, and: 3) == 2)   // top
        #expect(Placement.sortOrder(between: nil, and: nil) == 0) // empty list
    }

    @Test func renormalizationDetectsCollapsedGaps() {
        let a = task("a", sortOrder: 1)
        let b = task("b", sortOrder: 1 + 1e-12)
        #expect(Placement.needsRenormalization(visible: [a, b]))
        let fresh = Placement.renormalized(visible: [a, b])
        #expect(fresh.map(\.sortOrder) == [0, 1])
        #expect(fresh.map(\.task.title) == ["a", "b"]) // relative order preserved
    }

    @Test func healthyGapsNeedNoRenormalization() {
        #expect(!Placement.needsRenormalization(visible: [task("a", sortOrder: 1), task("b", sortOrder: 1.5)]))
    }
}

@Suite("Placement: day-rollover pass")
struct RolloverTests {
    let cal = Fixed.calendar
    let now = Fixed.date(2026, 8, 3) // Monday noon

    @Test func newlyOverdueSlotBetweenTopBlockAndNormals() {
        let imp = task("imp", sortOrder: 1, important: true)
        let placedOverdue = task("old overdue", sortOrder: 2, due: Fixed.date(2026, 7, 30, 0, 0), overduePlaced: true)
        let newOverdue = task("new overdue", sortOrder: 99, due: Fixed.date(2026, 8, 2, 0, 0))
        let normal = task("normal", sortOrder: 3, due: Fixed.date(2026, 8, 3, 0, 0))

        let placements = Placement.rolloverPlacements(
            visibleToday: [imp, placedOverdue, normal, newOverdue], now: now, calendar: cal)

        #expect(placements.count == 1)
        let order = placements[0].sortOrder
        #expect(placements[0].task.title == "new overdue")
        #expect(order > 2 && order < 3) // after top block (imp+placed), before normals
    }

    @Test func multipleNewlyOverdueKeepDueDateOrder() {
        let older = task("from Sat", sortOrder: 50, due: Fixed.date(2026, 8, 1, 0, 0))
        let newer = task("from Sun", sortOrder: 40, due: Fixed.date(2026, 8, 2, 0, 0))
        let normal = task("normal", sortOrder: 1, due: Fixed.date(2026, 8, 3, 0, 0))

        let placements = Placement.rolloverPlacements(
            visibleToday: [normal, newer, older], now: now, calendar: cal)

        #expect(placements.map(\.task.title) == ["from Sat", "from Sun"]) // oldest first
        #expect(placements[0].sortOrder < placements[1].sortOrder)
        #expect(placements.allSatisfy { $0.sortOrder < 1 }) // both above the normal task
    }

    @Test func draggedOverdueTaskIsNeverRePlaced() {
        // The load-bearing guarantee of Q17-B: overduePlaced == true → untouchable.
        let dragged = task("dragged", sortOrder: 10, due: Fixed.date(2026, 8, 1, 0, 0), overduePlaced: true)
        let normal = task("normal", sortOrder: 1, due: Fixed.date(2026, 8, 3, 0, 0))
        let placements = Placement.rolloverPlacements(
            visibleToday: [normal, dragged], now: now, calendar: cal)
        #expect(placements.isEmpty)
    }

    @Test func importantOverdueIsSkippedByRollover() {
        let impOverdue = task("imp overdue", sortOrder: 1, important: true, due: Fixed.date(2026, 8, 1, 0, 0))
        let placements = Placement.rolloverPlacements(
            visibleToday: [impOverdue], now: now, calendar: cal)
        #expect(placements.isEmpty)
    }

    @Test func rolloverIntoEmptyTodayStillAssignsOrders() {
        let a = task("a", sortOrder: 5, due: Fixed.date(2026, 8, 1, 0, 0))
        let b = task("b", sortOrder: 6, due: Fixed.date(2026, 8, 2, 0, 0))
        let placements = Placement.rolloverPlacements(
            visibleToday: [a, b], now: now, calendar: cal)
        #expect(placements.count == 2)
        #expect(placements[0].sortOrder < placements[1].sortOrder)
    }
}
