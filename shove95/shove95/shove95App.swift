//
//  shove95App.swift
//  shove95
//
//  Created by Lucas Maher on 03.08.26.
//

import SwiftUI
import SwiftData
import Shove95Kit

@main
struct shove95App: App {
    private let container: ModelContainer
    @State private var store: TaskStore
    @State private var settings = AppSettings()
    @State private var sync = SyncStatus()
    @Environment(\.scenePhase) private var scenePhase

    init() {
        let (container, mode) = Self.makeContainer()
        self.container = container
        let store = TaskStore(context: container.mainContext)
        _store = State(initialValue: store)
        _sync = State(initialValue: SyncStatus(mode: mode))

        // The Lock Screen's tick button. `CompletePinnedTaskIntent` lives in
        // the package so both targets can see it, and performs in THIS
        // process — iOS launches the app in the background to run it — so the
        // work is handed back up here, where the store is.
        //
        // Installed in `init` rather than a `.task`: on that background launch
        // no scene is ever shown, so nothing in `body` is guaranteed to run
        // before the intent performs. `init` always does.
        // Found through `anyTask(withID:)`: unscoped, so a task pinned in Work
        // is still found while Personal is open, and resolved BY THE ID THE
        // CARD CARRIES rather than by whatever currently holds the pin — see
        // that method for why the difference is not academic.
        PinnedTaskActions.complete = { @MainActor id in
            guard let task = store.anyTask(withID: id), !task.isCompleted else { return }
            store.toggleCompleted(task) // also releases the pin
        }
    }

    /// Sync when it's provisioned, local otherwise — and NEVER a crash.
    ///
    /// The gate is a real one, not caution: with `cloudKitDatabase: .private`
    /// and no iCloud entitlement, CoreData's mirroring delegate calls
    /// `CKContainer(identifier:)`, which raises an OBJECTIVE-C exception on a
    /// background queue. Swift `try/catch` cannot see it and the app dies on
    /// launch (verified 2026-08-04). So the CloudKit path is only taken when
    /// the entitlement actually exists, which the Info.plist flag records —
    /// see docs/cloudkit-setup.md for the two-minute Xcode step that sets it.
    static var cloudKitEnabled: Bool {
        Bundle.main.object(forInfoDictionaryKey: "ShoveCloudKitEnabled") as? Bool ?? false
    }

    private static func makeContainer() -> (ModelContainer, SyncStatus.Mode) {
        let models: [any PersistentModel.Type] = [TaskItem.self, TaskPhoto.self, Workspace.self]
        let schema = Schema(models)

        do {
            guard cloudKitEnabled else {
                let local = ModelConfiguration(schema: schema, cloudKitDatabase: .none)
                return (try ModelContainer(for: schema, configurations: local),
                        .localOnly(reason: "iCloud not enabled for this build"))
            }
            let cloud = ModelConfiguration(
                schema: schema,
                cloudKitDatabase: .private("iCloud.com.lucasmaher.shove95")
            )
            return (try ModelContainer(for: schema, configurations: cloud), .syncing)
        } catch {
            // Local store, same schema — the data is identical, only the
            // mirroring is absent.
            let local = ModelConfiguration(schema: schema, cloudKitDatabase: .none)
            if let container = try? ModelContainer(for: schema, configurations: local) {
                return (container, .localOnly(reason: error.localizedDescription))
            }
            // Nothing on disk works: an in-memory store still lets the app run
            // rather than crash on launch. Nothing written here survives.
            let memory = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
            let container = try! ModelContainer(for: schema, configurations: memory)
            return (container, .unavailable(reason: error.localizedDescription))
        }
    }

    var body: some Scene {
        WindowGroup {
            ZStack {
                AppShell()
                .environment(store)
                .environment(settings)
                .environment(sync)
                .modifier(PixelScale()) // stepped 2×/3×/4× (FR-015)
                .task {
                    // Photos moved into their own records for CloudKit; this
                    // lifts anything still in the old fields. Idempotent.
                    store.migrateLegacyPhotos()
                }
                #if DEBUG
                // Seeding by launch argument keeps the debug controls off the
                // screen: `simctl launch … -seedFillers YES`.
                .task {
                    // FIRST, so `-wipeAll YES -seedDemo YES` reads as "start
                    // clean, then seed" rather than racing the two.
                    if UserDefaults.standard.bool(forKey: "wipeAll") {
                        store.wipeAllTasks()
                    }
                    if UserDefaults.standard.bool(forKey: "seedFillers") {
                        store.seedScrollFillers()
                    }
                    if UserDefaults.standard.bool(forKey: "seedSoonSpread") {
                        store.seedSoonSpread()
                    }
                    if UserDefaults.standard.bool(forKey: "seedArchive") {
                        // AFTER the root has pointed the store at a workspace.
                        // Seeded before that, the tasks carry no workspace and
                        // every query filters them out again.
                        try? await Task.sleep(for: .milliseconds(500))
                        store.seedArchive()
                    }
                    if UserDefaults.standard.bool(forKey: "seedDemo") {
                        store.seedDemo()
                    }
                }
                #endif

            }
            .task {
                // Warms the store. The first query is the thing that actually
                // takes time on a cold CloudKit launch, so it is worth firing
                // before the list asks for it — but nothing waits on it now.
                _ = store.tasks(in: .today)
            }
        }
        .modelContainer(container)
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active {
                // WARM the taptic generators. They are held statically, which
                // is half the job — an unprepared generator drops or weakens
                // its first impulse, and this look fires rarely enough that
                // its first impulse was almost always the one you felt
                // (founder bug report 2026-08-17). Skeu got away with it by
                // firing constantly and keeping them warm by accident.
                SkeuHaptic.prepare()
                // Day-rollover placement pass — cheap and idempotent (PRD §2).
                store.runDayRolloverPassIfNeeded(
                    timeRules: settings.timeRulesEnabled(for: .today))
                sync.refreshAccountStatus()
            }
        }
    }
}
