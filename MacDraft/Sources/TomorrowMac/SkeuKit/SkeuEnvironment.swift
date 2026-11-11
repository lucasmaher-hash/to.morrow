//
//  SkeuEnvironment.swift
//  shove95
//
//  Environment injection (§2.6). This is the ONLY permitted way for a component
//  to read colour:
//
//      @Environment(\.skeu) private var skeu
//      Text("Hello").foregroundStyle(skeu.ink)
//
//  The look this replaced read its palette from statics and had to force
//  redraws with `.id(scheme.id)`. Going through the environment means SwiftUI
//  sees the dependency and repaints on its own — no rebuild hack anywhere.
//

import SwiftUI

extension EnvironmentValues {
    /// The active palette. Default is the shipping theme (§2.4).
    @Entry var skeu: SkeuPalette = .cream

    /// The active typeface — the one thing SkeuKit still reads from a static
    /// (`SkeuFont.face`), because `SkeuFont.at(_:)` is a free function that
    /// cannot reach the environment.
    ///
    /// This value carries no information a view uses directly. It exists so a
    /// view can DECLARE the dependency SwiftUI cannot infer: read it, and the
    /// body re-runs on a face change, picking up the new static. The
    /// alternative was `.id(face)` on the whole screen, which rebuilds the
    /// subtree and so kills any animation in flight — including the gliding
    /// pill of the very toggle you just used (founder bug report 2026-08-16).
    @Entry var skeuFace: AppFace = .system
}

extension View {
    /// Re-skins this subtree. Changing only this call must re-theme every screen
    /// correctly — that is the acceptance test for the whole system.
    func skeuTheme(_ palette: SkeuPalette) -> some View {
        environment(\.skeu, palette)
    }
}
