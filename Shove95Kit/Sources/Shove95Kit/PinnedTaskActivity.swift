//
//  PinnedTaskActivity.swift
//  Shove95Kit
//
//  The contract between the app and the Lock Screen.
//
//  It lives in the package because both the app and the widget extension have
//  to agree on it exactly — an ActivityAttributes mismatch does not fail to
//  build, it fails to decode at runtime and the Live Activity simply never
//  appears.
//
//  COLOUR TRAVELS RESOLVED. The obvious design was to send a theme id and let
//  the widget rebuild the palette, which would have meant moving SkeuPalette
//  and everything it touches into this package and making all of it public.
//  Instead the app — which already owns the palette, and is the only place
//  allowed to know colours (CLAUDE.md rule 2) — resolves them and sends the
//  six it needs. The widget draws what it is handed and has no concept of a
//  theme at all. Re-skinning the app re-skins the Lock Screen for free, with
//  no widget code involved.
//
//  What the widget still owns is GEOMETRY: a soft-shadowed capsule is a
//  drawing, not a colour. Those are drawn there.
//

import Foundation

// `os(iOS)`, NOT `canImport(ActivityKit)`. The module IS importable on
// macOS — every type in it is marked unavailable there instead — so
// canImport compiled the guard in and then failed on the protocol. The
// package targets macOS for the future Mac app, and this broke `swift test`
// outright (found in the 2026-08-16 audit).
#if os(iOS)
import ActivityKit
#endif

/// An sRGB colour that survives the trip through ActivityKit's encoder.
///
/// Not `Color`: SwiftUI's `Color` is not `Codable`, and `CodableColor`
/// wrappers that go through `UIColor` archiving are both heavier and lossy
/// across process boundaries. Four doubles are neither.
public struct ActivityColor: Codable, Hashable, Sendable {
    public var red: Double
    public var green: Double
    public var blue: Double
    public var alpha: Double

    public init(red: Double, green: Double, blue: Double, alpha: Double = 1) {
        self.red = red
        self.green = green
        self.blue = blue
        self.alpha = alpha
    }
}

/// Which grammar the Lock Screen card is drawn in.
///
/// There were two, and they were not variations of one card — they shared no
/// geometry, so this picked a whole layout rather than a style flag. One is
/// left (2026-08-22). The field stays because it is part of the activity's
/// encoded state: an activity still running from an older build carries the
/// removed value, fails to decode, and is simply replaced when the app next
/// reconciles.
public enum ActivityLook: String, Codable, Sendable {
    case skeu
}

/// The six roles the card needs. Named by ROLE rather than by what draws
/// them, so the card asks for `surface` and not for a particular material.
public struct ActivityPalette: Codable, Hashable, Sendable {
    public var surface: ActivityColor
    public var ink: ActivityColor
    public var inkMuted: ActivityColor
    public var accent: ActivityColor
    /// The rim light.
    public var light: ActivityColor
    /// The contact shadow.
    public var dark: ActivityColor

    public init(surface: ActivityColor, ink: ActivityColor, inkMuted: ActivityColor,
                accent: ActivityColor, light: ActivityColor, dark: ActivityColor) {
        self.surface = surface
        self.ink = ink
        self.inkMuted = inkMuted
        self.accent = accent
        self.light = light
        self.dark = dark
    }
}

#if os(iOS)

public struct PinnedTaskAttributes: ActivityAttributes {

    /// Everything that can change while the activity is running.
    ///
    /// The TITLE is here rather than in the static half deliberately: renaming
    /// a pinned task updates the Lock Screen in place. In the static half it
    /// would have required ending and restarting the activity, which flashes.
    public struct ContentState: Codable, Hashable {
        public var title: String
        /// The due-date word — "Wed", "Overdue". nil when the task is dateless.
        public var chip: String?
        public var look: ActivityLook
        public var palette: ActivityPalette
        /// PostScript name of the face to draw in, or nil for the system font.
        /// The typeface is a setting, and the Lock Screen honours it.
        public var fontName: String?

        public init(title: String, chip: String?, look: ActivityLook,
                    palette: ActivityPalette, fontName: String?) {
            self.title = title
            self.chip = chip
            self.look = look
            self.palette = palette
            self.fontName = fontName
        }
    }

    /// Identifies which task this is, so the complete button and the deep link
    /// know what they are acting on. Immutable for the activity's lifetime —
    /// pinning a different task ends this one and starts another.
    public var taskID: UUID

    public init(taskID: UUID) {
        self.taskID = taskID
    }
}

#endif
