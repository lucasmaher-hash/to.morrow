import XCTest
import SwiftData
import ActivityKit
import SwiftUI
import UIKit
import Shove95Kit
@testable import shove95

@MainActor
final class TaskRegressionTests: XCTestCase {
    private var retainedContainer: ModelContainer?

    private func makeStore() throws -> (ModelContainer, TaskStore) {
        let schema = Schema([TaskItem.self, TaskPhoto.self, Workspace.self])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true,
                                        cloudKitDatabase: .none)
        let container = try ModelContainer(for: schema, configurations: config)
        retainedContainer = container
        let store = TaskStore(context: container.mainContext)
        store.now = { Date(timeIntervalSince1970: 1_792_864_800) }
        return (container, store)
    }

    private func starterDefaults() throws -> UserDefaults {
        let suite = "to.morrow.starter-tests.\(UUID().uuidString)"
        addTeardownBlock { UserDefaults.standard.removePersistentDomain(forName: suite) }
        return try XCTUnwrap(UserDefaults(suiteName: suite))
    }

    func testLiveCompletionButtonKeepsItsCircleSlotAcrossPrimaryStates() throws {
        for width: CGFloat in [150, 255, 410] {
            for ready in [false, true] {
                // Draft's Go pill has an intrinsic width; Live/Off air expands.
                // The completion circle must keep the same right-hand slot.
                let row = SkeuLiveControlsLayout(width: width, controlSize: 44) {
                    if ready {
                        Text("Live").frame(maxWidth: .infinity).frame(height: 44)
                    } else {
                        Text("Go").padding(.horizontal, 24).frame(height: 44)
                    }
                } completion: {
                    Rectangle().fill(.red).frame(width: 44, height: 44)
                }
                let renderer = ImageRenderer(content: row.background(.white))
                renderer.scale = 1
                let image = try XCTUnwrap(renderer.cgImage)
                let context = try XCTUnwrap(CGContext(data: nil, width: image.width, height: image.height,
                    bitsPerComponent: 8, bytesPerRow: image.width * 4, space: CGColorSpaceCreateDeviceRGB(),
                    bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue | CGBitmapInfo.byteOrder32Big.rawValue))
                context.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
                let pixels = try XCTUnwrap(context.data).assumingMemoryBound(to: UInt8.self)
                var xs: [Int] = []
                let y = image.height / 2
                for x in 0..<image.width {
                    let offset = y * image.width * 4 + x * 4
                    if pixels[offset] > 200 && pixels[offset + 1] < 80 { xs.append(x) }
                }
                XCTAssertEqual(xs.first, Int(width) - 44, "Circle shifted for width \(width), ready \(ready)")
                XCTAssertEqual(xs.last, Int(width) - 1)
                XCTAssertEqual(xs.count, 44, "Circle must not compress")
            }
        }
    }

    func testLandscapeCaptureFieldsKeepIndependentFocusIdentities() {
        let today = EditingCoordinator.addRowID(for: nil, in: .today)
        let tomorrow = EditingCoordinator.addRowID(for: nil, in: .tomorrow)
        let general = EditingCoordinator.addRowID(for: nil, in: .general)
        let scheduled = EditingCoordinator.addRowID(for: Date(timeIntervalSince1970: 1_792_864_800),
                                                     in: .general)
        XCTAssertEqual(Set([today, tomorrow, general, scheduled]).count, 4)

        let editing = EditingCoordinator()
        editing.begin(today, bottom: 100)
        editing.begin(tomorrow, bottom: 200)
        editing.end(today)
        XCTAssertEqual(editing.focused, tomorrow)
        XCTAssertEqual(editing.focusedBottom, 200)
        editing.end(tomorrow)
        XCTAssertNil(editing.focused)
    }

    func testLandscapeTransferKeepsOneTaskThroughLiftAndLanding() throws {
        let (_, store) = try makeStore()
        let task = try XCTUnwrap(store.addTask(title: "Carry this", in: .today))
        let transfer = TaskTransferCoordinator()
        let source = CGRect(x: 60, y: 40, width: 210, height: 70)
        let target = CGRect(x: 290, y: 110, width: 210, height: 70)
        XCTAssertTrue(transfer.lift(task, from: source))
        let session = transfer.sessionID
        transfer.track(72)
        XCTAssertEqual(transfer.frame.minX, 132)
        XCTAssertEqual(store.tasks(in: .today).active.map(\.id), [task.id])

        transfer.prepare(for: .tomorrow, velocity: 600)
        store.step(task, direction: .deferOne)
        XCTAssertEqual(store.tasks(in: .tomorrow).active.map(\.id), [task.id])
        XCTAssertTrue(store.tasks(in: .today).active.isEmpty)
        XCTAssertEqual(transfer.taskID, task.id)
        // The outgoing view may report again after its model date changed.
        // Its original list identity must never become the landing target.
        transfer.report(source, taskID: task.id, in: .today)
        XCTAssertNil(transfer.targetFrame)
        transfer.recordViewport(CGRect(x: 280, y: 30, width: 230, height: 300), in: .tomorrow)
        transfer.report(target, taskID: task.id, in: .tomorrow)
        XCTAssertEqual(transfer.targetFrame, target)
        transfer.flyToTarget()
        XCTAssertEqual(transfer.frame, target)
        XCTAssertEqual(transfer.phase, .landing)
        transfer.lower(session: session)
        XCTAssertFalse(transfer.isLifted)
        transfer.finish(session: session)
        XCTAssertNil(transfer.taskID)
        XCTAssertEqual(store.tasks(in: .tomorrow).active.map(\.id), [task.id])
    }

    func testMovedTasksLeadDestinationAndUndoRestoresPreviousPosition() throws {
        let (_, store) = try makeStore()
        let important = try XCTUnwrap(store.addTask(title: "Existing important", in: .tomorrow))
        important.isImportant = true
        let normal = try XCTUnwrap(store.addTask(title: "Existing normal", in: .tomorrow))
        let first = try XCTUnwrap(store.addTask(title: "First arrival", in: .today))
        let second = try XCTUnwrap(store.addTask(title: "Latest arrival", in: .today))
        let previousOrder = second.sortOrder

        store.step(first, direction: .deferOne)
        XCTAssertEqual(store.tasks(in: .tomorrow).active.map(\.id), [first.id, important.id, normal.id])
        store.step(second, direction: .deferOne)
        XCTAssertEqual(store.tasks(in: .tomorrow).active.map(\.id), [second.id, first.id, important.id, normal.id])
        store.undoLastAction()
        XCTAssertEqual(store.tasks(in: .today).active.map(\.id), [second.id])
        XCTAssertEqual(second.sortOrder, previousOrder)
        XCTAssertEqual(store.tasks(in: .tomorrow).active.map(\.id), [first.id, important.id, normal.id])

        let soon = try XCTUnwrap(store.addTask(title: "Existing Soon", in: .general))
        store.move(first, to: .general)
        XCTAssertEqual(store.tasks(in: .general).active.map(\.id), [first.id, soon.id])
        store.move(first, to: .today)
        XCTAssertEqual(store.tasks(in: .today).active.map(\.id), [first.id, second.id])
    }

    func testCancelledLandscapeTransferReturnsWithoutMovingTask() throws {
        let (_, store) = try makeStore()
        let task = try XCTUnwrap(store.addTask(title: "Keep here", in: .today))
        let transfer = TaskTransferCoordinator()
        let source = CGRect(x: 60, y: 40, width: 210, height: 70)
        transfer.lift(task, from: source)
        transfer.track(30)
        transfer.returnHome()
        XCTAssertEqual(transfer.targetFrame, source)
        XCTAssertNil(transfer.destination)
        transfer.flyToTarget()
        transfer.finish(session: transfer.sessionID)
        XCTAssertNil(transfer.taskID)
        XCTAssertEqual(store.tasks(in: .today).active.map(\.id), [task.id])
        XCTAssertTrue(store.tasks(in: .tomorrow).active.isEmpty)
    }

    func testTransferWaitsForOffscreenDestinationToBeRevealed() throws {
        let (_, store) = try makeStore()
        let task = try XCTUnwrap(store.addTask(title: "Reveal the landing", in: .today))
        let transfer = TaskTransferCoordinator()
        transfer.lift(task, from: CGRect(x: 60, y: 40, width: 210, height: 70))
        transfer.prepare(for: .tomorrow, velocity: 0)
        transfer.recordViewport(CGRect(x: 280, y: 30, width: 230, height: 250), in: .tomorrow)
        transfer.report(CGRect(x: 290, y: 400, width: 210, height: 70), taskID: task.id, in: .tomorrow)
        XCTAssertTrue(transfer.isWaiting)
        XCTAssertNil(transfer.targetFrame)
        let revealed = CGRect(x: 290, y: 120, width: 210, height: 70)
        transfer.report(revealed, taskID: task.id, in: .tomorrow)
        XCTAssertEqual(transfer.targetFrame, revealed)
        transfer.reset()
    }

    func testOldTransferCallbacksCannotFinishANewFlight() throws {
        let (_, store) = try makeStore()
        let first = try XCTUnwrap(store.addTask(title: "First", in: .today))
        let second = try XCTUnwrap(store.addTask(title: "Second", in: .today))
        let frame = CGRect(x: 60, y: 40, width: 210, height: 70)
        let transfer = TaskTransferCoordinator()
        transfer.lift(first, from: frame)
        let previous = transfer.sessionID
        transfer.reset() // rotation/workspace change
        XCTAssertTrue(transfer.lift(second, from: frame))
        transfer.finish(session: previous)
        transfer.lower(session: previous)
        XCTAssertEqual(transfer.taskID, second.id)
        XCTAssertTrue(transfer.isLifted)
        XCTAssertFalse(transfer.lift(first, from: frame))
        transfer.prepare(for: .tomorrow, velocity: 0)
        transfer.report(frame, taskID: first.id, in: .tomorrow)
        XCTAssertNil(transfer.targetFrame)
        transfer.reset()
    }

    func testBoardHandleTracksBothAxesAndCanSkipAColumn() throws {
        let (_, store) = try makeStore()
        let task = try XCTUnwrap(store.addTask(title: "Carry", in: .today))
        let first = try XCTUnwrap(store.addTask(title: "First", in: .general))
        let second = try XCTUnwrap(store.addTask(title: "Second", in: .general))
        let transfer = TaskTransferCoordinator()
        let section = TaskTransferCoordinator.BoardSection(bucket: .general)
        transfer.recordBoardViewport(CGRect(x: 400, y: 20, width: 190, height: 400), in: .general)
        transfer.recordBoardRow(CGRect(x: 410, y: 60, width: 170, height: 60), id: first.id, section: section)
        transfer.recordBoardRow(CGRect(x: 410, y: 160, width: 170, height: 60), id: second.id, section: section)
        let origin = CGRect(x: 10, y: 40, width: 170, height: 60)
        XCTAssertTrue(transfer.liftBoard(task, from: origin))
        transfer.trackBoard(CGSize(width: 430, height: 90), at: CGPoint(x: 500, y: 140))
        XCTAssertEqual(transfer.frame, origin.offsetBy(dx: 430, dy: 90))
        XCTAssertEqual(transfer.boardDrop, .init(section: section, before: second.id))
        // Hovering does not move the model or write an Undo record.
        XCTAssertEqual(store.tasks(in: .today).active.map(\.id), [task.id])
        transfer.prepareBoard(velocity: CGSize(width: 500, height: 100))
        XCTAssertEqual(transfer.destination, .general)
        XCTAssertFalse(transfer.isLifted)
        XCTAssertTrue(transfer.isWaiting)
        transfer.reset()
    }

    func testBoardPreviewMovesTheRealGapBetweenRowsAndSections() throws {
        let (_, store) = try makeStore()
        let task = try XCTUnwrap(store.addTask(title: "Carry", in: .today))
        let first = UUID(), second = UUID()
        let transfer = TaskTransferCoordinator()
        let tomorrow = TaskTransferCoordinator.BoardSection(bucket: .tomorrow)
        let general = TaskTransferCoordinator.BoardSection(bucket: .general)
        transfer.recordBoardViewport(CGRect(x: 200, y: 20, width: 190, height: 400), in: .tomorrow)
        transfer.recordBoardViewport(CGRect(x: 400, y: 20, width: 190, height: 400), in: .general)
        transfer.recordBoardRow(CGRect(x: 210, y: 40, width: 170, height: 50), id: first, section: tomorrow)
        transfer.recordBoardRow(CGRect(x: 210, y: 140, width: 170, height: 100), id: second, section: tomorrow)
        transfer.liftBoard(task, from: CGRect(x: 10, y: 40, width: 170, height: 70))
        transfer.trackBoard(CGSize(width: 200, height: 60), at: CGPoint(x: 300, y: 110))
        XCTAssertTrue(transfer.isBoardPreview)
        XCTAssertEqual(transfer.boardGapHeight(in: tomorrow, before: second, rowGap: 8), 78)
        XCTAssertEqual(transfer.boardGapHeight(in: tomorrow, before: first, rowGap: 8), 0)
        // The receiving row moves down as the gap opens. The target remains
        // stable rather than repeatedly opening and closing the same gap.
        transfer.recordBoardRow(CGRect(x: 210, y: 218, width: 170, height: 100), id: second, section: tomorrow)
        XCTAssertEqual(transfer.boardDrop?.before, second)
        transfer.trackBoard(CGSize(width: 400, height: 100), at: CGPoint(x: 500, y: 150))
        XCTAssertEqual(transfer.boardGapHeight(in: tomorrow, before: second, rowGap: 8), 0)
        XCTAssertEqual(transfer.boardGapHeight(in: general, before: nil), 70)
        transfer.prepareBoard(velocity: .zero)
        XCTAssertFalse(transfer.isBoardPreview)
        XCTAssertEqual(transfer.boardGapHeight(in: general, before: nil), 0)
        transfer.reset()
    }

    func testBoardDetectsDatedAndEmptySectionsAndRejectsStaleLanding() throws {
        let (_, store) = try makeStore()
        let task = try XCTUnwrap(store.addTask(title: "Carry", in: .today))
        let transfer = TaskTransferCoordinator()
        let day = store.calendar.date(byAdding: .day, value: 4, to: store.calendar.startOfDay(for: store.now()))!
        let general = TaskTransferCoordinator.BoardSection(bucket: .general)
        let dated = TaskTransferCoordinator.BoardSection(bucket: .general, day: day)
        transfer.recordBoardViewport(CGRect(x: 400, y: 20, width: 190, height: 400), in: .general)
        transfer.recordBoardHeader(CGRect(x: 410, y: 20, width: 170, height: 40), section: general)
        transfer.recordBoardHeader(CGRect(x: 410, y: 220, width: 170, height: 40), section: dated)
        transfer.liftBoard(task, from: CGRect(x: 10, y: 40, width: 170, height: 60))
        transfer.trackBoard(CGSize(width: 420, height: 250), at: CGPoint(x: 500, y: 300))
        XCTAssertEqual(transfer.boardDrop, .init(section: dated, before: nil))
        transfer.prepareBoard(velocity: .zero)
        let target = CGRect(x: 410, y: 280, width: 170, height: 60)
        transfer.report(target, taskID: task.id, in: .general)
        XCTAssertNil(transfer.targetFrame)
        transfer.report(target, taskID: task.id, in: .general, day: day)
        XCTAssertEqual(transfer.targetFrame, target)
        transfer.reset()
    }

    func testBoardDropOutsideColumnsReturnsWithoutChangingTask() throws {
        let (_, store) = try makeStore()
        let task = try XCTUnwrap(store.addTask(title: "Keep", in: .today))
        let transfer = TaskTransferCoordinator()
        let origin = CGRect(x: 10, y: 40, width: 170, height: 60)
        transfer.recordBoardViewport(CGRect(x: 0, y: 20, width: 190, height: 400), in: .today)
        transfer.liftBoard(task, from: origin)
        transfer.trackBoard(CGSize(width: 700, height: 100), at: CGPoint(x: 800, y: 140))
        XCTAssertNil(transfer.boardDrop)
        transfer.prepareBoard(velocity: .zero)
        XCTAssertEqual(transfer.targetFrame, origin)
        XCTAssertNil(transfer.destination)
        XCTAssertEqual(store.tasks(in: .today).active.map(\.id), [task.id])
        transfer.reset()
    }

    func testBoardEdgeScrollRevealsNextRowOnlyInHoveredColumn() throws {
        let (_, store) = try makeStore()
        let task = try XCTUnwrap(store.addTask(title: "Carry", in: .today))
        let ids = [UUID(), UUID(), UUID()]
        let transfer = TaskTransferCoordinator()
        let section = TaskTransferCoordinator.BoardSection(bucket: .tomorrow)
        transfer.recordBoardViewport(CGRect(x: 200, y: 20, width: 190, height: 200), in: .tomorrow)
        for (index, id) in ids.enumerated() {
            transfer.recordBoardRow(CGRect(x: 210, y: 30 + index * 100, width: 170, height: 60),
                                    id: id, section: section)
        }
        transfer.liftBoard(task, from: CGRect(x: 10, y: 40, width: 170, height: 60))
        transfer.trackBoard(CGSize(width: 200, height: 150), at: CGPoint(x: 300, y: 210))
        XCTAssertEqual(transfer.boardScrollTarget(in: .tomorrow, order: ids)?.id, ids[2])
        XCTAssertTrue(transfer.boardScrollTarget(in: .tomorrow, order: ids)?.downward == true)
        XCTAssertNil(transfer.boardScrollTarget(in: .today, order: ids))
        transfer.trackBoard(.zero, at: CGPoint(x: 100, y: 100))
        XCTAssertNil(transfer.boardScrollTarget(in: .tomorrow, order: ids))
        transfer.reset()
    }

    func testBoardDropInsertsAtExactPositionAndUndoRestoresSource() throws {
        let (_, store) = try makeStore()
        let task = try XCTUnwrap(store.addTask(title: "Carry", in: .today))
        let first = try XCTUnwrap(store.addTask(title: "First", in: .general))
        let second = try XCTUnwrap(store.addTask(title: "Second", in: .general))
        let originalDate = task.dueDate
        let originalOrder = task.sortOrder
        store.placeOnBoard(task, in: .general, day: nil, before: second.id)
        XCTAssertEqual(store.tasks(in: .general).active.map(\.id), [first.id, task.id, second.id])
        XCTAssertTrue(store.tasks(in: .today).active.isEmpty)
        store.undoLastAction()
        XCTAssertEqual(task.dueDate, originalDate)
        XCTAssertEqual(task.sortOrder, originalOrder)
        XCTAssertEqual(store.tasks(in: .today).active.map(\.id), [task.id])
        XCTAssertEqual(store.tasks(in: .general).active.map(\.id), [first.id, second.id])
    }

    func testBoardDropCanReorderWithinAndAcrossDatedSections() throws {
        let (_, store) = try makeStore()
        let task = try XCTUnwrap(store.addTask(title: "Carry", in: .general))
        let first = try XCTUnwrap(store.addTask(title: "First", in: .general))
        let second = try XCTUnwrap(store.addTask(title: "Second", in: .general))
        store.placeOnBoard(task, in: .general, day: nil, before: second.id)
        XCTAssertEqual(store.tasks(in: .general).active.map(\.id), [first.id, task.id, second.id])
        let day = store.calendar.date(byAdding: .day, value: 4, to: store.calendar.startOfDay(for: store.now()))!
        store.schedule(second, on: day)
        store.placeOnBoard(task, in: .general, day: day, before: second.id)
        XCTAssertEqual(store.soonSections().first(where: { $0.day == day })?.active.map(\.id), [task.id, second.id])
        store.undoLastAction()
        XCTAssertNil(task.dueDate)
        XCTAssertEqual(store.soonSections().first?.active.map(\.id), [first.id, task.id])
    }

    func testLandscapeMenuStaysVisibleWhenNeitherSideOfRowHasRoom() {
        let bounds = CGRect(x: 8, y: 8, width: 800, height: 340)
        let row = CGRect(x: 650, y: 190, width: 180, height: 60)
        let frame = SkeuMenuOverlay.menuFrame(for: row, in: bounds,
                                              menuSize: CGSize(width: 210, height: 302), gap: 8)
        XCTAssertGreaterThanOrEqual(frame.minY, bounds.minY)
        XCTAssertLessThanOrEqual(frame.maxY, bounds.maxY)
        XCTAssertGreaterThanOrEqual(frame.minX, bounds.minX)
        XCTAssertLessThanOrEqual(frame.maxX, bounds.maxX)
    }

    func testMenuLargerThanViewportIsConstrainedForScrolling() {
        let bounds = CGRect(x: 8, y: 8, width: 180, height: 240)
        let frame = SkeuMenuOverlay.menuFrame(for: CGRect(x: 80, y: 100, width: 80, height: 60),
                                              in: bounds, menuSize: CGSize(width: 210, height: 302), gap: 8)
        XCTAssertTrue(bounds.contains(frame))
    }

    func testPortraitMenuStillOpensBelowRowWhenItFits() {
        let row = CGRect(x: 20, y: 100, width: 350, height: 60)
        let frame = SkeuMenuOverlay.menuFrame(for: row, in: CGRect(x: 8, y: 8, width: 386, height: 800),
                                              menuSize: CGSize(width: 210, height: 302), gap: 8)
        XCTAssertEqual(frame.minY, row.maxY + 8)
    }

    func testFreshInstallGetsFourOrdinaryTasksOnlyOnce() throws {
        let (container, store) = try makeStore()
        let defaults = try starterDefaults()
        store.seedStarterTasksIfNeeded(isNewInstall: true, defaults: defaults)
        let tasks = store.tasks(in: .today).active
        XCTAssertEqual(tasks.count, 4)
        XCTAssertTrue(tasks.allSatisfy { !$0.isCompleted && !$0.isLiveNote && $0.workspaceID == nil })
        XCTAssertTrue(tasks.contains { $0.title.contains("Go Live") })
        store.seedStarterTasksIfNeeded(isNewInstall: true, defaults: defaults)
        XCTAssertEqual(try container.mainContext.fetchCount(FetchDescriptor<TaskItem>()), 4)
    }

    func testStarterTasksDoNotReturnAfterBeingRemoved() throws {
        let (container, store) = try makeStore()
        let defaults = try starterDefaults()
        store.seedStarterTasksIfNeeded(isNewInstall: true, defaults: defaults)
        for task in store.tasks(in: .today).active { store.delete(task) }
        store.seedStarterTasksIfNeeded(isNewInstall: true, defaults: defaults)
        XCTAssertEqual(try container.mainContext.fetchCount(FetchDescriptor<TaskItem>()), 0)
    }

    func testExistingEmptyInstallDoesNotGetStarterTasksOnUpgrade() throws {
        let (container, store) = try makeStore()
        let defaults = try starterDefaults()
        store.seedStarterTasksIfNeeded(isNewInstall: false, defaults: defaults)
        XCTAssertEqual(try container.mainContext.fetchCount(FetchDescriptor<TaskItem>()), 0)
    }

    func testExistingTasksInAnotherWorkspacePreventStarterTasks() throws {
        let (container, store) = try makeStore()
        store.workspaceID = Workspace.workID
        let task = try XCTUnwrap(store.addTask(title: "Keep my task", in: .today))
        store.workspaceID = nil
        store.seedStarterTasksIfNeeded(isNewInstall: true, defaults: try starterDefaults())
        XCTAssertEqual(try container.mainContext.fetchCount(FetchDescriptor<TaskItem>()), 1)
        XCTAssertEqual(store.anyTask(withID: task.id)?.title, "Keep my task")
    }

    func testImportedDesktopLiveTaskAppearsInTodayWithoutLocalGoLiveAction() throws {
        let (container, store) = try makeStore()
        store.knownWorkspaceIDs = [Workspace.workID]
        // An imported record bypasses the phone's writeLiveNote/makeLive helpers.
        // Legacy notes can arrive before their date field; Live still belongs to Today.
        for workspace: String? in [nil, Workspace.workID] {
            let remote = TaskItem()
            remote.title = "Live created on Mac"
            remote.workspaceID = workspace
            remote.isLiveNote = true
            remote.isPinned = true
            remote.dueDate = nil
            container.mainContext.insert(remote)
            try container.mainContext.save()
            store.workspaceID = workspace
            let row = try XCTUnwrap(store.tasks(in: .today).active.first { $0.id == remote.id })
            XCTAssertTrue(row.isLiveNote && row.isPinned, "The Today row must carry the pulsing Live marker")
            XCTAssertFalse(store.tasks(in: .tomorrow).active.contains { $0.id == remote.id })
            XCTAssertFalse(store.tasks(in: .general).active.contains { $0.id == remote.id })
            XCTAssertEqual(store.liveNote()?.id, remote.id)
            remote.isLiveNote = false; remote.isPinned = false
            try container.mainContext.save()
        }
    }

    func testLiveNoteIsTheSameTodayTaskAndCompletesFromEitherView() throws {
        let (container, store) = try makeStore()
        let note = try XCTUnwrap(store.writeLiveNote("Linked task"))
        XCTAssertEqual(store.tasks(in: .today).active.map(\.id), [note.id])
        XCTAssertEqual(store.liveNote()?.id, note.id)
        store.editTitle(note, to: "Edited in Today")
        XCTAssertEqual(store.liveNote()?.title, "Edited in Today")
        store.toggleCompleted(try XCTUnwrap(store.tasks(in: .today).active.first))
        XCTAssertNil(store.liveNote())
        XCTAssertFalse(note.isPinned)
        XCTAssertEqual(store.tasks(in: .today).completed.map(\.id), [note.id])
        XCTAssertEqual(try container.mainContext.fetchCount(FetchDescriptor<TaskItem>()), 1)
    }

    func testGoLiveMovesTomorrowIntoTodayAndPreservesReplacedTask() throws {
        let (container, store) = try makeStore()
        let old = try XCTUnwrap(store.writeLiveNote("First focus"))
        let next = try XCTUnwrap(store.addTask(title: "Tomorrow focus", in: .tomorrow))
        next.isImportant = true
        store.makeLive(next)
        XCTAssertEqual(store.liveNote()?.id, next.id)
        XCTAssertEqual(Set(store.tasks(in: .today).active.map(\.id)), Set([old.id, next.id]))
        XCTAssertTrue(store.tasks(in: .tomorrow).active.isEmpty)
        XCTAssertFalse(old.isLiveNote)
        XCTAssertFalse(old.isPinned)
        XCTAssertTrue(next.isImportant)
        XCTAssertEqual(try container.mainContext.fetchCount(FetchDescriptor<TaskItem>()), 2)
        store.toggleCompleted(next)
        XCTAssertTrue(store.tasks(in: .today).completed.contains { $0.id == next.id })
    }

    func testReplacingTypedLiveLeavesPreviousTaskInToday() throws {
        let (container, store) = try makeStore()
        let first = try XCTUnwrap(store.setLiveNote("First"))
        let second = try XCTUnwrap(store.setLiveNote("Second"))
        XCTAssertEqual(Set(store.tasks(in: .today).active.map(\.id)), Set([first.id, second.id]))
        XCTAssertFalse(first.isLiveNote)
        XCTAssertFalse(first.isPinned)
        XCTAssertEqual(store.liveNote()?.id, second.id)
        XCTAssertEqual(try container.mainContext.fetchCount(FetchDescriptor<TaskItem>()), 2)
    }

    func testMovingLiveOutOfTodayEndsFocusAndUndoRestoresIt() throws {
        let (_, store) = try makeStore()
        let task = try XCTUnwrap(store.writeLiveNote("Move focus"))
        store.move(task, to: .tomorrow)
        XCTAssertNil(store.liveNote())
        XCTAssertFalse(task.isPinned)
        XCTAssertEqual(store.tasks(in: .tomorrow).active.map(\.id), [task.id])
        store.undoLastAction()
        XCTAssertEqual(store.liveNote()?.id, task.id)
        XCTAssertTrue(task.isPinned)
        XCTAssertEqual(store.tasks(in: .today).active.map(\.id), [task.id])
    }

    func testCompletedLiveNoteAppearsInTodayAndArchivesTomorrow() throws {
        let (container, store) = try makeStore()
        _ = container
        let note = try XCTUnwrap(store.writeLiveNote("Finish this"))
        store.toggleCompleted(note)
        XCTAssertNil(store.liveNote())
        XCTAssertFalse(note.isPinned)
        XCTAssertEqual(store.tasks(in: .today).completed.map(\.id), [note.id])
        XCTAssertTrue(store.archivedTasksByDay().isEmpty)
        let tomorrow = store.calendar.date(byAdding: .day, value: 1, to: store.now())!
        store.now = { tomorrow }
        XCTAssertEqual(store.archivedTasksByDay().flatMap(\.tasks).map(\.id), [note.id])
    }

    func testEditingLiveNoteKeepsOneRecordAndIdentity() throws {
        let (container, store) = try makeStore()
        let note = try XCTUnwrap(store.writeLiveNote("First title"))
        for index in 0..<20 { store.writeLiveNote("Edited \(index)") }
        XCTAssertEqual(store.liveNote()?.id, note.id)
        XCTAssertEqual(try container.mainContext.fetchCount(FetchDescriptor<TaskItem>()), 1)
        XCTAssertEqual(note.title, "Edited 19")
    }

    func testCompletedCountIncludesTodayAndArchiveInCurrentWorkspace() throws {
        let (_, store) = try makeStore()
        store.knownWorkspaceIDs = [Workspace.workID]
        let today = try XCTUnwrap(store.addTask(title: "Today", in: .today))
        store.toggleCompleted(today)
        let old = try XCTUnwrap(store.addTask(title: "Older", in: .today))
        store.toggleCompleted(old)
        old.completedAt = store.now().addingTimeInterval(-172_800)
        _ = store.addTask(title: "Still open", in: .today)
        store.workspaceID = Workspace.workID
        let work = try XCTUnwrap(store.addTask(title: "Work", in: .today))
        store.toggleCompleted(work)
        XCTAssertEqual(store.completedTaskCount(), 1)
        store.workspaceID = nil
        XCTAssertEqual(store.completedTaskCount(), 2)
        XCTAssertEqual(store.archivedTasksByDay().flatMap(\.tasks).map(\.id), [old.id])
    }

    func testMovingWorkspacePreservesTaskAndCanBeUndone() throws {
        let (_, store) = try makeStore()
        store.seedWorkspacesIfNeeded(legacy: [])
        store.knownWorkspaceIDs = Set(store.workspaces().compactMap(\.taskStampID))
        let work = try XCTUnwrap(store.workspace(withID: Workspace.workID))
        let task = try XCTUnwrap(store.addTask(title: "Move this", in: .tomorrow))
        store.toggleImportant(task)
        store.addPhoto(task, data: Data([1, 2, 3]))
        let order = task.sortOrder
        let date = task.dueDate
        store.move(task, toWorkspace: work)
        XCTAssertTrue(store.tasks(in: .tomorrow).active.isEmpty)
        store.workspaceID = work.taskStampID
        XCTAssertEqual(store.tasks(in: .tomorrow).active.map(\.id), [task.id])
        XCTAssertEqual(task.dueDate, date)
        XCTAssertTrue(task.isImportant)
        XCTAssertEqual(task.allPhotos, [Data([1, 2, 3])])
        store.undoLastAction()
        XCTAssertNil(task.workspaceID)
        XCTAssertEqual(task.sortOrder, order)
        store.workspaceID = nil
        XCTAssertEqual(store.tasks(in: .tomorrow).active.map(\.id), [task.id])
    }

    func testLiveCompletionFromFutureDateKeepsWorkspaceAndUncompletesInToday() throws {
        let (_, store) = try makeStore()
        store.workspaceID = Workspace.workID
        let task = try XCTUnwrap(store.addTask(title: "Future task", in: .tomorrow))
        store.makeLive(task)
        store.toggleCompleted(task)
        XCTAssertEqual(store.tasks(in: .today).completed.map(\.id), [task.id])
        XCTAssertEqual(task.workspaceID, Workspace.workID)
        store.toggleCompleted(task)
        XCTAssertEqual(store.tasks(in: .today).active.map(\.id), [task.id])
        XCTAssertNil(store.liveNote())
    }

    func testReorderOffsetsMatchUnequalRowHeights() throws {
        let (_, store) = try makeStore()
        let rows = ["First", "Tall photo task", "Last"].compactMap {
            store.addTask(title: $0, in: .today)
        }
        let reorder = ReorderCoordinator()
        reorder.rowGap = 10
        for (row, height) in zip(rows, [50.0, 120.0, 60.0]) {
            reorder.heights.record(height, for: row.id)
        }
        reorder.begin(rows[0], in: rows.map(\.id), frame: .zero)
        reorder.update(195)
        XCTAssertEqual(reorder.destination()?.above, rows[2].id)
        XCTAssertEqual(reorder.offset(for: rows[1].id), -60)
        XCTAssertEqual(reorder.settle, 200)
        reorder.flyHome()
        XCTAssertEqual(reorder.travel, 200)
    }

    func testEditingStaleLiveActivityUpdatesSameCard() async throws {
        let (_, store) = try makeStore()
        let note = try XCTUnwrap(store.writeLiveNote("Before edit"))
        let client = TestActivities()
        let controller = LiveActivityController(client: client.client)
        let settings = AppSettings()
        controller.reconcile(store: store, settings: settings, isDark: false)
        for _ in 0..<10 { await Task.yield() }
        let original = try XCTUnwrap(client.entries.first)
        original.state = .stale
        store.writeLiveNote("After edit")
        controller.reconcile(store: store, settings: settings, isDark: false)
        for _ in 0..<10 { await Task.yield() }
        let remaining = client.entries.filter { $0.state != .ended && $0.state != .dismissed }
        XCTAssertEqual(remaining.count, 1)
        XCTAssertEqual(remaining.first?.id, original.id)
        XCTAssertEqual(remaining.first?.title, "After edit")
        XCTAssertEqual(remaining.first?.taskID, note.id)
    }

    func testPendingLiveActivityAndDuplicateRecovery() async throws {
        let (_, store) = try makeStore()
        store.writeLiveNote("Original")
        let client = TestActivities()
        let controller = LiveActivityController(client: client.client)
        let settings = AppSettings()
        controller.reconcile(store: store, settings: settings, isDark: false)
        for _ in 0..<10 { await Task.yield() }
        let original = try XCTUnwrap(client.entries.first)
        if #available(iOS 26, *) { original.state = .pending }
        let duplicate = TestActivities.Entry(taskID: original.taskID, content: original.content)
        client.entries.append(duplicate)
        for index in 0..<20 {
            store.writeLiveNote("Edited \(index)")
            controller.reconcile(store: store, settings: settings, isDark: false)
            await Task.yield()
        }
        for _ in 0..<30 { await Task.yield() }
        XCTAssertEqual(client.entries.filter { $0.state != .ended }.count, 1)
        XCTAssertEqual(original.title, "Edited 19")
        XCTAssertEqual(duplicate.state, .ended)
        let note = try XCTUnwrap(store.liveNote())
        store.toggleCompleted(note)
        controller.reconcile(store: store, settings: settings, isDark: false)
        for _ in 0..<10 { await Task.yield() }
        XCTAssertTrue(client.entries.allSatisfy { $0.state == .ended })
    }

    func testLiveCompletionDrawsFinalStateBeforeDismissal() async throws {
        let (_, store) = try makeStore()
        let note = try XCTUnwrap(store.writeLiveNote("Draw a line through this"))
        let client = TestActivities()
        let pause = CompletionPause()
        let controller = LiveActivityController(client: client.client, completionPause: { await pause.wait() })
        let settings = AppSettings()
        controller.reconcile(store: store, settings: settings, isDark: false)
        for _ in 0..<10 { await Task.yield() }
        let card = try XCTUnwrap(client.entries.first)
        let completion = Task { await controller.complete(taskID: note.id, store: store) }
        defer { pause.finish() }
        for _ in 0..<100 {
            if pause.isWaiting { break }
            await Task.yield()
        }
        XCTAssertTrue(pause.isWaiting)
        XCTAssertEqual(card.content.isCompleted, true)
        XCTAssertTrue(note.isCompleted)
        XCTAssertEqual(store.tasks(in: .today).completed.map(\.id), [note.id])
        XCTAssertEqual(card.state, .active)

        // Foreground/revision refreshes and a second tap must not remove the
        // card early, reset the final state or toggle the task back to open.
        controller.reconcile(store: store, settings: settings, isDark: true)
        await controller.complete(taskID: note.id, store: store)
        for _ in 0..<20 { await Task.yield() }
        XCTAssertEqual(card.state, .active)
        XCTAssertEqual(card.content.isCompleted, true)
        XCTAssertTrue(note.isCompleted)
        pause.finish()
        await completion.value
        XCTAssertEqual(card.state, .ended)
        XCTAssertEqual(card.endCount, 1)
    }

    func testWorkspaceMorphStaysInsideButtonRightEdgeThroughBothDirections() throws {
        for inset in [CGFloat(0), 51] {
            var opening: [CGRect] = []
            for step in 0...10 {
                let bounds = try renderedWorkspaceBounds(progress: CGFloat(step) / 10, inset: inset)
                XCTAssertLessThanOrEqual(bounds.maxX, 400, "Right edge escaped at step \(step)")
                opening.append(bounds)
            }
            // The same rendered positions must be visited on the way back,
            // including the notch-side translation and the mid-morph swell.
            for step in (0...10).reversed() {
                XCTAssertEqual(try renderedWorkspaceBounds(progress: CGFloat(step) / 10, inset: inset),
                               opening[step])
            }
            XCTAssertGreaterThan(opening[0].minX, opening[10].minX)
            XCTAssertGreaterThan(opening[10].height, opening[0].height)
        }
    }

    func testWorkspaceAnimationDoesNotRebuildItsGlassTreeEveryDisplayFrame() async throws {
        let scene = try XCTUnwrap(UIApplication.shared.connectedScenes.first as? UIWindowScene)
        let previousKey = scene.windows.first(where: \.isKeyWindow)
        let state = WorkspaceAnimationState()
        let window = UIWindow(windowScene: scene)
        window.frame = CGRect(x: 0, y: 0, width: 400, height: 400)
        window.rootViewController = UIHostingController(rootView: WorkspaceAnimationHarness(state: state))
        window.makeKeyAndVisible()
        defer { window.isHidden = true; previousKey?.makeKey() }
        try await Task.sleep(for: .milliseconds(150))
        WorkspaceMenuPerformance.bodyBuilds = 0
        withAnimation(.easeInOut(duration: 0.42)) { state.progress = 1 }
        try await Task.sleep(for: .milliseconds(650))
        let openingBuilds = WorkspaceMenuPerformance.bodyBuilds
        WorkspaceMenuPerformance.bodyBuilds = 0
        withAnimation(.easeInOut(duration: 0.42)) { state.progress = 0 }
        try await Task.sleep(for: .milliseconds(650))
        let closingBuilds = WorkspaceMenuPerformance.bodyBuilds
        print("Workspace animation glass tree builds: opening=\(openingBuilds), closing=\(closingBuilds)")
        XCTAssertLessThan(openingBuilds, 10, "Only endpoints should rebuild the glass/material tree")
        XCTAssertLessThan(closingBuilds, 10, "Closing must use compositor interpolation too")
    }

    func testWorkspaceMorphReusesGlassInsteadOfBakingEveryFrame() throws {
        _ = try renderedWorkspaceBounds(progress: 0, inset: 51)
        let warmedCount = SkeuGlassBakery.renderCount
        for step in 1...30 {
            _ = try renderedWorkspaceBounds(progress: CGFloat(step) / 30, inset: 51)
        }
        XCTAssertEqual(SkeuGlassBakery.renderCount, warmedCount,
                       "Resizing the menu must not render a new glass image per frame")
    }

    private func renderedWorkspaceBounds(progress: CGFloat, inset: CGFloat) throws -> CGRect {
        let view = Rectangle().fill(.red)
            .modifier(WorkspaceMenuMorph(progress: progress, controlSize: 44,
                openSize: CGSize(width: 200, height: 132), trailingInset: inset, reduceMotion: false))
            .frame(width: 360, height: 240, alignment: .topTrailing)
            .padding(40)
            .background(.white)
        let renderer = ImageRenderer(content: view)
        renderer.scale = 1
        let image = try XCTUnwrap(renderer.cgImage)
        let context = try XCTUnwrap(CGContext(data: nil, width: image.width, height: image.height,
            bitsPerComponent: 8, bytesPerRow: image.width * 4, space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue | CGBitmapInfo.byteOrder32Big.rawValue))
        context.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
        let bytes = try XCTUnwrap(context.data).assumingMemoryBound(to: UInt8.self)
        var bounds = CGRect.null
        for y in 0..<image.height {
            for x in 0..<image.width {
                let offset = y * image.width * 4 + x * 4
                if bytes[offset] > 160
                    && Int(bytes[offset]) > Int(bytes[offset + 1]) + 30
                    && Int(bytes[offset]) > Int(bytes[offset + 2]) + 30 {
                    bounds = bounds.union(CGRect(x: x, y: y, width: 1, height: 1))
                }
            }
        }
        XCTAssertFalse(bounds.isNull)
        return bounds
    }

    private func renderedStrikePixels(progress: CGFloat, text: String) throws -> [(x: Int, y: Int)] {
        let view = Text(verbatim: text)
            .font(.system(size: 20))
            // Paint real glyphs as in the widget, but distinguish the stroke
            // by colour so an actually drawn line is required to pass.
            .foregroundStyle(.black)
            .lineLimit(3)
            .textRenderer(ActivityCompletionTextRenderer(progress: progress, color: .red))
            .fixedSize(horizontal: false, vertical: true)
            .frame(width: 220, height: 100, alignment: .topLeading)
            .background(.white)
        let renderer = ImageRenderer(content: view)
        renderer.scale = 1
        let image = try XCTUnwrap(renderer.cgImage)
        let attachment = XCTAttachment(image: UIImage(cgImage: image))
        attachment.name = "strike-\(progress)-\(text.contains("\n") ? "wrapped" : "single")"
        attachment.lifetime = .keepAlways
        add(attachment)
        let context = try XCTUnwrap(CGContext(data: nil, width: image.width, height: image.height,
            bitsPerComponent: 8, bytesPerRow: image.width * 4, space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue | CGBitmapInfo.byteOrder32Big.rawValue))
        context.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
        let bytes = try XCTUnwrap(context.data).assumingMemoryBound(to: UInt8.self)
        var pixels: [(Int, Int)] = []
        for y in 0..<image.height {
            for x in 0..<image.width {
                let offset = y * image.width * 4 + x * 4
                if bytes[offset] > 160
                    && Int(bytes[offset]) > Int(bytes[offset + 1]) + 30
                    && Int(bytes[offset]) > Int(bytes[offset + 2]) + 30 {
                    pixels.append((x, y))
                }
            }
        }
        return pixels
    }

    func testCompletionStrikeActuallyDrawsAndGrowsLeftToRight() throws {
        let start = try renderedStrikePixels(progress: 0, text: "Complete this task")
        let early = try renderedStrikePixels(progress: 0.1, text: "Complete this task")
        let halfway = try renderedStrikePixels(progress: 0.5, text: "Complete this task")
        let end = try renderedStrikePixels(progress: 1, text: "Complete this task")
        XCTAssertTrue(start.isEmpty)
        XCTAssertFalse(early.isEmpty)
        XCTAssertEqual(early.map(\.x).min(), end.map(\.x).min())
        XCTAssertLessThan(try XCTUnwrap(early.map(\.x).max()),
                          Int(Double(try XCTUnwrap(end.map(\.x).max())) * 0.18))
        XCTAssertGreaterThan(halfway.count, 20)
        XCTAssertGreaterThan(end.count, Int(Double(halfway.count) * 1.7))
        XCTAssertEqual(halfway.map(\.x).min(), end.map(\.x).min())
        XCTAssertLessThan(try XCTUnwrap(halfway.map(\.x).max()),
                          Int(Double(try XCTUnwrap(end.map(\.x).max())) * 0.65))
    }

    func testCompletionStrikeDrawsAcrossEveryWrappedTextLine() throws {
        let pixels = try renderedStrikePixels(progress: 1, text: "First line\nSecond line\nThird line")
        let rows = Set(pixels.map(\.y)).sorted()
        var lines = 0
        var previous = -10
        for row in rows {
            if row - previous > 2 { lines += 1 }
            previous = row
        }
        XCTAssertEqual(lines, 3)
    }

    func testCancelledIntentCannotDismissBeforeCompletionAnimationWindow() async throws {
        let (_, store) = try makeStore()
        let note = try XCTUnwrap(store.writeLiveNote("Finish the animation"))
        let client = TestActivities()
        let controller = LiveActivityController(client: client.client)
        controller.reconcile(store: store, settings: AppSettings(), isDark: false)
        for _ in 0..<20 { await Task.yield() }
        let card = try XCTUnwrap(client.entries.first)
        let start = ContinuousClock.now
        let completion = Task { await controller.complete(taskID: note.id, store: store) }
        for _ in 0..<100 {
            if card.content.isCompleted == true { break }
            await Task.yield()
        }
        XCTAssertEqual(card.content.isCompleted, true)
        XCTAssertEqual(card.state, .active)
        completion.cancel()
        await completion.value
        XCTAssertGreaterThanOrEqual(start.duration(to: .now),
                                    .seconds(PinnedTaskCompletionTiming.dismissalDelay))
        XCTAssertEqual(card.state, .ended)
        XCTAssertEqual(card.endCount, 1)
    }

    func testFinishingOldLiveCardDoesNotDismissNewTask() async throws {
        let (_, store) = try makeStore()
        let first = try XCTUnwrap(store.writeLiveNote("Finish first"))
        let client = TestActivities()
        let pause = CompletionPause()
        let controller = LiveActivityController(client: client.client, completionPause: { await pause.wait() })
        let settings = AppSettings()
        controller.reconcile(store: store, settings: settings, isDark: false)
        for _ in 0..<10 { await Task.yield() }
        let completion = Task { await controller.complete(taskID: first.id, store: store) }
        defer { pause.finish() }
        for _ in 0..<100 {
            if pause.isWaiting { break }
            await Task.yield()
        }
        XCTAssertTrue(pause.isWaiting)
        let second = try XCTUnwrap(store.writeLiveNote("Next task"))
        controller.reconcile(store: store, settings: settings, isDark: false)
        for _ in 0..<20 { await Task.yield() }
        pause.finish()
        await completion.value
        let nextCard = try XCTUnwrap(client.entries.first { $0.taskID == second.id })
        XCTAssertEqual(nextCard.state, .active)
        XCTAssertEqual(nextCard.content.isCompleted, false)
        XCTAssertEqual(store.liveNote()?.id, second.id)
    }

    func testCompletionWithoutVisibleCardStillSavesTask() async throws {
        let (_, store) = try makeStore()
        let note = try XCTUnwrap(store.writeLiveNote("No card"))
        var pauses = 0
        let controller = LiveActivityController(client: TestActivities().client,
                                                completionPause: { pauses += 1 })
        await controller.complete(taskID: note.id, store: store)
        XCTAssertTrue(note.isCompleted)
        XCTAssertEqual(pauses, 0)
    }

    func testLiveContentFromOlderBuildStillDecodes() async throws {
        let (_, store) = try makeStore()
        store.writeLiveNote("Old card")
        let client = TestActivities()
        let controller = LiveActivityController(client: client.client)
        controller.reconcile(store: store, settings: AppSettings(), isDark: false)
        for _ in 0..<10 { await Task.yield() }
        let content = try XCTUnwrap(client.entries.first?.content)
        var json = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(content)) as? [String: Any])
        json.removeValue(forKey: "isCompleted")
        let decoded = try JSONDecoder().decode(PinnedTaskAttributes.ContentState.self,
            from: JSONSerialization.data(withJSONObject: json))
        XCTAssertNil(decoded.isCompleted)
        XCTAssertEqual(decoded.title, "Old card")
        XCTAssertEqual(decoded.palette, content.palette)
    }
}

@MainActor
private final class CompletionPause {
    private var continuation: CheckedContinuation<Void, Never>?
    var isWaiting: Bool { continuation != nil }
    func wait() async { await withCheckedContinuation { continuation = $0 } }
    func finish() { continuation?.resume(); continuation = nil }
}

@MainActor
private final class TestActivities {
    final class Entry {
        let id = UUID().uuidString
        let taskID: UUID
        var state = ActivityState.active
        var content: PinnedTaskAttributes.ContentState
        var title: String { content.title }
        var endCount = 0
        init(taskID: UUID, content: PinnedTaskAttributes.ContentState) {
            self.taskID = taskID; self.content = content
        }
        var card: LiveActivityClient.Card {
            .init(id: id, taskID: taskID, state: { self.state },
                  content: { self.content },
                  update: { state in await Task.yield(); self.content = state },
                  end: { await Task.yield(); self.endCount += 1; self.state = .ended })
        }
    }
    var entries: [Entry] = []
    var client: LiveActivityClient {
        .init(enabled: { true }, cards: { self.entries.map(\.card) }, request: { id, state in
            let entry = Entry(taskID: id, content: state)
            self.entries.append(entry)
            return entry.card
        })
    }
}

@MainActor @Observable private final class WorkspaceAnimationState {
    var progress: CGFloat = 0
}
private struct WorkspaceAnimationHarness: View {
    var state: WorkspaceAnimationState
    var body: some View {
        Text("Personal").frame(width: 200, height: 132)
            .modifier(WorkspaceMenuMorph(progress: state.progress, controlSize: 44,
                openSize: CGSize(width: 200, height: 132), trailingInset: 51, reduceMotion: false))
            .frame(width: 360, height: 240, alignment: .topTrailing)
            .padding(20)
    }
}
