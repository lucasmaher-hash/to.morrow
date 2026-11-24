import Foundation
import Testing
import Shove95Kit
@testable import TomorrowMac

@Suite @MainActor struct BoardDragTests {
    @Test func followsPointerAndPreviewsAcrossColumnsWithoutWritingTheTask() {
        let drag = MacTaskTransferCoordinator(), task = TaskItem(), target = TaskItem()
        task.sortOrder = 400; task.dueDate = .distantPast
        let original = CGRect(x: 20, y: 100, width: 250, height: 60)
        drag.recordBoardViewport(CGRect(x: 0, y: 80, width: 300, height: 600), in: .today)
        drag.recordBoardViewport(CGRect(x: 300, y: 80, width: 300, height: 600), in: .tomorrow)
        drag.recordBoardRow(CGRect(x: 320, y: 200, width: 250, height: 60), id: target.id, section: .init(bucket: .tomorrow))
        #expect(drag.liftBoard(task, from: original))
        drag.trackBoard(CGSize(width: 310, height: 50), at: CGPoint(x: 550, y: 160))
        #expect(drag.frame == original.offsetBy(dx: 310, dy: 50))
        #expect(drag.boardDrop == .init(section: .init(bucket: .tomorrow), before: target.id))
        #expect(drag.boardGapHeight(in: .init(bucket: .tomorrow), before: target.id, rowGap: 6) == 66)
        #expect(drag.boardGapHeight(in: .init(bucket: .today), before: nil) == 0)
        #expect(task.sortOrder == 400 && task.dueDate == .distantPast)
        drag.prepareBoard(velocity: .zero)
        #expect(!drag.isLifted && drag.isWaiting)
        let landing = CGRect(x: 320, y: 100, width: 250, height: 60)
        drag.report(landing, taskID: task.id, in: .tomorrow)
        drag.flyToTarget()
        #expect(drag.frame == landing)
        #expect(drag.phase == .landing)
        drag.finish(session: drag.sessionID)
        #expect(drag.task == nil)
    }
    @Test func sameDayLandingUsesThePreviewSlotInsteadOfTheStaleSourceFrame() {
        let drag = MacTaskTransferCoordinator(), task = TaskItem(), other = TaskItem()
        let source = CGRect(x: 20, y: 100, width: 250, height: 60)
        let slot = CGRect(x: 20, y: 240, width: 250, height: 66)
        drag.recordBoardViewport(CGRect(x: 0, y: 80, width: 300, height: 600), in: .tomorrow)
        drag.recordBoardRow(CGRect(x: 20, y: 300, width: 250, height: 60), id: other.id, section: .init(bucket: .tomorrow))
        #expect(drag.liftBoard(task, from: source))
        drag.trackBoard(CGSize(width: 0, height: 140), at: CGPoint(x: 200, y: 260))
        let drop = MacTaskTransferCoordinator.BoardDrop(section: .init(bucket: .tomorrow), before: other.id)
        drag.recordBoardGap(slot, drop: drop)
        drag.prepareBoard(velocity: .zero)
        // The source view's phase callback still knows yesterday's layout.
        drag.report(source, taskID: task.id, in: .tomorrow)
        #expect(drag.targetFrame == CGRect(x: slot.minX, y: slot.minY, width: slot.width, height: source.height))
        drag.flyToTarget()
        #expect(drag.frame.minY == slot.minY)
        drag.reset()
    }
    @Test func droppingInLiveTargetsTheTextWellAndLeavingItRestoresBoardPreview() {
        let drag = MacTaskTransferCoordinator(), task = TaskItem()
        let source = CGRect(x: 20, y: 100, width: 250, height: 60)
        let well = CGRect(x: 920, y: 100, width: 276, height: 260)
        drag.recordBoardViewport(CGRect(x: 0, y: 80, width: 300, height: 600), in: .today)
        drag.recordLiveWell(well)
        #expect(drag.liftBoard(task, from: source))
        drag.trackBoard(CGSize(width: 900, height: 20), at: CGPoint(x: 1000, y: 140))
        #expect(drag.isOverLive && drag.boardDrop == nil)
        drag.trackBoard(.zero, at: CGPoint(x: 200, y: 140))
        #expect(!drag.isOverLive && drag.boardDrop?.section.bucket == .today)
        drag.trackBoard(CGSize(width: 900, height: 20), at: CGPoint(x: 1000, y: 140))
        drag.prepareLive(velocity: .zero)
        #expect(drag.targetFrame == well && drag.isLiveTransfer)
        drag.flyToTarget()
        #expect(drag.isLiveLanding && drag.frame == well)
        drag.finish(session: drag.sessionID)
        #expect(!drag.isLiveTransfer && drag.task == nil)
    }
    @Test func offscreenPreviewWaitsForTheRevealedDestination() {
        let drag = MacTaskTransferCoordinator(), task = TaskItem()
        let source = CGRect(x: 20, y: 100, width: 250, height: 60)
        drag.recordBoardViewport(CGRect(x: 0, y: 80, width: 300, height: 300), in: .tomorrow)
        #expect(drag.liftBoard(task, from: source))
        drag.trackBoard(CGSize(width: 0, height: 260), at: CGPoint(x: 200, y: 370))
        drag.recordBoardGap(CGRect(x: 20, y: 420, width: 250, height: 60),
                            drop: .init(section: .init(bucket: .tomorrow), before: nil))
        drag.prepareBoard(velocity: .zero)
        #expect(drag.isWaiting && drag.targetFrame == nil)
        let revealed = CGRect(x: 20, y: 200, width: 250, height: 60)
        drag.report(revealed, taskID: task.id, in: .tomorrow)
        #expect(drag.targetFrame == revealed)
        drag.reset()
    }
    @Test func dropOutsideReturnsHomeAndStaleSessionCannotHideANewDrag() {
        let drag = MacTaskTransferCoordinator(), task = TaskItem()
        let frame = CGRect(x: 20, y: 100, width: 250, height: 60)
        #expect(drag.liftBoard(task, from: frame))
        let oldSession = drag.sessionID
        drag.trackBoard(CGSize(width: 900, height: 0), at: CGPoint(x: 900, y: 100))
        #expect(drag.boardDrop == nil)
        drag.returnHome(); drag.flyToTarget()
        #expect(drag.frame == frame)
        drag.finish(session: oldSession)
        #expect(drag.liftBoard(task, from: frame))
        drag.finish(session: oldSession)
        #expect(drag.taskID == task.id)
        drag.reset()
    }
    @Test func sameSectionReorderPreservesScheduledDate() {
        let suite = "BoardDragTests.\(UUID())"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let settings = MacSettings(defaults: defaults)
        let task = TaskItem(), other = TaskItem()
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: .now)!
        task.dueDate = yesterday; task.sortOrder = 100
        other.dueDate = .now; other.sortOrder = 0
        MacTaskActions.placeOnBoard(task, in: .today, before: other.id, tasks: [other, task], settings: settings)
        #expect(task.dueDate == yesterday)
        #expect(task.sortOrder < other.sortOrder)
    }
    @Test func releaseCommitsDestinationAndOrderOnlyWithinTheWorkspace() {
        let suite = "BoardDragTests.\(UUID())"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let settings = MacSettings(defaults: defaults)
        let task = TaskItem(), before = TaskItem(), other = TaskItem()
        task.dueDate = DateEngine.targetDate(for: .today, now: .now, calendar: .current)
        before.dueDate = DateEngine.targetDate(for: .tomorrow, now: .now, calendar: .current)
        other.workspaceID = Workspace.workID; other.sortOrder = 77
        settings.rules[Bucket.tomorrow.rawValue] = false
        settings.place(before, in: .tomorrow)
        MacTaskActions.placeOnBoard(task, in: .tomorrow, before: before.id, tasks: [task, before, other], settings: settings)
        #expect(settings.bucket(for: task) == .tomorrow)
        #expect(task.sortOrder < before.sortOrder)
        #expect(other.sortOrder == 77)
    }
}
