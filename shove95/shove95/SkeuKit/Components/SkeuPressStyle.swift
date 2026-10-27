//
//  SkeuPressStyle.swift
//  shove95
//
//  The canonical press interaction (§8.3). Law 5: pressing COSTS depth — the
//  object shrinks slightly, drops one rung down the ladder, and darkens a
//  touch. A press that only changes opacity is rejected on sight.
//
//  Reduce Motion (§8.5) removes the SCALE but keeps the depth change: the depth
//  change is the affordance, not decoration.
//

import SwiftUI

struct SkeuPressStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    var radius: CGFloat = SkeuRadius.md
    var depth: SkeuDepth = .raised
    var tint: Color? = nil
    var sheen: Bool = true

    func makeBody(configuration: Configuration) -> some View {
        let pressed = configuration.isPressed
        return configuration.label
            .skeuSurface(skeuShape(radius),
                         depth: pressed ? depth.pressed : depth,
                         tint: tint,
                         sheen: sheen && !pressed)
            .scaleEffect(reduceMotion ? 1.0 : (pressed ? 0.97 : 1.0))
            .brightness(pressed ? -0.03 : 0)
            .animation(reduceMotion ? SkeuMotion.tint : SkeuMotion.press, value: pressed)
    }
}

/// A press treatment for rows and tiles that are not `Button`s — the same
/// physics, driven by a bool the caller already owns.
struct SkeuPressed: ViewModifier {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let isPressed: Bool
    var radius: CGFloat = SkeuRadius.md
    var depth: SkeuDepth = .raised
    var tint: Color? = nil

    func body(content: Content) -> some View {
        content
            .skeuSurface(skeuShape(radius),
                         depth: isPressed ? depth.pressed : depth,
                         tint: tint,
                         sheen: !isPressed)
            .scaleEffect(reduceMotion ? 1.0 : (isPressed ? 0.97 : 1.0))
            .brightness(isPressed ? -0.03 : 0)
            .animation(reduceMotion ? SkeuMotion.tint : SkeuMotion.press, value: isPressed)
    }
}
