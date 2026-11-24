//
//  AppFace.swift
//  shove95
//
//  Which typeface the interface is set in, and the one distinction that
//  choice turns on.
//
//  W95FA — an OpenType recreation of the Windows 95 MS Sans Serif bitmap — is
//  bundled at Resources/W95FA.otf (SIL OFL, see W95FA-LICENSE.txt). The
//  interface it was drawn for is gone (2026-08-22); the face stayed, because
//  what the founder wanted from it was a texture on the app's own furniture,
//  not a costume for the whole screen.
//
//  This file was W95Font.swift and carried three fixed pixel sizes as well.
//  Those belonged to the pixel-grid layout and went with it — SkeuFont sizes
//  type now, and asks here only which face to set it in.
//

import SwiftUI

/// What a piece of text IS — the distinction the Retro face is built on.
///
/// `content` is the DEFAULT, deliberately. Retro is defined by what stays
/// pixel, not by what escapes it (founder direction 2026-08-16: "only the
/// important parts"), so a call site that says nothing gets the readable face.
/// Forgetting to mark a label then costs legibility for one line; the opposite
/// default would quietly costume the user's own words.
enum TextRole {
    /// The app's own furniture: the workspace name, the tab bar, a settings
    /// heading, the toggle you just pressed. Things the app says about itself,
    /// where the pixel face IS the product.
    case chrome
    /// The user's own words — a task's title, a name they typed. Never
    /// sacrificed to costume.
    case content
}

/// Which typeface the interface uses.
enum AppFace: String, CaseIterable, Sendable {
    /// TWO faces, not three. There was an all-pixel option; the founder cut
    /// it as too much, on the reasoning that a blend is what almost everyone
    /// actually wants and the third choice only made the decision harder
    /// (founder direction 2026-08-22).
    ///
    /// The raw values are the ones already on disk, so nobody's choice moves
    /// when the app updates.
    case blend, system

    var label: String {
        switch self {
        // Never "W95FA" (founder direction 2026-08-16): the file name of a
        // typeface is not what the setting is offering. The credit for the
        // face itself stays in About, where it belongs.
        //
        // `blend` answers to "Retro" now that nothing retro-er exists to claim
        // the name. The label describes what a reader gets, not how the
        // implementation mixes two faces.
        case .blend:  "Retro"
        case .system: "Modern"
        }
    }

    /// Whether text in `role` is set in the pixel face.
    func isPixel(_ role: TextRole) -> Bool {
        switch self {
        case .blend:  role == .chrome
        case .system: false
        }
    }

    /// PostScript name, verified via CoreText: family "W95FA", one Regular face.
    static let pixelPostScriptName = "W95FARegular"
}
