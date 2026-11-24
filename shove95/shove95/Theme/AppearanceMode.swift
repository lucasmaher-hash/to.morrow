//
//  AppearanceMode.swift
//  shove95
//
//  Whether the app is lit light or dark.
//

import SwiftUI

enum AppearanceMode: String, CaseIterable, Sendable {
    case system, light, dark

    var label: String {
        switch self {
        case .system: "System"
        case .light:  "Light"
        case .dark:   "Dark"
        }
    }

    /// What to hand `preferredColorScheme`. `.system` returns nil so the app
    /// keeps following the device — pinning it would break the very thing the
    /// option promises, and would make the resolved palette self-referential.
    var preferred: ColorScheme? {
        switch self {
        case .system: nil
        case .light:  .light
        case .dark:   .dark
        }
    }

    /// Resolves against the device setting, which only matters for `.system`.
    func isDark(system: ColorScheme) -> Bool {
        switch self {
        case .system: system == .dark
        case .light:  false
        case .dark:   true
        }
    }
}
