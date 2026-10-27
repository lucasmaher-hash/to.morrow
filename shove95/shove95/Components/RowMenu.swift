//
//  RowMenu.swift
//  shove95
//
//  Which row's menu is open, and what it was asked to do.
//
//  This outlived the interface it was written for: the Windows 95 look owned
//  the file it used to sit in and was removed on 2026-08-22, but the
//  coordinator was never look-specific — it holds a task id and a rectangle,
//  and the skeu menu reads exactly the same two things.
//

import SwiftUI
import Shove95Kit

// MARK: - Coordinator

/// What the root view needs in order to draw a menu: which task, and where the
/// finger was. Lives above the list so the panel is never clipped by the
/// scroll view.
struct RowMenuRequest: Equatable {
    let taskID: UUID
    /// The row's frame in GLOBAL coordinates. The overlay needs the whole rect,
    /// not a single anchor: near the bottom of the screen the menu has to flip
    /// ABOVE the row, or Delete lands off-screen and is unreachable (founder
    /// bug report 2026-08-04).
    let rowFrame: CGRect

    static func == (a: RowMenuRequest, b: RowMenuRequest) -> Bool {
        a.taskID == b.taskID && a.rowFrame == b.rowFrame
    }
}

@Observable @MainActor
final class MenuCoordinator {
    var request: RowMenuRequest?
    /// The task waiting on a yes to take over the Live section.
    ///
    /// Held HERE rather than in either root view because the menu that asks
    /// for it is drawn by an overlay, not by the row — and both looks render
    /// their dialog from the same signal.
    var pendingLive: TaskItem?

    /// The live note waiting on a yes to be thrown away.
    ///
    /// Here for the same reason as `pendingLive`, and for one of its own: the
    /// dialog was an overlay INSIDE the Live section, whose frame is only the
    /// band between the workspace bar and the tab bar. Its scrim could not
    /// reach past them however much safe area it ignored, so the screen dimmed
    /// in the middle and stayed lit top and bottom (founder bug report
    /// 2026-09-01). Asked from here, it is drawn by the root, over everything.
    var pendingLiveDelete = false

    /// Sends a task live, asking first when something already holds it.
    func goLive(_ task: TaskItem, store: TaskStore) {
        if store.liveNote() == nil {
            store.makeLive(task)
        } else {
            pendingLive = task
        }
    }

    func confirmLive(store: TaskStore) {
        if let task = pendingLive { store.makeLive(task) }
        pendingLive = nil
    }

    func cancelLive() { pendingLive = nil }

    /// Springs in with a little overshoot; the anchor is the row's bottom-left,
    /// so it grows out of the row the way a menu drops from what opened it.
    func show(task: TaskItem, rowFrame: CGRect) {
        withAnimation(.spring(duration: 0.26, bounce: 0.38)) {
            request = RowMenuRequest(taskID: task.id, rowFrame: rowFrame)
        }
    }

    func dismiss() {
        withAnimation(.easeOut(duration: 0.11)) { request = nil }
    }

    func isShowing(_ task: TaskItem) -> Bool {
        request?.taskID == task.id
    }
}
