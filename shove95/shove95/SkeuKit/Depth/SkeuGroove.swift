//
//  SkeuGroove.swift
//  shove95
//
//  A groove is a thin channel cut just inside a raised surface — the detail
//  that makes a bezel read as a moulded frame rather than a coloured rectangle.
//
//  Its lighting is INVERTED against the object carrying it: dark on the top and
//  leading edge, light on the bottom and trailing edge. That inversion is the
//  whole trick. The same light source that lifts the frame has to fall INTO the
//  channel, and a viewer reads the reversal instantly as "cut in".
//
//  Distinct from `Seam` (§4.6): a seam is decorative and single-toned, a groove
//  is structural and two-toned. A surface may carry one or the other.
//

import SwiftUI

struct SkeuGroove<S: InsettableShape>: ViewModifier {
    @Environment(\.skeu) private var skeu
    let shape: S
    var inset: CGFloat = 6
    var width: CGFloat = 1
    /// Scales both tones together, for frames that want a whisper of a channel.
    var strength: Double = 1

    func body(content: Content) -> some View {
        content.overlay {
            let channel = shape.inset(by: inset)
            ZStack {
                // The near wall, in shade.
                channel.stroke(
                    LinearGradient(
                        stops: [.init(color: skeu.edgeShade.opacity(0.55 * strength), location: 0),
                                .init(color: .clear, location: 0.55)],
                        startPoint: .topLeading, endPoint: .bottomTrailing),
                    lineWidth: width)

                // The far wall, catching the light.
                channel.stroke(
                    LinearGradient(
                        stops: [.init(color: .clear, location: 0.45),
                                .init(color: skeu.edgeLight.opacity(0.60 * strength), location: 1)],
                        startPoint: .topLeading, endPoint: .bottomTrailing),
                    lineWidth: width)
            }
            .allowsHitTesting(false)
        }
    }
}

extension View {
    /// Cuts a channel just inside `shape`. Pass the SAME shape the surface uses;
    /// the inset is applied here so the two stay concentric.
    func skeuGroove<S: InsettableShape>(_ shape: S,
                                        inset: CGFloat = 6,
                                        width: CGFloat = 1,
                                        strength: Double = 1) -> some View {
        modifier(SkeuGroove(shape: shape, inset: inset, width: width, strength: strength))
    }
}
