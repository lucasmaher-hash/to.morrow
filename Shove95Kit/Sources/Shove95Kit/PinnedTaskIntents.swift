//
//  PinnedTaskIntents.swift
//  Shove95Kit
//
//  The tick button on the Lock Screen card.
//
//  `LiveActivityIntent` is the reason this feature needs no App Group. A
//  plain `AppIntent` on a widget button performs in the WIDGET's process,
//  which cannot reach the app's SwiftData store without a shared container —
//  and a shared container means an App Group, which means provisioning work
//  and a store migration. A `LiveActivityIntent` performs in the APP's
//  process instead: iOS launches the app in the background to run it, so the
//  store is simply there, exactly as the app always sees it.
//
//  The intent still has to be visible to BOTH targets — the widget needs the
//  type to build the button, the app needs it to perform — hence the package.
//  What it must NOT do is reach into the app's types from here, so the work
//  goes through a hook the app installs at launch.
//

import Foundation

// `os(iOS)` for the same reason as PinnedTaskActivity: AppIntents is
// importable on macOS but `LiveActivityIntent` is unavailable there.
#if os(iOS)
import AppIntents

/// The seam between an intent defined down here and a store defined up in the
/// app. The app installs this in its `init`, which runs during launch and so
/// is in place before any intent performs — including on the background
/// launch iOS does to run one.
public enum PinnedTaskActions {
    nonisolated(unsafe)
    public static var complete: (@MainActor (UUID) async -> Void)?
}

/// Ticks the pinned task off from the Lock Screen or the Dynamic Island.
///
/// Completing releases the pin (`TaskStore.toggleCompleted`), so the card
/// retires itself — which is the whole gesture: the one thing following you
/// around is done, and it stops following you.
public struct CompletePinnedTaskIntent: LiveActivityIntent {
    public static let title: LocalizedStringResource = "Complete Task"
    public static let isDiscoverable: Bool = false

    /// A string rather than a `UUID`: `@Parameter` needs a type conforming to
    /// AppIntents' value protocols, and `UUID` is not one of them.
    @Parameter(title: "Task")
    public var taskID: String

    public init() {}

    public init(taskID: UUID) {
        self.taskID = taskID.uuidString
    }

    public func perform() async throws -> some IntentResult {
        if let id = UUID(uuidString: taskID) {
            await PinnedTaskActions.complete?(id)
        }
        return .result()
    }
}

#endif
