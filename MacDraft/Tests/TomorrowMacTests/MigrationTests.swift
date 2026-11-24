import Foundation
import SwiftData
import Testing
import Shove95Kit
@testable import TomorrowMac

@Suite @MainActor struct MigrationTests {
    private func hashes(_ directory: URL) throws -> [String: Data] {
        let fm = FileManager.default
        var result: [String: Data] = [:]
        for case let file as URL in fm.enumerator(at: directory, includingPropertiesForKeys: [.isRegularFileKey])! {
            if try file.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile == true {
                result[String(file.path.dropFirst(directory.path.count))] = try Data(contentsOf: file)
            }
        }
        return result
    }

    @Test func copiedBackupPreservesDataAndNeverOverwrites() throws {
        let fm = FileManager.default
        let root = fm.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try fm.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? fm.removeItem(at: root) }
        let backup = root.appendingPathComponent("backup")
        let fixture = ProcessInfo.processInfo.environment["MAC_DRAFT_MIGRATION_FIXTURE"]
        if let fixture {
            // Test a disposable copy of the dated backup, never the original store.
            try fm.copyItem(at: URL(fileURLWithPath: fixture), to: backup)
        } else {
            let support = backup.appendingPathComponent("Application Support")
            try fm.createDirectory(at: support, withIntermediateDirectories: true)
            let config = ModelConfiguration("TomorrowMacDraft", schema: MacCloudStore.schema,
                url: support.appendingPathComponent(MacDraftMigration.storeName), cloudKitDatabase: .none)
            let container = try ModelContainer(for: MacCloudStore.schema, configurations: config)
            let task = TaskItem(); task.title = "Migration test"
            container.mainContext.insert(task)
            try container.mainContext.save()
            let preferences = try PropertyListSerialization.data(fromPropertyList: ["mac.theme": "rose"], format: .xml, options: 0)
            try preferences.write(to: backup.appendingPathComponent("preferences-export.plist"))
        }
        let before = try hashes(backup)
        let suite = "migration-test-" + UUID().uuidString
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        defaults.set("existing", forKey: "mac.appearance")
        let destination = root.appendingPathComponent("new")
        try MacDraftMigration.copyBackup(from: backup, to: destination, defaults: defaults)
        for (path, bytes) in before where path.hasPrefix("/Application Support/TomorrowMacDraft") || path.hasPrefix("/Application Support/.TomorrowMacDraft") {
            let relative = String(path.dropFirst("/Application Support/".count))
            #expect(try Data(contentsOf: destination.appendingPathComponent(relative)) == bytes)
        }
        #expect(defaults.string(forKey: "mac.appearance") == "existing")
        let oldValues = try PropertyListSerialization.propertyList(from: Data(contentsOf: backup.appendingPathComponent("preferences-export.plist")), format: nil) as! [String: Any]
        #expect(defaults.string(forKey: "mac.theme") == oldValues["mac.theme"] as? String)
        let copied = try hashes(destination)
        try MacDraftMigration.copyBackup(from: backup, to: destination, defaults: defaults)
        #expect(try hashes(destination) == copied)
        #expect(try hashes(backup) == before)
        // Open only the migrated copy. Fetching proves this is a usable SwiftData store.
        let config = ModelConfiguration("TomorrowMacDraft", schema: MacCloudStore.schema,
            url: destination.appendingPathComponent(MacDraftMigration.storeName), cloudKitDatabase: .none)
        let container = try ModelContainer(for: MacCloudStore.schema, configurations: config)
        #expect(try container.mainContext.fetchCount(FetchDescriptor<TaskItem>()) > 0)
        _ = try container.mainContext.fetch(FetchDescriptor<TaskPhoto>())
    }

    @Test func failedImportDoesNotCreateDestination() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let destination = root.appendingPathComponent("new")
        #expect(throws: (any Error).self) {
            try MacDraftMigration.copyBackup(from: root, to: destination, defaults: .standard)
        }
        #expect(!FileManager.default.fileExists(atPath: destination.path))
    }
}
