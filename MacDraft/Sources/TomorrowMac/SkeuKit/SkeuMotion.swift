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
