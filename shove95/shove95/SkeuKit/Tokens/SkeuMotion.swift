//
//  SkeuMotion.swift
//  shove95
//
//  Motion physics (§8). Motion communicates MASS: these objects are light but
//  not weightless, so they settle quickly with a small overshoot. Nothing
//  linear, nothing bouncy.
//
//  This is the exact opposite of the rule the app shipped with, where
//  appearance changes were instant and the press WAS the animation.
//

import SwiftUI

enum SkeuMotion {
    /// Press / release. The most-used curve in the system.
    static let press = Animation.spring(response: 0.26, dampingFraction: 0.68)
    /// Layout shifts, appearance of inline content.
    static let layout = Animation.spring(response: 0.40, dampingFraction: 0.86)
    /// Sheets and large overlays.
    static let present = Animation.spring(response: 0.52, dampingFraction: 0.84)
    /// State cross-fades where nothing actually moves.
    static let tint = Animation.easeOut(duration: 0.16)
}

// MARK: - Haptics (§8.4)

/// Touch-DOWN rather than release is deliberate: it reinforces that the object
/// physically moved under the finger.
/// The app's haptics. Named for the skeu kit because that is where it
/// started; it was shared so a swipe would feel the same in either costume
/// (founder bug report 2026-08-17, that the slide buzzed in one and not the
/// other).
///
/// The generators are HELD and PREPARED rather than built at the call site.
/// A generator constructed and fired in the same breath frequently drops its
/// first impulse — the engine has not spun up — which is exactly how one look
/// ends up feeling dead while the other, warmed by some earlier tap, does not.
enum SkeuHaptic {
    @MainActor private static let light = UIImpactFeedbackGenerator(style: .light)
    @MainActor private static let rigid = UIImpactFeedbackGenerator(style: .rigid)
    @MainActor private static let soft = UIImpactFeedbackGenerator(style: .soft)
    @MainActor private static let selector = UISelectionFeedbackGenerator()
    @MainActor private static let notifier = UINotificationFeedbackGenerator()

    /// Call before a gesture that will buzz — on touch-down, not on commit.
    @MainActor static func prepare() {
        light.prepare()
        rigid.prepare()
        soft.prepare()
        // The selector and the notifier were left out, and they carry every
        // choice in settings and every menu row (founder bug report
        // 2026-08-17). A generator that is never prepared drops or weakens its
        // first impulse, which where one fires rarely is most of them.
        selector.prepare()
        notifier.prepare()
    }

    @MainActor static func press() {
        light.impactOccurred()
    }

    /// The moment a swipe passes the point where letting go would commit.
    /// Softer than the commit itself, so the two read as a pair rather than a
    /// double tap.
    @MainActor static func threshold() {
        soft.impactOccurred(intensity: 0.7)
    }

    @MainActor static func toggle() {
        rigid.impactOccurred()
    }

    @MainActor static func selection() {
        selector.selectionChanged()
    }

    @MainActor static func warning() {
        notifier.notificationOccurred(.warning)
    }

    @MainActor static func success() {
        notifier.notificationOccurred(.success)
    }
}
