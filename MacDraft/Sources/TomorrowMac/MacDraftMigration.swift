import AppKit
import Foundation

/// Copy-only migration. The directory is committed atomically before SwiftData
/// opens it; a failed/cancelled import never falls through to an empty store.
@MainActor enum MacDraftMigration {
    static let storeName = "TomorrowMacDraft.store"
    static var directory: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("to.morrow", isDirectory: true)
    }
    static var storeURL: URL { directory.appendingPathComponent(storeName) }

    static func prepare() throws {
        let fm = FileManager.default
        if fm.fileExists(atPath: directory.path) {
            guard fm.fileExists(atPath: storeURL.path) || fm.fileExists(atPath: directory.appendingPathComponent("draft-preferences.plist").path) || fm.fileExists(atPath: directory.appendingPathComponent("fresh-install").path) else {
                throw CocoaError(.fileReadCorruptFile)
            }
            try finishPreferences(at: directory, defaults: .standard)
            return
        }
        let alert = NSAlert()
        alert.messageText = "Import your existing to.morrow data?"
        alert.informativeText = "If you used the earlier Mac version, select its dated backup folder. Tasks, photos and settings will be copied. The original stays untouched."
        alert.addButton(withTitle: "Import Existing Data…")
        alert.addButton(withTitle: "Start Without Draft Data")
        alert.addButton(withTitle: "Quit")
        switch alert.runModal() {
        case .alertFirstButtonReturn:
            let panel = NSOpenPanel()
            panel.title = "Select your to.morrow backup folder"
            panel.canChooseDirectories = true
            panel.canChooseFiles = false
            panel.allowsMultipleSelection = false
            guard panel.runModal() == .OK, let source = panel.url else { throw CocoaError(.userCancelled) }
            let scoped = source.startAccessingSecurityScopedResource()
            defer { if scoped { source.stopAccessingSecurityScopedResource() } }
            try copyBackup(from: source, to: directory, defaults: .standard)
        case .alertSecondButtonReturn:
            try fm.createDirectory(at: directory, withIntermediateDirectories: true)
            try Data().write(to: directory.appendingPathComponent("fresh-install"), options: .atomic)
        default: throw CocoaError(.userCancelled)
        }
    }

    static func copyBackup(from source: URL, to destination: URL, defaults: UserDefaults) throws {
        let fm = FileManager.default
        // Never merge into or overwrite a destination, including partial user data.
        guard !fm.fileExists(atPath: destination.path) else { return }
        let support = source.appendingPathComponent("Application Support", isDirectory: true)
        guard fm.fileExists(atPath: support.appendingPathComponent(storeName).path) else {
            throw CocoaError(.fileReadNoSuchFile)
        }
        let stage = destination.deletingLastPathComponent().appendingPathComponent(".tomorrow-migration-" + UUID().uuidString)
        try fm.createDirectory(at: stage, withIntermediateDirectories: true)
        defer { try? fm.removeItem(at: stage) } // Only this invocation's staging directory.
        for item in try fm.contentsOfDirectory(at: support, includingPropertiesForKeys: nil)
        where item.lastPathComponent.hasPrefix("TomorrowMacDraft") || item.lastPathComponent.hasPrefix(".TomorrowMacDraft") {
            try fm.copyItem(at: item, to: stage.appendingPathComponent(item.lastPathComponent))
        }
        let preferences = source.appendingPathComponent("preferences-export.plist")
        guard fm.fileExists(atPath: preferences.path) else { throw CocoaError(.fileReadNoSuchFile) }
        let values = try PropertyListSerialization.propertyList(from: Data(contentsOf: preferences), format: nil)
        guard values is [String: Any] else { throw CocoaError(.propertyListReadCorrupt) }
        try fm.copyItem(at: preferences, to: stage.appendingPathComponent("draft-preferences.plist"))
        try fm.moveItem(at: stage, to: destination)
        try finishPreferences(at: destination, defaults: defaults)
    }

    static func finishPreferences(at directory: URL, defaults: UserDefaults) throws {
        let source = directory.appendingPathComponent("draft-preferences.plist")
        let marker = directory.appendingPathComponent("migration-complete")
        guard !FileManager.default.fileExists(atPath: marker.path),
              FileManager.default.fileExists(atPath: source.path) else { return }
        guard let values = try PropertyListSerialization.propertyList(from: Data(contentsOf: source), format: nil) as? [String: Any] else {
            throw CocoaError(.propertyListReadCorrupt)
        }
        for (key, value) in values where key.hasPrefix("mac.") || key == "macDraftSeeded" {
            if defaults.object(forKey: key) == nil { defaults.set(value, forKey: key) }
        }
        // The marker must not outrun persistence if the process exits immediately.
        guard defaults.synchronize() else { throw CocoaError(.fileWriteUnknown) }
        try Data().write(to: marker, options: .atomic)
    }
}
