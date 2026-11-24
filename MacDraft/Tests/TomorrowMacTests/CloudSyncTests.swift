import Foundation
import SwiftData
import CoreData
import Testing
import Shove95Kit
@testable import TomorrowMac

@Suite @MainActor struct CloudSyncTests {
    @Test func backgroundSyncNotificationsDoNotViolateMainActor() async throws {
        let status = MacCloudSync(mode: .cloud, checkAccount: false)
        await Task.detached {
            NotificationCenter.default.post(name: NSPersistentCloudKitContainer.eventChangedNotification, object: nil)
        }.value
        try await Task.sleep(for: .milliseconds(80))
        #expect(status.mode == .cloud)
    }
    @Test func cloudKeepsTheExistingLocalStoreURL() {
        #expect(MacCloudStore.configuration(cloud: true).url == MacCloudStore.configuration(cloud: false).url)
    }
    @Test func unsignedOrWrongContainerBuildsCannotStartCloudKit() {
        #expect(!MacCloudSync.isProvisioned(entitlements: [:]))
        #expect(!MacCloudSync.isProvisioned(entitlements: [
            "com.apple.developer.icloud-services": ["CloudKit"],
            "com.apple.developer.icloud-container-identifiers": ["iCloud.wrong"],
            "com.apple.developer.team-identifier": "test"
        ]))
        #expect(MacCloudSync.isProvisioned(entitlements: [
            "com.apple.developer.icloud-services": ["CloudKit"],
            "com.apple.developer.icloud-container-identifiers": [MacCloudSync.containerID],
            "com.apple.developer.team-identifier": "test"
        ]))
    }
    @Test func backupPreservesSidecarsAndAssetsAndIsNotOverwritten() throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }
        let store = dir.appendingPathComponent("TomorrowMacDraft.store")
        for name in [store.lastPathComponent, store.lastPathComponent + "-wal", "." + store.lastPathComponent + "_SUPPORT"] {
            try Data(name.utf8).write(to: dir.appendingPathComponent(name))
        }
        try MacCloudStore.backupBeforeFirstSync(at: store)
        try Data("changed".utf8).write(to: store)
        try MacCloudStore.backupBeforeFirstSync(at: store)
        let backup = dir.appendingPathComponent("Before-iCloud-TomorrowMacDraft")
        #expect(try Data(contentsOf: backup.appendingPathComponent(store.lastPathComponent)) == Data(store.lastPathComponent.utf8))
        #expect(FileManager.default.fileExists(atPath: backup.appendingPathComponent(store.lastPathComponent + "-wal").path))
        #expect(FileManager.default.fileExists(atPath: backup.appendingPathComponent("." + store.lastPathComponent + "_SUPPORT").path))
    }
    @Test func workspaceSeedsConvergeWithoutDeletingRecords() {
        let old = Workspace(id: Workspace.defaultID, name: "Mine", createdAt: .distantPast)
        let duplicate = Workspace(id: Workspace.defaultID, name: "Personal")
        let work = Workspace(id: Workspace.workID, name: "Work")
        let namedDuplicate = Workspace(id: "legacy", name: " Work ", createdAt: .distantFuture)
        let records = [duplicate, namedDuplicate, work, old]
        let result = MacWorkspaceRecords.unique(records)
        #expect(result.map(\.id) == [Workspace.defaultID, Workspace.workID])
        #expect(result.first?.name == "Mine")
        #expect(records.count == 4)
    }
    @Test func liveReflectsRemoteCompletionAndReplacement() throws {
        let schema = MacCloudStore.schema
        let container = try ModelContainer(for: schema, configurations: ModelConfiguration(schema: schema, isStoredInMemoryOnly: true, cloudKitDatabase: .none))
        let task = TaskItem(); task.isLiveNote = true
        container.mainContext.insert(task)
        let live = MacLiveController(context: container.mainContext, presentUI: false)
        #expect(live.note?.id == task.id)
        task.isCompleted = true
        let replacement = TaskItem(); replacement.isLiveNote = true
        container.mainContext.insert(replacement)
        live.reloadFromStore()
        #expect(live.note?.id == replacement.id)
    }
}
