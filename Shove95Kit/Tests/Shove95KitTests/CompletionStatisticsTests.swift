import Foundation
import Testing
@testable import Shove95Kit

@Suite struct CompletionStatisticsTests {
    @Test func countsCalendarDaysIncludingQuietDaysAcrossDST() {
        let first = TaskItem(), second = TaskItem(), unfinished = TaskItem()
        first.isCompleted = true; first.completedAt = Fixed.date(2026, 10, 24)
        second.isCompleted = true; second.completedAt = Fixed.date(2026, 10, 26)
        let stats = CompletionStatistics(tasks: [first, second, unfinished],
            now: Fixed.date(2026, 10, 27), calendar: Fixed.calendar)
        #expect(stats.total == 2)
        #expect(stats.dailyAverage == 0.5)
    }
    @Test func emptyAndFirstDayDoNotDivideByZero() {
        #expect(CompletionStatistics(tasks: []).dailyAverage == 0)
        let task = TaskItem(); task.isCompleted = true; task.completedAt = Fixed.date(2026, 8, 3)
        #expect(CompletionStatistics(tasks: [task], now: Fixed.date(2026, 8, 3), calendar: Fixed.calendar).dailyAverage == 1)
    }
}


@Suite struct CompletionBehaviorTests {
    @Test func liveCompletionClearsFocusAndOverdueWithoutReorderingAndUntickDoesNotRepin() {
        let task = TaskItem()
        task.dueDate = Fixed.date(2026, 8, 2); task.sortOrder = 175
        task.isLiveNote = true; task.isPinned = true; task.overduePlaced = true
        task.toggleCompletion(now: Fixed.date(2026, 8, 3), calendar: Fixed.calendar)
        #expect(task.isCompleted && task.completedAt == Fixed.date(2026, 8, 3))
        #expect(task.dueDate == Fixed.date(2026, 8, 3, 0))
        #expect(!task.isLiveNote && !task.isPinned && !task.overduePlaced && task.sortOrder == 175)
        task.toggleCompletion(now: Fixed.date(2026, 8, 3), calendar: Fixed.calendar)
        #expect(!task.isCompleted && task.completedAt == nil && !task.isPinned && !task.isLiveNote)
    }
    @Test func futureTaskCompletionPreservesItsScheduledDay() {
        let task = TaskItem(); task.dueDate = Fixed.date(2026, 8, 5)
        task.toggleCompletion(now: Fixed.date(2026, 8, 3), calendar: Fixed.calendar)
        #expect(task.dueDate == Fixed.date(2026, 8, 5))
        #expect(task.isVisible(in: .general, now: Fixed.date(2026, 8, 3), calendar: Fixed.calendar))
    }
}
