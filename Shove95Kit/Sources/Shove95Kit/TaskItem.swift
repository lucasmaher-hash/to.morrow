import Foundation
import SwiftData

/// The one entity (PRD §3). CloudKit-compatible by construction:
/// every stored property is defaulted or optional, no `#Unique`,
/// no relationships. NEVER name this `Task` — it collides with
/// Swift Concurrency.
@Model
public final class TaskItem {
    public var id: UUID = UUID()
    public var title: String = ""
    /// Start-of-day date this task is scheduled for. nil = General (dateless).
    public var dueDate: Date? = nil
    public var isImportant: Bool = false
    public var isCompleted: Bool = false
    /// Set when ticked; cleared when unticked. Drives archive visibility.
    public var completedAt: Date? = nil
    public var createdAt: Date = Date.now
    /// Global manual ordering. Placement rules assign it once on events;
    /// drag-reorder mutates it. Fractional (midpoint) inserts.
    public var sortOrder: Double = 0
    /// True once the day-rollover pass has positioned this task in Today's
    /// overdue block. Reset whenever `dueDate` changes, so a re-deferred task
    /// gets placed again the next time it goes overdue. Prevents re-placing a
    /// task the user has dragged (PRD §3 placement table).
    public var overduePlaced: Bool = false
    /// The one task pinned to the Lock Screen and Dynamic Island — the
    /// founder calls this "active" (2026-08-16).
    ///
    /// App-wide exactly one, across every workspace: the question it answers
    /// is "what is the one thing right now", and that is not a per-folder
    /// question. `TaskStore.pin(_:)` is the only writer and enforces it.
    ///
    /// Named `isPinned` rather than `isActive` because the file that acts on
    /// it also holds ActivityKit's `Activity`, and two different meanings of
    /// "active" in one place is how bugs get written. It SYNCS: pin on the
    /// phone and the iPad's Lock Screen shows it too.
    public var isPinned: Bool = false
    /// This task IS the live note — it lives in the Live section and nowhere
    /// else (founder direction 2026-08-17).
    ///
    /// It is the one deliberate hole in the "tabs are total filters" rule.
    /// Everything else maps to exactly one tab at every moment; a live note
    /// maps to none, because it is not a thing you scheduled — it is the
    /// thing you are doing. Ticking it on the Lock Screen completes it like
    /// any other task, so it still reaches the archive.
    ///
    /// Separate from `isPinned`, which now means only "showing on the Lock
    /// Screen right now". The switch in the Live section turns that off and
    /// leaves the text in the box.
    public var isLiveNote: Bool = false
    // ── Photos ──────────────────────────────────────────────────────────
    // Each photo is its OWN record (TASK-050). The previous shape — one
    // `Data?` plus an `[Data]` array — could not go to CloudKit: an array of
    // image blobs serialises into a single field, and CKRecord caps
    // non-asset payload at 1MB, so two photos would have failed to sync
    // silently. As a separate entity each photo's `data` maps to a CKAsset,
    // which has no such limit.
    @Relationship(deleteRule: .cascade, inverse: \TaskPhoto.task)
    public var photos: [TaskPhoto]? = nil

    // Legacy slots, read once by the launch migration and then left empty.
    // Kept (rather than deleted) so an existing store opens without a
    // versioned-schema migration.
    @Attribute(.externalStorage) public var photoData: Data? = nil
    public var extraPhotos: [Data] = []
    /// Which workspace this task lives in. nil = the default workspace, which
    /// is also what every pre-workspace task migrates to (optional + defaulted
    /// keeps the model CloudKit-compatible and the store migration lightweight).
    public var workspaceID: String? = nil

    public init() {}

    /// Every photo, oldest first — the order they were added, left to right.
    public var allPhotos: [Data] {
        orderedPhotos.compactMap(\.data)
    }

    public var orderedPhotos: [TaskPhoto] {
        (photos ?? []).sorted { $0.order < $1.order }
    }

    /// True while this task still holds photos in the pre-CloudKit slots.
    public var needsPhotoMigration: Bool {
        photoData != nil || !extraPhotos.isEmpty
    }

    /// The legacy contents, oldest first, for the launch migration.
    public var legacyPhotos: [Data] {
        (photoData.map { [$0] } ?? []) + extraPhotos
    }

    public func clearLegacyPhotos() {
        photoData = nil
        extraPhotos = []
    }

    public var nextPhotoOrder: Int {
        ((photos ?? []).map(\.order).max() ?? -1) + 1
    }
}
