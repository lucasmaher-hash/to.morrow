//
//  AppShell.swift
//  shove95
//
//  The root: hands the tree its palette, typeface and lighting.
//
//  The SETTINGS SHEET is owned here rather than by the root view, so controls
//  inside the sheet that re-skin the app (theme, typeface) never swap the
//  presenting tree out from under their own presentation — that vanished the
//  sheet mid-interaction (founder bug report 2026-08-14). Held above, the
//  sheet survives and simply re-skins.
//

import SwiftUI

struct AppShell: View {
    @Environment(AppSettings.self) private var settings
    /// The DEVICE setting. Only consulted when the user picked "System" — in
    /// the other two cases the palette is pinned, so reading this would make
    /// the resolution circular once `preferredColorScheme` takes effect.
    @Environment(\.colorScheme) private var systemScheme

    @State private var showSettings = false
    /// Owned HERE for the same reason the settings sheet is: the pinned task
    /// is app-wide, so its coordinator lives above everything it outlasts.
    @State private var activity = LiveActivityController()
    @Environment(TaskStore.self) private var store
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        root
            // `isPresented` is untouched by re-skinning controls inside the
            // sheet, so the sheet stays up; only its content and the palette
            // underneath change.
            .fullScreenCover(isPresented: $showSettings) {
                settingsSheet
            }
            // Reconciliation, not commands — see LiveActivityController. Every
            // way a pin can appear or vanish (pinned, replaced, completed,
            // deleted, rolled over, synced from another device) bumps
            // `revision`, so this one hook covers all of them.
            .task(id: store.revision) { reconcile() }
            // The look travels INSIDE the activity's content, so a theme,
            // typeface or design change has to be pushed out to the Lock
            // Screen the same as a title change.
            .onChange(of: lookSignature) { reconcile() }
            // Restarts anything iOS retired at its eight-hour ceiling.
            .onChange(of: scenePhase) { _, phase in
                if phase == .active { reconcile() }
            }
    }

    private func reconcile() {
        activity.reconcile(store: store, settings: settings, isDark: isDark)
    }

    /// Everything the Lock Screen card's appearance depends on, in one value
    /// so a single `onChange` catches all of it.
    private var lookSignature: String {
        [settings.skeuTheme.id,
         settings.skeuFace.rawValue,
         isDark ? "d" : "l"].joined(separator: "|")
    }

    @ViewBuilder
    private var root: some View {
        SkeuRootView(showSettings: $showSettings)
            // The palette rides the environment, so it needs no help. The
            // TYPEFACE does: SkeuFont reads a static, which SwiftUI cannot
            // see, so the subtree has to be rebuilt when it changes.
            .id(settings.skeuFace.rawValue)
            // Dynamic Type (FR-015). This look has no stepped pixel unit, so
            // it resolves the setting into two multipliers here.
            .skeuTypeScaling()
            .skeuTheme(settings.skeuTheme.palette(dark: isDark))
            .preferredColorScheme(settings.appearance.preferred)
    }

    @ViewBuilder
    private var settingsSheet: some View {
        // NO `.id(face)` here, unlike the root above. Rebuilding this
        // sheet on a typeface change tore down the toggle mid-glide, so
        // the Typeface switch was the one switch on the screen that
        // snapped instead of sliding. The face rides the environment
        // instead; the few leaf views that don't otherwise observe
        // AppSettings read it to declare the dependency.
        SkeuSettingsView { showSettings = false }
            .environment(\.skeuFace, settings.skeuFace)
            .skeuTypeScaling()
            .skeuTheme(settings.skeuTheme.palette(dark: isDark))
            .preferredColorScheme(settings.appearance.preferred)
    }

    private var isDark: Bool {
        settings.appearance.isDark(system: systemScheme)
    }
}
