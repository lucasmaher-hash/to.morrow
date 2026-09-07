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

@MainActor
@Observable
final class LiveActivityController {

    /// True when iOS has Live Activities switched off for to morrow. The pin
    /// still works — it is app state — but nothing reaches the Lock Screen,
    /// and the user is told once (founder direction 2026-08-16).
    var activitiesDisabled: Bool {
        !ActivityAuthorizationInfo().areActivitiesEnabled
    }

    private var current: Activity<PinnedTaskAttributes>?

    /// True while a card is being retired and its replacement requested. The
    /// two halves straddle an `await`, and `current` is nil in between, so
    /// reconciles arriving in that window have to wait rather than act on
    /// what looks like an empty Lock Screen.
    private var swapping = false
    /// The most recent reconcile that arrived during a swap, replayed when
    /// the swap lands. Only the last one is kept — they are all asking the
    /// same question, "match the store", and the newest inputs are the ones
    /// worth answering.
    private var missedPass: (store: TaskStore, settings: AppSettings, isDark: Bool)?

    /// Makes the Lock Screen match the store. Safe to call as often as you
    /// like — it is a no-op when nothing has changed.
    func reconcile(store: TaskStore, settings: AppSettings, isDark: Bool) {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else {
            // Permission can be revoked while an activity is up; drop the
            // handle so a later grant starts cleanly rather than trying to
            // update a card iOS has already taken away.
            Task { await endAll() }
            current = nil
            return
        }

        // A swap is mid-flight. Requesting now is exactly how two cards for
        // the SAME task end up on the Lock Screen: `current` was cleared
        // synchronously, so this pass would see nothing running, fall through
        // to the swap branch and request a second one — and only the later
        // handle survives, leaving the first card unendable until iOS's
        // eight-hour ceiling. Remember the pass and let the swap replay it.
        guard !swapping else {
            missedPass = (store, settings, isDark)
            return
        }

        // Adopt anything already running — after a cold launch this process
        // has no handle on the activity from the last one, and requesting a
        // second would leave two cards on the Lock Screen.
        // A handle whose activity iOS has already ENDED is not a running
        // card. iOS retires every Live Activity at an eight-hour ceiling and
        // tells nobody, so `current` stayed non-nil pointing at a dead
        // activity — every later reconcile then `update`d into the void and
        // the Lock Screen stayed empty for the rest of the process (found in
        // review 2026-08-26). Dropping the stale handle lets the request path
        // below build a fresh card.
        if let running = current, running.activityState != .active {
            current = nil
        }

        if current == nil {
            // `.active` only, for the reason above — `Activity.activities` can
            // still list one iOS has just ended.
            let running = Activity<PinnedTaskAttributes>.activities
                .filter { $0.activityState == .active }
            current = running.first
            // Retire any extras a previous run left behind. Without this a
            // ghost from a crashed session is invisible to every code path
            // here — `endAll` only runs when permission is revoked.
            if running.count > 1 {
                let extras = running.dropFirst()
                Task { for activity in extras { await activity.end(nil, dismissalPolicy: .immediate) } }
            }
        }

        guard let task = store.pinnedTask(), !task.isCompleted else {
            let running = current
            current = nil
            Task { await running?.end(nil, dismissalPolicy: .immediate) }
            return
        }

        let state = contentState(for: task, store: store, settings: settings, isDark: isDark)

        if let running = current, running.attributes.taskID == task.id {
            Task { await running.update(ActivityContent(state: state, staleDate: nil)) }
            return
        }

        // A DIFFERENT task holds the pin. taskID is immutable for an
        // activity's lifetime, so the old card is retired and a new one
        // requested rather than mutated.
        let outgoing = current
        current = nil
        swapping = true
        Task {
            await outgoing?.end(nil, dismissalPolicy: .immediate)
            current = try? Activity.request(
                attributes: PinnedTaskAttributes(taskID: task.id),
                content: ActivityContent(state: state, staleDate: nil))
            swapping = false
            // Anything that arrived while the swap was in flight is replayed
            // now, against the handle that actually exists.
            if let missed = missedPass {
                missedPass = nil
                reconcile(store: missed.store, settings: missed.settings, isDark: missed.isDark)
            }
        }
    }

    private func endAll() async {
        for activity in Activity<PinnedTaskAttributes>.activities {
            await activity.end(nil, dismissalPolicy: .immediate)
        }
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
