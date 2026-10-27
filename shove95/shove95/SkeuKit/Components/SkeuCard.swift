//
//  SkeuCard.swift
//  shove95
//
//  The slab the bars sit in — transcribed from the main-screen frame
//  (shove95 file, node 2:376 / 2:324). Stated at that frame's 250pt card
//  height and expressed as fractions of it, so it scales with `height`.
//
//    fill      material
//    rim       10/250 of white, solid, the whole way round. Not a rim LIGHT —
//              an actual white border. It is the brightest thing on the screen
//              and the reason the card reads as a lit object.
//    inner     inset 30.93 / -38.14 blur 58.55 black 0.25 — from the top-right,
//              throwing the bottom-left of the card into shade.
//    outer     a long soft fall down and to the LEFT, opposite the key light.
//
//  Radius is 123.26/250 ≈ 0.493 of the height — just short of a capsule, which
//  is why it reads as a slab with very round ends rather than a pill.
//

import SwiftUI

struct SkeuCard<Content: View>: View {
    @Environment(\.skeu) private var skeu
    var height: CGFloat = 67
    @ViewBuilder var content: Content

    private var k: CGFloat { height / 250 }
    private var shape: RoundedRectangle {
        RoundedRectangle(cornerRadius: 123.262 * k, style: .continuous)
    }

    var body: some View {
        content
            .frame(maxWidth: .infinity, alignment: .leading)
            .frame(height: height)
            .background { shape.fill(skeu.material) }
            .innerShadow(shape, color: shadow(0.25), radius: 58.553 * k,
                         offset: CGSize(width: 30.926 * k, height: -38.142 * k))
            .overlay { shape.strokeBorder(skeu.edgeLight, lineWidth: 10 * k) }
            .clipShape(shape)
            .shadow(color: shadow(0.19), radius: 68.037 * k,
                    x: -16.494 * k, y: 26.802 * k)
            .shadow(color: shadow(0.16), radius: 123.703 * k,
                    x: -63.913 * k, y: 106.179 * k)
    }

    private func shadow(_ alpha: Double) -> Color {
        skeu.shadow.opacity(alpha * skeu.shadowIntensity)
    }
}
