//
//  TaskStore.swift
//  shove95
//
//  The @Observable façade (PRD §4). The ONLY object that touches the
//  ModelContext — views never do. All date logic delegates to Shove95Kit's
//  DateEngine; `now`/`calendar` are injected here and nowhere else.
//

import Foundation
import SwiftData
import CoreData   // NSPersistentStoreRemoteChange — see observeRemoteChanges
import UIKit
import Shove95Kit

// MARK: - Undo record (PRD §4)

/// Full field copy for delete-undo resurrection.
struct TaskSnapshot {
    let title: String
    let dueDate: Date?
    let isImportant: Bool
    let isCompleted: Bool
    let completedAt: Date?
    let createdAt: Date
    let sortOrder: Double
    let overduePlaced: Bool
    /// WHICH LIST it came from. Absent, undo rebuilt the task with a nil
    /// workspace, which the scoped queries read as the default one — so
    /// undoing a delete inside "Work" silently moved the task to Personal and
    /// it looked like undo had simply failed (found in review 2026-08-26).
    let workspaceID: String?
    /// Live state, so undoing the replacement `makeLive` performs can put the
    /// old note back where it was rather than as a loose task.
    let isLiveNote: Bool
    let isPinned: Bool
    /// Raw bytes, oldest first — the records themselves are gone by the time
    /// undo runs (cascade delete), so the snapshot has to carry the payload.
    let photos: [Data]
}

enum LastAction {
    case moved(taskID: UUID, title: String, to: Bucket,
               previousDueDate: Date?, previousSortOrder: Double, previousOverduePlaced: Bool)
    case deleted(snapshot: TaskSnapshot)

    /// Status-panel text (voice rules: terse, no exclamation marks).
    /// `name` resolves the destination label so renamed tabs read correctly.
    func statusText(name: (Bucket) -> String) -> String {
        switch self {
        case let .moved(_, title, destination, _, _, _): "\(title) → \(name(destination))"
        case let .deleted(snapshot): "\(snapshot.title) deleted"
        }
    }
}

// MARK: - Store

@Observable @MainActor
final class TaskStore {
    @ObservationIgnored private let context: ModelContext
    /// AUTOUPDATING, so the store follows the device across a time zone.
    /// `Calendar.current` is a snapshot: captured once into a `let` on an
    /// object that lives for the whole process, it froze the departure zone.
    /// Flying Berlin → New York then left the rollover pass computing "today"
    /// in Berlin, marking a whole evening's tasks overdue and PERSISTING the
    /// reshuffle via `overduePlaced`, which is a one-way latch (found in
    /// review 2026-08-26).
    @ObservationIgnored let calendar = Calendar.autoupdatingCurrent
    /// Injectable clock — the one place real time enters the system.
    @ObservationIgnored var now: () -> Date = { .now }

    /// Bumped on every mutation, and by the remote-change observer below, so
    /// query methods re-render for a sync as well as for a local edit.
    private(set) var revision = 0

    /// Watches for changes CloudKit imported behind our back.
    @ObservationIgnored private var remoteChangeObserver: (any NSObjectProtocol)?

    /// Single-level undo (PRD FR-009). The panel that surfaces it retires
    /// itself on a timer — it reports a change, it is not standing chrome.
    private(set) var lastAction: LastAction?

    /// Retires the status panel without undoing anything.
    func dismissLastAction() {
        lastAction = nil
    }

    /// The active workspace. nil = the default workspace (and every task
    /// created before workspaces existed). RootView keeps this in sync with
    /// AppSettings; every query below is scoped to it, so switching workspace
    /// swaps the entire visible world in one assignment.
    /// Guarded against no-op writes. `workspaces()` reads `revision`, and
    /// RootView re-syncs the scope whenever `revision` changes — so a setter
    /// that bumped unconditionally span the update loop until the UI rendered
    /// nothing at all (2026-08-04).
    var workspaceID: String? {
        didSet { if workspaceID != oldValue { revision += 1 } }
    }

    /// Workspace ids this device knows about, so unknown ones can be shown in
    /// the default workspace rather than vanishing. Kept in sync by RootView.
    var knownWorkspaceIDs: Set<String> = [] {
        didSet { if knownWorkspaceIDs != oldValue { revision += 1 } }
    }

    init(context: ModelContext) {
        self.context = context
        observeRemoteChanges()
    }

    deinit {
        if let remoteChangeObserver {
            NotificationCenter.default.removeObserver(remoteChangeObserver)
        }
    }

    /// The observer the comment on `revision` had promised for a while and
    /// that did not actually exist (found in review 2026-08-26).
    ///
    /// Every read in the app goes through this store and is gated on
    /// `revision` — there is no `@Query` anywhere — so an import that no one
    /// announces is invisible. A task added on another device landed in the
    /// local store and simply did not appear until something else forced a
    /// re-render, which made sync look broken on the very screen it serves.
    private func observeRemoteChanges() {
        remoteChangeObserver = NotificationCenter.default.addObserver(
            forName: .NSPersistentStoreRemoteChange,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            // The notification arrives off the main actor's knowledge even
            // when delivered on the main queue, so the hop is explicit.
            Task { @MainActor [weak self] in
                guard let self else { return }
                // The context has to be told to pick the changes up before
                // anything re-queries, or the re-render reads the old graph.
                self.context.processPendingChanges()
                self.revision &+= 1
            }
        }
    }

    // MARK: Workspaces (synced records — see Workspace.swift)

    /// Deduped by id: the store cannot enforce uniqueness under CloudKit, and
    /// two devices seeding the same fixed ids independently would otherwise
    /// show "Personal" twice. Oldest record wins so the pick is stable.
    func workspaces() -> [Workspace] {
        _ = revision
        let all = (try? context.fetch(FetchDescriptor<Workspace>())) ?? []
        var byID: [String: Workspace] = [:]
        for workspace in all {
            if let existing = byID[workspace.id], existing.createdAt <= workspace.createdAt {
                continue
            }
            byID[workspace.id] = workspace
        }
        // Default first, then oldest to newest.
        let unique = byID.values.sorted {
            if $0.isDefault != $1.isDefault { return $0.isDefault }
            return $0.createdAt < $1.createdAt
        }

        // ...and then deduped by NAME as well (founder bug report 2026-08-16:
        // "Work" appeared twice on the phone).
        //
        // Deduping by id alone cannot catch this. Two records with the SAME
        // name and DIFFERENT ids are exactly what the legacy migration
        // produces: a device that had workspaces in preferences creates "Work"
        // with a generated id, while a device seeding fresh creates it with
        // the fixed `Workspace.workID`. CloudKit then delivers both, and the
        // id-dedup above sees two legitimately distinct records.
        //
        // Oldest wins, matching the id rule, so every device converges on the
        // same survivor. The loser's tasks fall back to the default workspace
        // for display via the existing unknown-id path in `allTasksSorted` —
        // they are not lost, and nothing is written, so a real merge (or an
        // undo) is still possible later.
        var seenNames = Set<String>()
        return unique.filter { workspace in
            let key = workspace.name.trimmingCharacters(in: .whitespaces).lowercased()
            guard !key.isEmpty else { return true }
            return seenNames.insert(key).inserted
        }
    }

    func workspace(withID id: String) -> Workspace? {
        workspaces().first { $0.id == id }
    }

    /// First run: Personal + Work, with FIXED ids so a second device converges
    /// on the same two rather than adding its own pair. `legacy` carries any
    /// workspaces this device had in preferences before they were records, so
    /// existing task assignments survive the change.
    func seedWorkspacesIfNeeded(legacy: [(id: String, name: String)]) {
        guard workspaces().isEmpty else { return }
        var seeded: [(String, String)] = [(Workspace.defaultID, "Personal")]
        if legacy.isEmpty {
            seeded.append((Workspace.workID, "Work"))
        } else {
            // Preserve the ids tasks are already stamped with.
            for entry in legacy where entry.id != Workspace.defaultID {
                seeded.append((entry.id, entry.name))
            }
            if let defaultName = legacy.first(where: { $0.id == Workspace.defaultID })?.name {
                seeded[0].1 = defaultName
            }
        }
        for (id, name) in seeded {
            context.insert(Workspace(id: id, name: name))
        }
        commit()
    }

    /// The key `workspaces()` dedupes on. Anything that WRITES a name has to
    /// ask this first, or it writes a record the list will then hide —
    /// which is how Add came to look like a dead button and Rename came to
    /// look like a delete (founder decision 2026-08-16: forbid duplicates
    /// outright rather than hide them).
    private func nameKey(_ raw: String) -> String {
        raw.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    /// True when some OTHER workspace already answers to this name.
    ///
    /// Checked against every record, not just the deduped list: a legacy
    /// twin that dedup is currently hiding still owns its name, and letting
    /// a third record land on it would only deepen the pile.
    func workspaceNameIsTaken(_ raw: String, excluding workspace: Workspace? = nil) -> Bool {
        let key = nameKey(raw)
        guard !key.isEmpty else { return false }
        let all = (try? context.fetch(FetchDescriptor<Workspace>())) ?? []
        return all.contains { nameKey($0.name) == key && $0.id != workspace?.id }
    }

    /// Returns nil when the name is empty or already taken — the caller is
    /// expected to leave the typed text in place rather than clear a field
    /// whose contents were never accepted.
    @discardableResult
    func addWorkspace(named raw: String) -> Workspace? {
        // Bounded like tab names: a workspace name rides in the home
        // screen's pill, and an unbounded one carried the settings gear off
        // the edge (founder bug report 2026-08-17).
        let name = String(raw.trimmingCharacters(in: .whitespacesAndNewlines)
            .prefix(AppSettings.maxNameLength))
        guard !name.isEmpty, !workspaceNameIsTaken(name) else { return nil }
        let workspace = Workspace(id: UUID().uuidString, name: name)
        context.insert(workspace)
        commit()
        return workspace
    }

    /// False when the rename was refused, so the caller can put the field
    /// back to the name that is still in force.
    @discardableResult
    func renameWorkspace(_ workspace: Workspace, to raw: String) -> Bool {
        // Bounded like tab names: a workspace name rides in the home
        // screen's pill, and an unbounded one carried the settings gear off
        // the edge (founder bug report 2026-08-17).
        let name = String(raw.trimmingCharacters(in: .whitespacesAndNewlines)
            .prefix(AppSettings.maxNameLength))
        guard !name.isEmpty, name != workspace.name else { return false }
        guard !workspaceNameIsTaken(name, excluding: workspace) else { return false }
        workspace.name = name
        commit()
        return true
    }

    /// The default is undeletable; a deleted workspace's tasks fold back into
    /// it rather than being destroyed — deleting a label must never delete work.
    func deleteWorkspace(_ workspace: Workspace) {
        guard !workspace.isDefault, let stamp = workspace.taskStampID else { return }
        for task in (try? context.fetch(FetchDescriptor<TaskItem>())) ?? []
        where task.workspaceID == stamp {
            task.workspaceID = nil
        }
        context.delete(workspace)
        commit()
    }

    // MARK: Queries

    private func allTasksSorted() -> [TaskItem] {
        // createdAt is the deterministic tie-breaker: legacy data written before
        // the 2026-08-04 collision fix can hold equal sortOrders, and midpoint
        // math can in principle land on a completed task's order.
        let descriptor = FetchDescriptor<TaskItem>(
            sortBy: [SortDescriptor(\.sortOrder), SortDescriptor(\.createdAt)])
        let all = (try? context.fetch(descriptor)) ?? []
        // Workspace scoping happens HERE, the one choke point every query uses,
        // so buckets, archive, placement and rollover are all scoped for free.
        //
        // A task whose workspace this device doesn't know about falls back to
        // the DEFAULT workspace for display only — its record is never
        // rewritten. That matters under sync: workspaces are still per-device
        // preferences, so a task arriving from another device carries an id
        // this one has never seen, and "fixing" the record would push the
        // damage back to the device it came from.
        return all.filter { task in
            if task.workspaceID == workspaceID { return true }
            guard workspaceID == nil, let id = task.workspaceID else { return false }
            return !knownWorkspaceIDs.contains(id)
        }
    }

    /// Every task currently mapping to the bucket — completed included.
    /// Bottom-anchor placements must clear completed tasks' kept sortOrders,
    /// or unticking loses its position (bug report 2026-08-04).
    private func allInBucket(_ bucket: Bucket) -> [TaskItem] {
        let now = now()
        return allTasksSorted().filter { $0.bucket(now: now, calendar: calendar) == bucket }
    }

    /// Look up a live task by id — used by the menu overlay, which holds an
    /// id rather than a model reference so it can't go stale.
    func task(withID id: UUID) -> TaskItem? {
        allTasksSorted().first { $0.id == id }
    }

    /// The same lookup, unscoped: across every workspace, pinned or not.
    ///
    /// The Lock Screen's tick button carries the id of the task ITS CARD was
    /// drawn for. Resolving that through `pinnedTask()` and comparing ids
    /// looked equivalent and is not: a card outlives the state it was drawn
    /// from, so pinning something else on another device — or two devices
    /// each pinning offline, where the fetch returns an arbitrary one of the
    /// two — made the guard fall through and the tap vanish with no signal.
    /// The card names its own task; honour that.
    func anyTask(withID id: UUID) -> TaskItem? {
        _ = revision // observation hook
        var descriptor = FetchDescriptor<TaskItem>(predicate: #Predicate { $0.id == id })
        descriptor.fetchLimit = 1
        return (try? context.fetch(descriptor))?.first
    }

    /// A tab's visible tasks: active (by sortOrder) and completed-not-archived
    /// (by completion time). Completed keep their sortOrder untouched, so
    /// unticking returns a task to its exact former spot (locked Q11).
    func tasks(in bucket: Bucket) -> (active: [TaskItem], completed: [TaskItem]) {
        _ = revision // observation hook
        let now = now()
        let visible = allTasksSorted().filter { $0.isVisible(in: bucket, now: now, calendar: calendar) }
        let active = visible.filter { !$0.isCompleted }
        let completed = visible.filter(\.isCompleted)
            .sorted { ($0.completedAt ?? .distantPast) < ($1.completedAt ?? .distantPast) }
        return (active, completed)
    }

    /// The two counts the first-run walkthrough watches, in ONE pass.
    ///
    /// It used to ask `tasks(in:)` once per bucket, which is three fetches and
    /// three sorts of the whole table to produce two integers. Same semantics:
    /// `all` counts active tasks visible in any of the three tabs, so the live
    /// note — which is in no tab — is left out of both, exactly as summing the
    /// three buckets did.
    func activeTally() -> (all: Int, today: Int) {
        let now = now()
        var all = 0
        var today = 0
        for task in allTasksSorted() where !task.isCompleted {
            if task.isVisible(in: .today, now: now, calendar: calendar) {
                today += 1
                all += 1
            } else if task.isVisible(in: .tomorrow, now: now, calendar: calendar)
                        || task.isVisible(in: .general, now: now, calendar: calendar) {
                all += 1
            }
        }
        return (all, today)
    }

    /// Schedules a task for a given day — the calendar button in Soon.
    ///
    /// Records undo like any other move, because that is what it is: the
    /// task's date changes and it may leave the tab entirely. Choosing today
    /// or tomorrow is allowed and simply sends it there (founder direction
    /// 2026-08-17); the date line decides which tab holds it, as it does for
    /// everything else.
    /// `recordingUndo: false` is for a task that is being BORN with a date —
    /// the add row under a day stamps its section on what it creates, and that
    /// is one act of writing, not a move. Reported as a move it produced an
    /// "X → Soon" undo bar on every single add, for a task that had never been
    /// anywhere else (founder direction 2026-08-17).
    func schedule(_ task: TaskItem, on day: Date, recordingUndo: Bool = true) {
        let target = calendar.startOfDay(for: day)
        let destination = DateEngine.bucket(for: target, now: now(), calendar: calendar)
        let destinationActive = tasks(in: destination).active.filter { $0 !== task }
        let destinationAll = allInBucket(destination).filter { $0 !== task }
        if recordingUndo {
            lastAction = .moved(
                taskID: task.id, title: task.title, to: destination,
                previousDueDate: task.dueDate, previousSortOrder: task.sortOrder,
                previousOverduePlaced: task.overduePlaced)
        }
        task.dueDate = target
        task.overduePlaced = false
        task.sortOrder = Placement.sortOrderForArrival(
            isImportant: task.isImportant, visible: destinationActive, allInBucket: destinationAll)
        commit()
    }

    /// One block of Soon: a heading, the tasks under it, and the ones ticked
    /// off there.
    ///
    /// `day` is nil for General — the same convention the add rows and the
    /// collapse state already use, so a section is identified one way
    /// throughout the app.
    struct SoonSection: Identifiable {
        let day: Date?
        let active: [TaskItem]
        let completed: [TaskItem]
        var id: Date? { day }
    }

    /// Soon, in the shape that tab draws: General first, then one block per
    /// scheduled day, oldest day first.
    ///
    /// Completed tasks belong to their OWN block. They used to be returned as
    /// one run for the foot of the whole list, so ticking something off under
    /// Wednesday sent it below the last day on screen — away from the day it
    /// belongs to, and past every heading in between (founder direction
    /// 2026-08-17). A task that is done is still a task of that day.
    ///
    /// There can never be a day before the day after tomorrow — anything
    /// earlier is in Today or Tomorrow by definition, which is why this needs
    /// no notion of an overdue section.
    ///
    /// Manual order survives inside each block: `tasks(in:)` already returns
    /// them sorted, and grouping preserves that within a day.
    func soonSections() -> [SoonSection] {
        let (active, completed) = tasks(in: .general)
        let day = { (task: TaskItem) -> Date? in
            task.dueDate.map { self.calendar.startOfDay(for: $0) }
        }

        let activeByDay = Dictionary(grouping: active, by: day)
        let completedByDay = Dictionary(grouping: completed, by: day)

        // Every day either side has to appear, or a block holding nothing but
        // ticked-off tasks would vanish along with them.
        let days = Set(activeByDay.keys).union(completedByDay.keys)
            .compactMap { $0 }
            .sorted()

        let general = SoonSection(day: nil,
                                  active: activeByDay[nil] ?? [],
                                  completed: completedByDay[nil] ?? [])
        return [general] + days.map { day in
            SoonSection(day: day,
                        active: activeByDay[day] ?? [],
                        completed: completedByDay[day] ?? [])
        }
    }

    /// Archive: completed tasks past their visibility window, grouped by
    /// completion day, newest day first (PRD § UI/UX > Archive).
    func archivedTasksByDay() -> [(day: Date, tasks: [TaskItem])] {
        _ = revision
        let now = now()
        let archived = allTasksSorted().filter { $0.isArchived(now: now, calendar: calendar) }
        let grouped = Dictionary(grouping: archived) { task in
            calendar.startOfDay(for: task.completedAt ?? task.createdAt)
        }
        return grouped
            .map { (day: $0.key, tasks: $0.value.sorted { ($0.completedAt ?? .distantPast) > ($1.completedAt ?? .distantPast) }) }
            .sorted { $0.day > $1.day }
    }

    // MARK: Photos (Phase 4, pulled forward 2026-08-04)

    /// Appends — photos accumulate left to right in the order added.
    func addPhoto(_ task: TaskItem, data: Data?) {
        guard let data else { return }
        insertPhoto(data, into: task, order: task.nextPhotoOrder)
        commit()
    }

    /// Removes one photo by its position in the strip. Orders are sparse on
    /// purpose — nothing is renumbered, so a removal can't disturb the rest.
    func removePhoto(_ task: TaskItem, at index: Int) {
        let ordered = task.orderedPhotos
        guard ordered.indices.contains(index) else { return }
        context.delete(ordered[index])
        commit()
    }

    private func insertPhoto(_ data: Data, into task: TaskItem, order: Int) {
        let photo = TaskPhoto()
        photo.data = data
        photo.order = order
        photo.task = task
        context.insert(photo)
    }

    /// One-time move of photos out of the pre-CloudKit fields and into their
    /// own records. Idempotent: a task is only touched while it still holds
    /// legacy data, and the slots are cleared as it goes.
    func migrateLegacyPhotos() {
        let descriptor = FetchDescriptor<TaskItem>()
        var moved = false
        for task in (try? context.fetch(descriptor)) ?? [] where task.needsPhotoMigration {
            var order = task.nextPhotoOrder
            for data in task.legacyPhotos {
                insertPhoto(data, into: task, order: order)
                order += 1
            }
            task.clearLegacyPhotos()
            moved = true
        }
        if moved { commit() }
    }

    // MARK: Mutations

    /// Creates in the given bucket with bottom placement. Whitespace-only
    /// titles are a no-op; pasted newlines collapse to spaces (PRD edge table).
    @discardableResult
    func addTask(title raw: String, in bucket: Bucket) -> TaskItem? {
        let title = raw
            .replacingOccurrences(of: "\n", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty else { return nil }

        let task = TaskItem()
        task.title = title
        task.workspaceID = workspaceID // born into the active workspace
        task.dueDate = DateEngine.targetDate(for: bucket, now: now(), calendar: calendar)
        task.sortOrder = Placement.sortOrderForNewTask(allInBucket: allInBucket(bucket))
        context.insert(task)
        commit()
        return task
    }

    /// Empty result reverts (delete is the menu's job — PRD FR-007).
    func editTitle(_ task: TaskItem, to raw: String) {
        let title = raw
            .replacingOccurrences(of: "\n", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty else { return }
        let changed = title != task.title
        task.title = title
        // An overdue task whose text was actually rewritten is a NEW task in
        // spirit — it re-dates to today and the overdue chip disappears
        // (founder request 2026-08-04). Tapping in and out without changing
        // anything keeps the chip.
        if changed, let due = task.dueDate,
           due < calendar.startOfDay(for: now()) {
            task.dueDate = calendar.startOfDay(for: now())
            task.overduePlaced = false
        }
        commit()
    }

    /// One step along the line. Returns nil at a dead end — caller rubber-bands.
    @discardableResult
    func step(_ task: TaskItem, direction: StepDirection) -> Bucket? {
        let current = task.bucket(now: now(), calendar: calendar)
        guard let destination = current.steppedOnce(direction) else { return nil }
        move(task, to: destination)
        return destination
    }

    /// Direct move (swipe commit or context menu). Records undo, applies
    /// arrival placement (important → under the destination's important block).
    func move(_ task: TaskItem, to bucket: Bucket) {
        let destinationActive = tasks(in: bucket).active.filter { $0 !== task }
        let destinationAll = allInBucket(bucket).filter { $0 !== task }
        lastAction = .moved(
            taskID: task.id, title: task.title, to: bucket,
            previousDueDate: task.dueDate, previousSortOrder: task.sortOrder,
            previousOverduePlaced: task.overduePlaced)
        task.dueDate = DateEngine.targetDate(for: bucket, now: now(), calendar: calendar)
        task.overduePlaced = false // dueDate changed → eligible for future rollover placement
        task.sortOrder = Placement.sortOrderForArrival(
            isImportant: task.isImportant, visible: destinationActive, allInBucket: destinationAll)
        commit()
    }

    /// Tick/untick. Never touches sortOrder — the completed section renders
    /// separately, so unticking restores the exact prior position.
    func toggleCompleted(_ task: TaskItem) {
        task.isCompleted.toggle()
        task.completedAt = task.isCompleted ? now() : nil
        // A finished task stops following you. Unticking does NOT re-pin it —
        // pinning is a deliberate act, and silently re-pinning something you
        // un-ticked by accident would put it back on the Lock Screen.
        if task.isCompleted { task.isPinned = false }
        commit()
    }

    // MARK: - The pinned task (mononote)

    /// The one task pinned to the Lock Screen, or nil.
    ///
    /// Searched WITHOUT the workspace filter that `allTasksSorted` applies:
    /// the pin is app-wide, so a task pinned in Work must still be found
    /// while Personal is open — otherwise switching workspace would look
    /// like the pin had been lost, and pinning again would leave two.
    func pinnedTask() -> TaskItem? {
        _ = revision // observation hook
        var descriptor = FetchDescriptor<TaskItem>(
            predicate: #Predicate { $0.isPinned })
        descriptor.fetchLimit = 1
        return (try? context.fetch(descriptor))?.first
    }

    /// Pins `task`, releasing whatever held the pin.
    ///
    /// Exactly one, app-wide. The unpin loop is defensive rather than
    /// decorative: two devices can each pin a different task offline, and
    /// sync then delivers a store with two. Whoever pins next cleans it up.
    func pin(_ task: TaskItem) {
        let descriptor = FetchDescriptor<TaskItem>(predicate: #Predicate { $0.isPinned })
        for held in (try? context.fetch(descriptor)) ?? [] where held.id != task.id {
            held.isPinned = false
        }
        task.isPinned = true
        commit()
    }

    func unpin(_ task: TaskItem) {
        guard task.isPinned else { return }
        task.isPinned = false
        commit()
    }

    // MARK: - The live note

    /// The one note in the Live section, if there is one.
    ///
    /// App-wide, like the pin it replaces: the question it answers is "what is
    /// the one thing right now", and that is not a per-workspace question
    /// (founder direction 2026-08-17).
    func liveNote() -> TaskItem? {
        _ = revision // observation hook
        var descriptor = FetchDescriptor<TaskItem>(
            predicate: #Predicate { $0.isLiveNote && !$0.isCompleted })
        descriptor.fetchLimit = 1
        return (try? context.fetch(descriptor))?.first
    }

    /// Writes the live note, replacing whatever was there.
    ///
    /// Created straight into the live state: the founder's flow is to type it
    /// and have it go, so there is no separate step that puts it on the Lock
    /// Screen afterwards.
    @discardableResult
    func setLiveNote(_ raw: String) -> TaskItem? {
        let title = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty else { return nil }
        clearLiveNote()
        let task = TaskItem()
        task.title = title
        task.isLiveNote = true
        task.isPinned = true
        task.workspaceID = workspaceID
        context.insert(task)
        commit()
        return task
    }

    /// Writes the box: renames the note that is there, or makes one.
    ///
    /// Renaming rather than replacing matters — the note keeps its identity,
    /// so editing the text does not knock it off the Lock Screen and back on
    /// (founder direction 2026-08-17).
    @discardableResult
    func writeLiveNote(_ raw: String) -> TaskItem? {
        let title = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty else { return nil }
        if let note = liveNote() {
            guard note.title != title else { return note }
            note.title = title
            commit()
            return note
        }
        return setLiveNote(title)
    }

    /// Removes the live note entirely — the bin in the Live section.
    ///
    /// `!isCompleted` matters as much here as it does in `liveNote()`, and for
    /// the same reason: a live note that has been ticked off is an ARCHIVE
    /// record, not the live note. Without the clause this deleted every live
    /// note the archive had ever kept, so writing a new one silently destroyed
    /// the history of the old ones (found in review 2026-08-26).
    func clearLiveNote() {
        let descriptor = FetchDescriptor<TaskItem>(
            predicate: #Predicate { $0.isLiveNote && !$0.isCompleted })
        for note in (try? context.fetch(descriptor)) ?? [] {
            context.delete(note)
        }
        commit()
    }

    /// Sends an existing task to the Live section.
    ///
    /// Whatever held Live is DELETED, not returned to a list (founder
    /// direction 2026-08-17, revising the first answer). Handing it back to
    /// Today or General meant that replacing one thing quietly produced
    /// another somewhere else — you went to Live to change what you were
    /// doing and came away with an extra task you never asked for.
    ///
    /// Deletion here is not final: `delete(_:)` writes the undo snapshot, so
    /// the bar offers it back for the few seconds anyone would notice.
    func makeLive(_ task: TaskItem) {
        // `!isCompleted` for the reason given on `clearLiveNote` — archived
        // live notes are not the incumbent and must not be swept up here.
        let descriptor = FetchDescriptor<TaskItem>(
            predicate: #Predicate { $0.isLiveNote && !$0.isCompleted })
        for held in (try? context.fetch(descriptor)) ?? [] where held.id != task.id {
            delete(held)
        }
        task.isLiveNote = true
        task.isPinned = true
        commit()
    }

    /// The Lock Screen switch, and ONLY that.
    ///
    /// Off leaves the text sitting in its box; the note is still the live note
    /// and comes straight back when the switch goes on again (founder
    /// direction 2026-08-17). Deleting it is the bin's job, not this one's.
    func setLiveOnLockScreen(_ on: Bool) {
        guard let note = liveNote() else { return }
        note.isPinned = on
        commit()
    }

    /// Flagging jumps to the very top of the current tab; unflagging leaves
    /// the task exactly where it is (locked Q17).
    func toggleImportant(_ task: TaskItem) {
        if task.isImportant {
            task.isImportant = false
        } else {
            let bucket = task.bucket(now: now(), calendar: calendar)
            task.sortOrder = Placement.sortOrderForFlagImportant(visible: tasks(in: bucket).active)
            task.isImportant = true
        }
        commit()
    }

    /// Immediate delete — no confirmation dialogs, ever (locked Q11). The
    /// status bar's persistent Undo is the safety net.
    func delete(_ task: TaskItem) {
        lastAction = .deleted(snapshot: TaskSnapshot(
            title: task.title, dueDate: task.dueDate, isImportant: task.isImportant,
            isCompleted: task.isCompleted, completedAt: task.completedAt,
            createdAt: task.createdAt, sortOrder: task.sortOrder,
            overduePlaced: task.overduePlaced, workspaceID: task.workspaceID,
            isLiveNote: task.isLiveNote, isPinned: task.isPinned,
            photos: task.allPhotos))
        context.delete(task)
        commit()
    }

    /// Drag-reorder by the row's grip (TASK-025, restored 2026-08-23).
    ///
    /// The task is placed BETWEEN its two new neighbours and nothing else is
    /// touched — one write, whatever the list is worth in length. Free
    /// placement: the user's order is theirs afterwards (locked Q17-B).
    ///
    /// Midpoints halve the gap every time, so a run of drops into the same
    /// crack eventually lands on two orders that no longer differ. That is
    /// what `needsRenormalization` watches for, and the whole list is spread
    /// out again on the rare pass where it says so.
    ///
    /// This is the function whose doc comment sat stranded above
    /// `undoLastAction` from 2026-08-04, when the drag was cut for competing
    /// with the row's other three gestures, until 2026-08-23 gave it a grip of
    /// its own.
    func reorder(_ task: TaskItem, between above: TaskItem?, and below: TaskItem?,
                 visible: [TaskItem]) {
        task.sortOrder = Placement.sortOrder(between: above?.sortOrder,
                                             and: below?.sortOrder)
        let settled = visible.sorted { $0.sortOrder < $1.sortOrder }
        if Placement.needsRenormalization(visible: settled) {
            for (task, order) in Placement.renormalized(visible: settled) {
                task.sortOrder = order
            }
        }
        commit()
    }

    func undoLastAction() {
        switch lastAction {
        case let .moved(taskID, _, _, previousDueDate, previousSortOrder, previousOverduePlaced):
            if let task = allTasksSorted().first(where: { $0.id == taskID }) {
                task.dueDate = previousDueDate
                task.sortOrder = previousSortOrder
                task.overduePlaced = previousOverduePlaced
            }
        case let .deleted(snapshot):
            let task = TaskItem()
            task.title = snapshot.title
            task.dueDate = snapshot.dueDate
            task.isImportant = snapshot.isImportant
            task.isCompleted = snapshot.isCompleted
            task.completedAt = snapshot.completedAt
            task.createdAt = snapshot.createdAt
            task.sortOrder = snapshot.sortOrder
            task.overduePlaced = snapshot.overduePlaced
            task.workspaceID = snapshot.workspaceID
            task.isPinned = snapshot.isPinned
            // Live is a SINGLE seat. If something else took it while the undo
            // bar was still up, the restored note comes back as an ordinary
            // task rather than fighting the incumbent for the Lock Screen.
            task.isLiveNote = snapshot.isLiveNote && liveNote() == nil
            for (index, data) in snapshot.photos.enumerated() {
                insertPhoto(data, into: task, order: index)
            }
            context.insert(task)
        case nil:
            return
        }
        lastAction = nil
        commit()
    }

    /// Day-rollover placement pass (PRD §3). Runs on app-active and
    /// significant-time-change. Idempotent: the `overduePlaced` flag guards
    /// every task, so re-running is free and dragged tasks are never touched.
    ///
    /// `timeRules` is Today's own switch (see `AppSettings.timeRulesEnabled`).
    /// Off, the pass does not run at all: nothing rolls over, nothing is
    /// marked overdue, and a task stays where it was put.
    func runDayRolloverPassIfNeeded(timeRules: Bool = true) {
        guard timeRules else { return }
        let now = now()
        let visibleToday = tasks(in: .today).active
        for (task, order) in Placement.rolloverPlacements(visibleToday: visibleToday, now: now, calendar: calendar) {
            task.sortOrder = order
        }
        // Mark every newly-overdue task placed (importants included — they
        // already sit in the top tier by their own placement).
        for task in visibleToday where task.isOverdue(now: now, calendar: calendar) && !task.overduePlaced {
            task.overduePlaced = true
        }
        commit()
    }

    // MARK: - Debug seeding

    #if DEBUG
    /// Sample data covering every tier: important, overdue, today, tomorrow,
    /// week, general (TASK-015 verify).
    func seedDebugData() {
        let now = now()
        func make(_ title: String, bucket: Bucket, important: Bool = false, daysAgo: Int? = nil) {
            let task = TaskItem()
            task.title = title
            if let daysAgo {
                task.dueDate = calendar.date(byAdding: .day, value: -daysAgo,
                                             to: DateEngine.startOfToday(now: now, calendar: calendar))
            } else {
                task.dueDate = DateEngine.targetDate(for: bucket, now: now, calendar: calendar)
            }
            task.isImportant = important
            task.sortOrder = Placement.sortOrderForNewTask(allInBucket: allInBucket(bucket))
            if important {
                task.sortOrder = Placement.sortOrderForFlagImportant(visible: tasks(in: bucket).active)
            }
            context.insert(task)
            try? context.save()
        }
        make("Ship the shell", bucket: .today, important: true)
        make("Repair bike", bucket: .today)
        make("From yesterday", bucket: .today, daysAgo: 1)
        make("From last week", bucket: .today, daysAgo: 8)
        make("Call dentist", bucket: .tomorrow)
        // Dated four days out: General by tab now, still dated, still chipped.
        make("File taxes", bucket: .general, daysAgo: -4)
        make("Build portfolio", bucket: .general)
        revision += 1
    }

    /// 15 filler rows in Today — enough height to exercise scrolling
    /// against the row pan (TASK-019 spike verification).
    /// `-seedDemo YES` fills the store with the App Store screenshot content.
    /// Deliberately mundane: a to-do list in a screenshot should look like
    /// somebody's actual Tuesday, not a product diagram where every row is the
    /// same length and nothing is late.
    func seedDemo() {
        let today = DateEngine.startOfToday(now: now(), calendar: calendar)
        let tomorrow = DateEngine.startOfTomorrow(now: now(), calendar: calendar)
        // Four days out — General by tab, but it keeps its day.
        let week = calendar.date(byAdding: .day, value: 4, to: today)
        // Two months out, so Soon shows a second dated group well clear of the
        // first — the founder's "Tax return" row.
        let farOff = calendar.date(byAdding: .day, value: 60, to: today)

        // (title, due, important, completed, photos, order)
        //
        // TRANSCRIBED FROM THE FOUNDER'S OWN LIST, read out of the simulator's
        // store rather than off a screenshot (2026-09-01) — titles,
        // capitalisation, dates, flags, photo count and sort order exactly as
        // they stood. Nothing here is tidied: not the lower-case first words,
        // not the two ticked-off rows, not the empty photo slot on the bike
        // light. A previous pass "helpfully" restored a row the founder had
        // deleted and corrected a title, which is the opposite of what a
        // screenshot seed is for. This list is theirs; leave it alone.
        let rows: [(String, Date?, Bool, Bool, [Data], Double)] = [
            ("call back dentist",                  today,    true,  false, [DemoPhotos.dentistMap()],   0),
            ("fix bike light",                     today,    true,  false, [],                          1),
            ("pick up parcel",                     today,    false, false, [DemoPhotos.parcelLabel()],  1.5),
            ("organize trip to Asia",              today,    false, false, [],                          2),
            ("water the plants",                   today,    false, true,  [],                          5),
            ("book train to Hamburg",              today,    true,  true,  [],                          6),
            ("Prepare presentation for work",      tomorrow, false, false, [],                          6),
            ("Send Marie vacation photos",         tomorrow, false, false, [],                          7),
            ("Renew public transport subscription", tomorrow, false, false, [],                         8),
            ("Dentist follow-up",                  week,     false, false, [],                          9),
            ("Return desk lamp",                   nil,      false, false, [],                         11),
            ("Send out job applications",          nil,      false, false, [],                         12),
            ("Organize exchange semester",         nil,      false, false, [],                         14),
            ("Tax return",                         farOff,   false, false, [],                         15),
        ]

        // The WORK workspace gets its own list (founder direction 2026-09-01).
        // Screenshots that show the workspace switcher want something behind
        // the second name — an empty list there says the feature is a promise
        // rather than a place. No photos: work tasks are words, and the photo
        // story is already told in Personal.
        let workRows: [(String, Date?, Bool, Double)] = [
            ("send the invoice",             today,    true,  0),
            ("review the pull request",      today,    false, 1),
            ("write standup notes",          today,    false, 2),
            ("book the meeting room",        tomorrow, false, 3),
            ("reply to the recruiter",       tomorrow, false, 4),
            ("prep the quarterly numbers",   week,     true,  5),
            ("update the team handbook",     nil,      false, 6),
            ("chase the signed contract",    nil,      false, 7),
        ]
        for (title, due, important, order) in workRows {
            let task = TaskItem()
            task.title = title
            task.dueDate = due
            task.isImportant = important
            task.workspaceID = Workspace.workID
            task.sortOrder = order
            context.insert(task)
        }

        for (title, due, important, completed, photos, order) in rows {
            let task = TaskItem()
            task.title = title
            task.dueDate = due
            task.isImportant = important
            task.workspaceID = workspaceID
            task.sortOrder = order
            if completed {
                task.isCompleted = true
                task.completedAt = now()
            }
            context.insert(task)
            for photo in photos { addPhoto(task, data: photo) }
        }
        commit()
    }

    func seedScrollFillers() {
        for i in 1...40 {
            let task = TaskItem()
            task.title = "Filler \(i)"
            task.dueDate = DateEngine.startOfToday(now: now(), calendar: calendar)
            task.sortOrder = Placement.sortOrderForNewTask(allInBucket: allInBucket(.today))
            context.insert(task)
            try? context.save()
        }
        revision += 1
    }

    /// Fillers SPREAD across the next three weeks, so Soon has many day
    /// sections rather than one long block.
    ///
    /// The list's length is what makes a handed-over edit hard to follow: a
    /// task sent from General to a day near the bottom lands off-screen, and
    /// a two-section list cannot show that. Added for the 2026-08-22 report.
    func seedSoonSpread() {
        let today = DateEngine.startOfToday(now: now(), calendar: calendar)
        for day in 2...20 {
            guard let date = calendar.date(byAdding: .day, value: day, to: today) else { continue }
            for i in 1...2 {
                let task = TaskItem()
                task.title = "Tag \(day) – \(i)"
                task.dueDate = date
                task.sortOrder = Placement.sortOrderForNewTask(allInBucket: allInBucket(.general))
                context.insert(task)
            }
        }
        try? context.save()
        revision += 1
    }

    /// Tasks already in the ARCHIVE, spread over several past days.
    ///
    /// Nothing reaches the archive without the clock moving — a dated task
    /// archives once its completion is yesterday — so there was no way to look
    /// at that screen with anything on it. Added for the 2026-08-23 rebuild of
    /// it.
    func seedArchive() {
        let today = DateEngine.startOfToday(now: now(), calendar: calendar)
        // Queries are scoped by the workspace's stamp, so the tasks are born
        // into whichever one is on screen. See the caller: it waits for the
        // scope to be synced, because a task seeded before that has no
        // workspace and is filtered straight back out.
        let home = workspaceID
        for back in 1...3 {
            guard let day = calendar.date(byAdding: .day, value: -back, to: today) else { continue }
            for i in 1...3 {
                let task = TaskItem()
                task.title = "Erledigt vor \(back) Tagen – \(i)"
                // Queries are workspace-scoped, and this runs before the
                // scope has been synced — so the default is stated rather
                // than inherited from a store that does not know yet.
                task.workspaceID = home
                task.dueDate = day
                task.isCompleted = true
                task.completedAt = calendar.date(byAdding: .hour, value: 10 + i, to: day)
                task.sortOrder = Double(i)
                context.insert(task)
            }
        }
        try? context.save()
        revision += 1
    }
    #endif

    // MARK: - Private

    private func commit() {
        try? context.save()
        revision += 1
    }
}
