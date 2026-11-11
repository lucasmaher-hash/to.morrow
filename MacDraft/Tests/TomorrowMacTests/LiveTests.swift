import Testing
import SwiftData
import Foundation
import Shove95Kit
@testable import TomorrowMac

@MainActor
struct LiveTests {
    private func store() throws -> ModelContainer {
        let schema = Schema([TaskItem.self, TaskPhoto.self, Workspace.self])
        return try ModelContainer(for: schema, configurations: ModelConfiguration(schema: schema, isStoredInMemoryOnly: true, cloudKitDatabase: .none))
    }

    @Test func liveAndTodayShareIdentityAndFutureTasksMoveToToday() throws {
        let container = try store(), context = container.mainContext
        let task = TaskItem(); task.title = "Tomorrow"
        task.dueDate = DateEngine.targetDate(for: .tomorrow, now: .now, calendar: .current)
        context.insert(task)
        let live = MacLiveController(context: context, presentUI: false)
        live.activate(task)
        #expect(task.isVisible(in: .today, now: .now, calendar: .current))
        #expect(!task.isVisible(in: .tomorrow, now: .now, calendar: .current))
        #expect(live.note?.id == task.id)
        task.title = "Edited in Today"
        #expect(live.note?.title == "Edited in Today")
        _ = MacTaskActions.toggleCompleted(task)
        #expect(!task.isLiveNote && !task.isPinned)
        live.reloadFromStore()
        #expect(live.note == nil)
        #expect(task.isVisible(in: .today, now: .now, calendar: .current))
        #expect(try context.fetchCount(FetchDescriptor<TaskItem>()) == 1)
    }

    @Test func typingLiveCreatesOneTodayRecordInTheSelectedWorkspace() throws {
        let container = try store(), context = container.mainContext
        let live = MacLiveController(context: context, presentUI: false)
        live.write("Focus at work", workspaceID: Workspace.workID)
        let note = try #require(live.note)
        #expect(note.workspaceID == Workspace.workID)
        #expect(note.isVisible(in: .today, now: .now, calendar: .current))
        live.write("Edited focus")
        #expect(live.note?.id == note.id)
        #expect(try context.fetchCount(FetchDescriptor<TaskItem>()) == 1)
    }

    @Test func replaceAndHidePreserveTasks() throws {
        let container = try store(), context = container.mainContext
        let first = TaskItem(), second = TaskItem()
        first.title = "First"; second.title = "Second"
        context.insert(first); context.insert(second)
        let live = MacLiveController(context: context, presentUI: false)
        live.activate(first); live.activate(second)
        #expect(!first.isLiveNote && !first.isPinned && !first.isCompleted)
        #expect(second.isLiveNote && second.isPinned)
        live.setVisible(false)
        #expect(live.note?.id == second.id && !second.isPinned)
        live.write("Edited")
        #expect(live.note?.id == second.id && second.title == "Edited")
        #expect(try context.fetch(FetchDescriptor<TaskItem>()).count == 2)
        live.clear()
        #expect(live.note == nil && second.isCompleted)
        live.undoClear()
        #expect(live.note?.id == second.id && !second.isCompleted)
    }

    @Test func openingLiveRefreshesACompletedOrReplacedTask() throws {
        let container = try store(), context = container.mainContext
        let first = TaskItem(), second = TaskItem()
        first.title = "Old"; second.title = "Current"
        context.insert(first); context.insert(second)
        let live = MacLiveController(context: context, presentUI: false)
        live.activate(first)
        first.isCompleted = true; first.isLiveNote = false; first.isPinned = false
        second.isLiveNote = true; second.isPinned = true
        try context.save()
        live.show()
        #expect(live.note?.id == second.id)
        second.isCompleted = true; second.isLiveNote = false
        try context.save()
        live.show()
        #expect(live.note == nil)
    }

    @Test func completionWaitsForAnimationAndSurvivesReload() async throws {
        let container = try store(), context = container.mainContext
        let task = TaskItem(); task.title = "Finish this"
        context.insert(task)
        let live = MacLiveController(context: context, presentUI: false)
        live.activate(task)
        let reopened = MacLiveController(context: context, presentUI: false)
        #expect(reopened.note?.id == task.id)
        let completion = try #require(live.complete())
        #expect(live.complete() == nil) // second click cannot schedule another finish
        #expect(live.completing && !task.isCompleted)
        try await Task.sleep(for: .milliseconds(100))
        #expect(!task.isCompleted && live.note?.id == task.id)
        try await Task.sleep(for: .milliseconds(750))
        #expect(!task.isCompleted && live.completing && live.stroke == 1)
        await completion.value
        #expect(task.isCompleted && !task.isLiveNote && !task.isPinned)
        #expect(live.note == nil && !live.completing)
        #expect(task.completedAt != nil && task.bucket(now: .now, calendar: .current) == .today)
        #expect(MacLiveController(context: context, presentUI: false).note == nil)
    }
    @Test func committingAnEmptyLiveDraftEndsTheNoteLikeOnPhone() throws {
        let container = try store(), context = container.mainContext
        let live = MacLiveController(context: context, presentUI: false)
        live.write("Erase me")
        let id = try #require(live.note?.id)
        #expect(live.commitDraft("  ", editingNoteID: id))
        #expect(live.note == nil)
        #expect(try context.fetchCount(FetchDescriptor<TaskItem>()) == 0)
    }

    @Test func editingOffAirPreservesItsIdentityAndDoesNotRepin() throws {
        let container = try store(), context = container.mainContext
        let live = MacLiveController(context: context, presentUI: false)
        live.write("Focus")
        let id = try #require(live.note?.id)
        live.setVisible(false)
        #expect(live.commitDraft("Edited off air", editingNoteID: id))
        #expect(live.note?.id == id && live.note?.isPinned == false)
        #expect(live.note?.title == "Edited off air")
        let replacement = TaskItem(); replacement.title = "Replacement"; context.insert(replacement)
        live.activate(replacement)
        #expect(!live.commitDraft("stale edit", editingNoteID: id))
        #expect(live.note?.title == "Replacement")
    }

    @Test func checkCompletesAnUncommittedDraftWithoutNeedingGoFirst() async throws {
        let container = try store(), context = container.mainContext
        let live = MacLiveController(context: context, presentUI: false)
        let completion = try #require(live.completeDraft("Finish draft", editingNoteID: nil, workspaceID: Workspace.workID))
        let task = try #require(live.note)
        #expect(live.completing && !task.isCompleted)
        #expect(live.completeDraft("Finish draft", editingNoteID: nil) == nil)
        await completion.value
        #expect(task.isCompleted && !task.isLiveNote && !task.isPinned)
        #expect(task.workspaceID == Workspace.workID)
        #expect(task.isVisible(in: .today, now: .now, calendar: .current))
        #expect(try context.fetchCount(FetchDescriptor<TaskItem>()) == 1)
    }

}
