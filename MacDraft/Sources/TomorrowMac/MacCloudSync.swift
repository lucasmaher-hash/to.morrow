import AppKit
import CloudKit
import Combine
import CoreData
import Security
import SwiftData
import Shove95Kit

/// Never construct CKContainer in an unprovisioned preview: its failure can be
/// an Objective-C exception outside Swift's do/catch.
@MainActor final class MacCloudSync: ObservableObject {
    static let containerID = "iCloud.com.lucasmaher.shove95"
    enum Mode: Equatable { case localPreview, cloud, localFallback(String) }
    @Published private(set) var mode: Mode
    @Published private(set) var account: CKAccountStatus?
    @Published private(set) var lastTransfer: Date?
    @Published private(set) var syncError: String?
    private var observers = Set<AnyCancellable>()

    init(mode: Mode, checkAccount: Bool = true) {
        self.mode = mode
        guard mode == .cloud else { return }
        NotificationCenter.default.publisher(for: .CKAccountChanged).receive(on: RunLoop.main).sink { [weak self] _ in
            Task { @MainActor in self?.refresh() }
        }.store(in: &observers)
        NotificationCenter.default.publisher(for: NSPersistentCloudKitContainer.eventChangedNotification).receive(on: RunLoop.main).sink { [weak self] notification in
            guard let event = notification.userInfo?[NSPersistentCloudKitContainer.eventNotificationUserInfoKey] as? NSPersistentCloudKitContainer.Event,
                  let end = event.endDate else { return }
            let transferred = event.type == .import || event.type == .export
            let success = event.succeeded
            let message = event.error?.localizedDescription
            Task { @MainActor in
                guard let self else { return }
                if success {
                    self.syncError = nil
                    if transferred { self.lastTransfer = end }
                } else { self.syncError = message ?? "iCloud is temporarily unavailable. Changes remain on this Mac." }
            }
        }.store(in: &observers)
        if checkAccount { refresh() }
    }

    func refresh() {
        guard mode == .cloud else { return }
        Task { @MainActor in
            do { account = try await CKContainer(identifier: Self.containerID).accountStatus() }
            catch { account = .temporarilyUnavailable; syncError = error.localizedDescription }
        }
    }
    var title: String {
        switch mode {
        case .localPreview: return "iCloud unavailable in this preview"
        case .localFallback: return "Saved on this Mac"
        case .cloud:
            switch account {
            case .available: return syncError == nil ? "iCloud connected" : "iCloud needs attention"
            case .noAccount: return "Sign in to iCloud"
            case .restricted: return "iCloud is restricted"
            case .temporarilyUnavailable, .couldNotDetermine: return "iCloud temporarily unavailable"
            case .none: return "Checking iCloud"
            @unknown default: return "iCloud unavailable"
            }
        }
    }
    var detail: String {
        switch mode {
        case .localPreview: return "Your tasks stay on this Mac. The signed Mac app connects to the same iCloud account as to.morrow on your iPhone."
        case .localFallback: return "iCloud could not start. Your existing tasks are still available locally."
        case .cloud:
            if account == .noAccount { return "Sign in to the same Apple Account on your iPhone and Mac, then enable iCloud for to.morrow." }
            if account == .restricted { return "This Apple Account does not currently allow iCloud access. Your tasks remain available on this Mac." }
            return "Tasks, workspaces and attached photos sync with to.morrow on devices using the same Apple Account. Changes made offline sync when iCloud is available."
        }
    }
    static func isProvisioned(entitlements: [String: Any]) -> Bool {
        let services = entitlements["com.apple.developer.icloud-services"] as? [String] ?? []
        let containers = entitlements["com.apple.developer.icloud-container-identifiers"] as? [String] ?? []
        return services.contains("CloudKit") && containers.contains(containerID)
            && entitlements["com.apple.developer.team-identifier"] as? String != nil
    }
    static var provisioned: Bool {
        var code: SecCode?
        guard SecCodeCopySelf([], &code) == errSecSuccess, let code else { return false }
        var staticCode: SecStaticCode?
        guard SecCodeCopyStaticCode(code, [], &staticCode) == errSecSuccess, let staticCode else { return false }
        var information: CFDictionary?
        guard SecCodeCopySigningInformation(staticCode, SecCSFlags(rawValue: kSecCSSigningInformation), &information) == errSecSuccess,
              let info = information as? [String: Any],
              let entitlements = info[kSecCodeInfoEntitlementsDict as String] as? [String: Any] else { return false }
        return isProvisioned(entitlements: entitlements)
    }
}

@MainActor enum MacCloudStore {
    static var schema: Schema { Schema([TaskItem.self, Workspace.self, TaskPhoto.self]) }
    // Preserve the original draft store location, UUIDs, relationships and photos.
    static func configuration(cloud: Bool) -> ModelConfiguration {
        ModelConfiguration("TomorrowMacDraft", schema: schema,
            cloudKitDatabase: cloud ? .private(MacCloudSync.containerID) : .none)
    }
    static func open() throws -> (ModelContainer, MacCloudSync.Mode) {
        guard MacCloudSync.provisioned else {
            return (try ModelContainer(for: schema, configurations: configuration(cloud: false)), .localPreview)
        }
        do {
            try backupBeforeFirstSync()
            return (try ModelContainer(for: schema, configurations: configuration(cloud: true)), .cloud)
        } catch {
            return (try ModelContainer(for: schema, configurations: configuration(cloud: false)), .localFallback(error.localizedDescription))
        }
    }
    static func backupBeforeFirstSync(at url: URL = configuration(cloud: false).url) throws {
        let fm = FileManager.default
        guard fm.fileExists(atPath: url.path) else { return }
        let backup = url.deletingLastPathComponent().appendingPathComponent("Before-iCloud-TomorrowMacDraft", isDirectory: true)
        guard !fm.fileExists(atPath: backup.appendingPathComponent("complete").path) else { return }
        try fm.createDirectory(at: backup, withIntermediateDirectories: true)
        // Before the store is opened, include SQLite sidecars and external assets.
        for source in try fm.contentsOfDirectory(at: url.deletingLastPathComponent(), includingPropertiesForKeys: nil)
        where source.lastPathComponent.hasPrefix(url.lastPathComponent) || source.lastPathComponent.hasPrefix("." + url.lastPathComponent) {
            let destination = backup.appendingPathComponent(source.lastPathComponent)
            if !fm.fileExists(atPath: destination.path) { try fm.copyItem(at: source, to: destination) }
        }
        try Data().write(to: backup.appendingPathComponent("complete"), options: .atomic)
    }
}

/// CloudKit does not allow uniqueness constraints; match the phone's oldest-wins
/// rule without deleting or rewriting remotely owned records.
@MainActor enum MacWorkspaceRecords {
    static func unique(_ records: [Workspace]) -> [Workspace] {
        let sorted = records.sorted { $0.createdAt < $1.createdAt }
        var ids = Set<String>(), names = Set<String>()
        let byID = sorted.filter { ids.insert($0.id).inserted }
            .sorted { $0.isDefault != $1.isDefault ? $0.isDefault : $0.createdAt < $1.createdAt }
        return byID.filter {
            let name = $0.name.trimmingCharacters(in: .whitespaces).lowercased()
            return name.isEmpty || names.insert(name).inserted
        }
    }
}

@MainActor final class MacCloudAppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        if MacCloudSync.provisioned { NSApp.registerForRemoteNotifications() }
    }
}
