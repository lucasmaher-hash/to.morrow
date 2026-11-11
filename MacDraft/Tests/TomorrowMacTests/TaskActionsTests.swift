import Foundation
import Testing
import Shove95Kit
@testable import TomorrowMac

@Suite @MainActor struct TaskActionsTests {
    private func settings() -> (MacSettings, UserDefaults, String) {
        let suite = "TaskActionsTests.\(UUID())"
        let defaults = UserDefaults(suiteName: suite)!
        return (MacSettings(defaults: defaults), defaults, suite)
    }
    @Test func completionMovesToTheDoneRunAndUntickingReturnsToItsManualOrder() {
        let first = TaskItem(), second = TaskItem(), done = TaskItem()
        first.sortOrder = 100; second.sortOrder = 200; done.sortOrder = 300
        done.isCompleted = true; done.completedAt = .distantPast
        _ = MacTaskActions.toggleCompleted(first)
        #expect(MacTaskActions.orderedForDisplay([first, second, done]).map(\.id) == [second.id, done.id, first.id])
        _ = MacTaskActions.toggleCompleted(first)
        #expect(MacTaskActions.orderedForDisplay([first, second, done]).map(\.id) == [first.id, second.id, done.id])
        #expect(first.sortOrder == 100 && first.completedAt == nil && !first.isPinned)
    }

    @Test func importanceMovesAboveActiveTasksOnlyInItsWorkspaceAndSection() {
        let (settings, defaults, suite) = settings()
        defer { defaults.removePersistentDomain(forName: suite) }
        let first = TaskItem(), marked = TaskItem(), elsewhere = TaskItem()
        first.dueDate = .now; marked.dueDate = .now; elsewhere.dueDate = .now
        first.sortOrder = 10; marked.sortOrder = 100
        elsewhere.sortOrder = -500; elsewhere.workspaceID = Workspace.workID
        MacTaskActions.toggleImportant(marked, tasks: [elsewhere, first, marked], settings: settings)
        #expect(marked.isImportant && marked.sortOrder < first.sortOrder && marked.sortOrder > elsewhere.sortOrder)
        let order = marked.sortOrder
        MacTaskActions.toggleImportant(marked, tasks: [elsewhere, marked, first], settings: settings)
        #expect(!marked.isImportant && marked.sortOrder == order)
    }

    @Test func menuUsesHeldTabWhenDateHasRolledOver() {
        let (settings, defaults, suite) = settings()
        defer { defaults.removePersistentDomain(forName: suite) }
        let task = TaskItem()
        task.dueDate = Calendar.current.date(byAdding: .day, value: -1, to: .now)
        settings.rules[Bucket.tomorrow.rawValue] = false
        settings.frozen[task.id.uuidString] = Bucket.tomorrow.rawValue
        #expect(settings.visible(task, in: .tomorrow))
        #expect(settings.bucket(for: task).menuDestinations.isEmpty)
    }
    @Test func undoRemovalPreservesExistingCompletion() {
        let task = TaskItem()
        let completed = Date(timeIntervalSince1970: 1_700_000_000)
        task.isCompleted = true; task.completedAt = completed
        let restore = MacTaskActions.remove(task)
        restore()
        #expect(task.isCompleted)
        #expect(task.completedAt == completed)
    }
    @Test func reorderResolvesTiedOrdersWithoutTouchingOtherWorkspaces() {
        let (settings, defaults, suite) = settings()
        defer { defaults.removePersistentDomain(forName: suite) }
        let first = TaskItem(), target = TaskItem(), dragged = TaskItem(), other = TaskItem()
        first.sortOrder = 100; target.sortOrder = 100; dragged.sortOrder = 300
        other.workspaceID = Workspace.workID; other.sortOrder = 99
        MacTaskActions.reorder(dragged, before: target, tasks: [other, first, target, dragged], settings: settings)
        #expect(first.sortOrder < dragged.sortOrder)
        #expect(dragged.sortOrder < target.sortOrder)
        #expect(other.sortOrder == 99)
    }
}
