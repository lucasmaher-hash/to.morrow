import Foundation
import Shove95Kit

@MainActor enum MacTaskActions {
    /// Reindex only the destination section. Fractional insertion cannot distinguish
    /// tied values (or adjacent floating-point values) after repeated drags.
    static func reorder(_ task: TaskItem, before target: TaskItem, tasks: [TaskItem], settings: MacSettings) {
        let workspace = target.workspaceID ?? Workspace.defaultID
        let bucket = settings.bucket(for: target)
        var section = tasks.enumerated().filter {
            $0.element.id != task.id &&
            ($0.element.workspaceID ?? Workspace.defaultID) == workspace &&
            settings.visible($0.element, in: bucket)
        }.sorted {
            $0.element.sortOrder == $1.element.sortOrder
                ? $0.offset < $1.offset : $0.element.sortOrder < $1.element.sortOrder
        }.map(\.element)
        guard let index = section.firstIndex(where: { $0.id == target.id }) else { return }
        settings.place(task, in: bucket)
        task.dueDate = target.dueDate
        section.insert(task, at: index)
        for (index, item) in section.enumerated() { item.sortOrder = Double(index) * 100 }
    }
    static func placeOnBoard(_ task: TaskItem, in bucket: Bucket, before id: UUID?, tasks: [TaskItem], settings: MacSettings) {
        let workspace = task.workspaceID ?? Workspace.defaultID
        let changesSection = settings.bucket(for: task) != bucket
        settings.place(task, in: bucket)
        if bucket != .today { task.isLiveNote = false; task.isPinned = false }
        if changesSection { task.dueDate = DateEngine.targetDate(for: bucket, now: .now, calendar: .current) }
        var section = tasks.filter {
            $0.id != task.id && !$0.isCompleted && ($0.workspaceID ?? Workspace.defaultID) == workspace && settings.visible($0, in: bucket)
        }.sorted { $0.sortOrder < $1.sortOrder }
        let index = id.flatMap { id in section.firstIndex(where: { $0.id == id }) } ?? section.count
        section.insert(task, at: index)
        for (index, item) in section.enumerated() { item.sortOrder = Double(index) * 100 }
    }
    static func toggleImportant(_ task: TaskItem, tasks: [TaskItem], settings: MacSettings) {
        guard !task.isCompleted else { return }
        if !task.isImportant {
            let workspace = task.workspaceID ?? Workspace.defaultID
            let bucket = settings.bucket(for: task)
            let active = tasks.filter {
                !$0.isCompleted && ($0.workspaceID ?? Workspace.defaultID) == workspace && settings.visible($0, in: bucket)
            }.sorted { $0.sortOrder < $1.sortOrder }
            task.sortOrder = Placement.sortOrderForFlagImportant(visible: active)
        }
        task.isImportant.toggle()
    }

    static func orderedForDisplay(_ tasks: [TaskItem]) -> [TaskItem] {
        tasks.filter { !$0.isCompleted } + tasks.filter(\.isCompleted).sorted {
            ($0.completedAt ?? .distantPast) < ($1.completedAt ?? .distantPast)
        }
    }

    static func toggleCompleted(_ task: TaskItem) -> () -> Void {
        let old = task.isCompleted, date = task.completedAt, live = task.isLiveNote, pinned = task.isPinned
        let due = task.dueDate
        let overdue = task.overduePlaced
        task.toggleCompletion()
        return { task.isCompleted = old; task.completedAt = date; task.isLiveNote = live; task.isPinned = pinned; task.dueDate = due; task.overduePlaced = overdue }
    }
    /// Completed tasks are also removable: Undo must preserve their original
    /// completion date rather than accidentally restoring them as unfinished.
    static func remove(_ task: TaskItem) -> () -> Void {
        let completed = task.isCompleted, date = task.completedAt, live = task.isLiveNote, pinned = task.isPinned, due = task.dueDate
        task.isCompleted = true; task.completedAt = .now
        if task.isLiveNote { task.dueDate = DateEngine.targetDate(for: .today, now: .now, calendar: .current) }
        task.isLiveNote = false; task.isPinned = false
        return { task.isCompleted = completed; task.completedAt = date; task.isLiveNote = live; task.isPinned = pinned; task.dueDate = due }
    }
}
