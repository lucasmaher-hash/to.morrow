//
//  LiveActivityController.swift
//  shove95
//
//  Keeps the Lock Screen showing whatever the store says is pinned.
//
//  RECONCILIATION, not commands. The obvious shape is `pin() { start() }` and
//  `unpin() { end() }`, and it is wrong: a pin can also disappear because the
//  task was completed, deleted, archived, rolled over at midnight, or
//  un-pinned on another device and synced here. Each of those would need its
//  own call, and the first one anyone forgot would leave a ghost card on the
//  Lock Screen with no way to dismiss it.
//
//  So nothing calls "start" or "stop". `reconcile()` looks at the store and
//  makes ActivityKit match, and every mutation path already bumps
//  `TaskStore.revision`, which is what triggers it. One code path, and no way
//  to add a sixth way of losing a pin without it being handled.
//
//  THE 8-HOUR CEILING. iOS ends every Live Activity after at most eight
//  hours. The founder's answer (2026-08-16) is that the pin belongs to the
//  TASK, not to the activity: if the store says something is pinned and no
//  activity is running, this starts a fresh one. Since reconcile runs on
//  foreground, the pin feels open-ended as long as the app is opened now and
//  then — which is the honest version of "it stays until you turn it off".
//

import SwiftUI
import ActivityKit
import Shove95Kit

/// ActivityKit operations at one boundary, also usable with an in-memory
/// client in regression tests (a test host cannot request Lock Screen cards).
@MainActor
struct LiveActivityClient {
    struct Card {
        let id: String
        let taskID: UUID
        let state: () -> ActivityState
        let content: () -> PinnedTaskAttributes.ContentState
        let update: (PinnedTaskAttributes.ContentState) async -> Void
        let end: () async -> Void

        init(_ activity: Activity<PinnedTaskAttributes>) {
            id = activity.id
            taskID = activity.attributes.taskID
            state = { activity.activityState }
            content = { activity.content.state }
            update = { await activity.update(ActivityContent(state: $0, staleDate: nil)) }
            end = { await activity.end(nil, dismissalPolicy: .immediate) }
        }

        init(id: String, taskID: UUID, state: @escaping () -> ActivityState,
             content: @escaping () -> PinnedTaskAttributes.ContentState,
             update: @escaping (PinnedTaskAttributes.ContentState) async -> Void,
             end: @escaping () async -> Void) {
            self.id = id; self.taskID = taskID; self.state = state
            self.content = content
            self.update = update; self.end = end
        }
    }

    var enabled: () -> Bool
    var cards: () -> [Card]
    var request: (UUID, PinnedTaskAttributes.ContentState) throws -> Card

    static var system: Self {
        .init(enabled: { ActivityAuthorizationInfo().areActivitiesEnabled },
              cards: { Activity<PinnedTaskAttributes>.activities.map(Card.init) },
              request: { id, state in
                  Card(try Activity.request(attributes: PinnedTaskAttributes(taskID: id),
                       content: ActivityContent(state: state, staleDate: nil)))
              })
    }
}

@MainActor
@Observable
final class LiveActivityController {

    /// True when iOS has Live Activities switched off for to.morrow. The pin
    /// still works — it is app state — but nothing reaches the Lock Screen,
    /// and the user is told once (founder direction 2026-08-16).
    var activitiesDisabled: Bool {
        !client.enabled()
    }

    private let client: LiveActivityClient
    private var current: LiveActivityClient.Card?
    private var completingTasks: Set<UUID> = []
    private let completionPause: () async -> Void

    init(client: LiveActivityClient? = nil, completionPause: (() async -> Void)? = nil) {
        self.client = client ?? .system
        self.completionPause = completionPause ?? {
            // Intent cancellation must not skip the widget's final animation
            // window. This independent delay finishes before we end the card.
            _ = await Task.detached {
                try? await Task.sleep(for: .seconds(PinnedTaskCompletionTiming.dismissalDelay))
            }.value
        }
    }

    private var reconciling = false
    private var reconciliationTask: Task<Void, Never>?
    private var nextPass: (store: TaskStore, settings: AppSettings, isDark: Bool)?

    /// Makes the Lock Screen match the store. Safe to call as often as you
    /// like — it is a no-op when nothing has changed.
    func reconcile(store: TaskStore, settings: AppSettings, isDark: Bool) {
        nextPass = (store, settings, isDark)
        guard !reconciling else { return }
        reconciling = true
        // Serialize updates AND removals, not just replacements. A new pass
        // while an end/update is suspended must not adopt the outgoing card
        // or overwrite a newer title with an older update.
        reconciliationTask = Task {
            while let pass = nextPass {
                nextPass = nil
                await apply(store: pass.store, settings: pass.settings, isDark: pass.isDark)
            }
            reconciling = false
        }
    }

    private func apply(store: TaskStore, settings: AppSettings, isDark: Bool) async {
        let cards = allCards()
        let task = client.enabled() ? store.pinnedTask() : nil
        let wantedID = task.flatMap { $0.isCompleted ? nil : $0.id }
        let keep = cards.first { $0.taskID == wantedID && Self.isOngoing($0.state()) }

        // Also clean up duplicates while we already hold a handle, including
        // ended cards that iOS can otherwise leave on the Lock Screen.
        for card in cards where card.id != keep?.id && !completingTasks.contains(card.taskID) {
            await card.end()
        }
        current = keep
        // Re-read the store after the await. A completion or replacement may
        // have arrived while old cards were being dismissed.
        if nextPass != nil { return }
        guard let task, !task.isCompleted else { return }
        let state = contentState(for: task, store: store, settings: settings, isDark: isDark)

        if let keep {
            if !completingTasks.contains(keep.taskID) { await keep.update(state) }
        } else {
            current = try? client.request(task.id, state)
        }
    }

    /// Commit immediately, then give the widget time to draw its final state.
    /// The same controller serves the scene and the background App Intent so
    /// revision/foreground updates cannot retire or overwrite the card early.
    func complete(taskID: UUID, store: TaskStore) async {
        guard !completingTasks.contains(taskID),
              store.anyTask(withID: taskID)?.isCompleted == false else { return }
        completingTasks.insert(taskID)
        defer { completingTasks.remove(taskID) }

        // Finish any older title/theme update before sending the final state.
        await reconciliationTask?.value
        guard let task = store.anyTask(withID: taskID), !task.isCompleted else { return }
        let cards = allCards().filter { $0.taskID == taskID && Self.isOngoing($0.state()) }
        store.toggleCompleted(task)
        for card in cards {
            var finalState = card.content()
            finalState.isCompleted = true
            await card.update(finalState)
        }
        if !cards.isEmpty { await completionPause() }
        for card in cards { await card.end() }
        if current?.taskID == taskID { current = nil }
    }

    private func allCards() -> [LiveActivityClient.Card] {
        var cards = client.cards()
        // ActivityKit's list may lag immediately after a request.
        if let current, !cards.contains(where: { $0.id == current.id }) {
            cards.append(current)
        }
        return cards
    }

    static func isOngoing(_ state: ActivityState) -> Bool {
        // Stale content still owns a card. iOS 26's pending activities also
        // keep their identity; only ended/dismissed cards need replacing.
        state != .ended && state != .dismissed
    }

    // MARK: Resolving the look

    /// The app is the only place allowed to know colours, so it resolves them
    /// here and the widget draws what it is handed — see PinnedTaskActivity.
    private func contentState(for task: TaskItem,
                              store: TaskStore,
                              settings: AppSettings,
                              isDark: Bool) -> PinnedTaskAttributes.ContentState {
        let chip = ChipFormat.label(dueDate: task.dueDate,
                                    isCompleted: task.isCompleted,
                                    now: store.now(),
                                    calendar: store.calendar)

        // One look — the Windows 95 variant was removed on 2026-08-22.
        //
        // The Lock Screen card never carried the pixel face anyway unless the
        // reader had chosen the all-pixel option, and that option is gone too:
        // the blend keeps the pixel face for CHROME, and a live note is the
        // user's own words. So the card is set in the system face, always.
        let palette = settings.skeuTheme.palette(dark: isDark)
        return .init(
            title: task.title,
            chip: chip,
            look: .skeu,
            palette: ActivityPalette(
                surface: .init(palette.material),
                ink: .init(palette.ink),
                inkMuted: .init(palette.inkMuted),
                accent: .init(palette.accent),
                light: .init(palette.edgeLight),
                dark: .init(palette.shadow)),
            fontName: nil)
    }
}

// MARK: - Colour bridging

extension ActivityColor {
    /// From the 24-bit literals the palettes are written in.
    init(hex: UInt32) {
        self.init(red: Double((hex >> 16) & 0xFF) / 255,
                  green: Double((hex >> 8) & 0xFF) / 255,
                  blue: Double(hex & 0xFF) / 255)
    }

    /// From a SwiftKit `Color`, which is how the skeu palettes are written.
    ///
    /// Resolved against the LIGHT trait deliberately: the palette handed in
    /// is already the dark one when dark is what the user picked, so
    /// resolving it again against the device trait would darken it twice.
    init(_ color: Color) {
        let resolved = UIColor(color).resolvedColor(with: UITraitCollection(userInterfaceStyle: .light))
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        resolved.getRed(&r, green: &g, blue: &b, alpha: &a)
        self.init(red: Double(r), green: Double(g), blue: Double(b), alpha: Double(a))
    }
}
