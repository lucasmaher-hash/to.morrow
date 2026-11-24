//
//  SkeuBezelBar.swift
//  shove95
//
//  The signature component, transcribed from the founder's reworked Figma file
//  (node 2:283). This becomes the bottom tab bar; it is built generically here
//  so the scaffold and the real screen share one implementation.
//
//  Two parts, and the relationship between them is the whole idea:
//
//    THE TROUGH  a channel cut through the material (`skeuTrough`) — dark at
//                the lip, light on the floor, a hard contour around it.
//    THE LENS    the selected item, a piece of glass lying IN that channel
//                (`skeuGlass`) — no fill of its own, just thickness, a bright
//                rim and a glow from below.
//
//  Unselected items carry no surface at all, only a muted icon (§9.5).
//
//  This replaces an earlier reading of the reference that built the bar as a
//  RAISED capsule with a groove. That was wrong in the one way that mattered:
//  the bar is cut in, not laid on, and the gradient runs dark-to-light rather
//  than light-to-dark. The two look similar in a thumbnail and nothing alike
//  on a device.
//

import SwiftUI

struct SkeuBarItem: Identifiable, Hashable {
    let id: String
    var title: String?
    var systemImage: String?

    init(id: String, title: String? = nil, systemImage: String? = nil) {
        self.id = id
        self.title = title
        self.systemImage = systemImage
    }
}

struct SkeuBezelBar: View {
    @Environment(\.skeu) private var skeu
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Namespace private var namespace

    let items: [SkeuBarItem]
    @Binding var selection: String
    /// Equal columns, as a tab bar wants. Off lets each item take the width it
    /// needs — an icon row with one labelled item cannot share evenly, and
    /// forcing it wraps the label.
    var equalWidths: Bool = true

    /// 134pt in the reference; 56 is the phone-scale equivalent and the value
    /// §9.5 already specifies.
    private let barHeight: CGFloat = 56
    private let lensHeight: CGFloat = 44
    /// 18.64pt of the reference's 134 → 7.8 here.
    private let padding: CGFloat = 8

    var body: some View {
        HStack(spacing: SkeuSpace.xxs) {
            if !equalWidths { Spacer(minLength: 0) }
            ForEach(items) { item in
                Button {
                    SkeuHaptic.selection()
                    withAnimation(reduceMotion ? SkeuMotion.tint : SkeuMotion.press) {
                        selection = item.id
                    }
                } label: {
                    label(for: item)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(item.title ?? item.id)
                .accessibilityAddTraits(
                    item.id == selection ? [.isButton, .isSelected] : .isButton)
            }
        }
        .padding(.horizontal, padding)
        .frame(height: barHeight)
        .skeuTrough(Capsule(), height: barHeight)
    }

    @ViewBuilder
    private func label(for item: SkeuBarItem) -> some View {
        let isSelected = item.id == selection

        HStack(spacing: SkeuSpace.sm) {
            if let symbol = item.systemImage {
                // §10: icons never carry depth of their own — the lens does.
                Image(systemName: symbol)
                    .font(.system(size: 17, weight: .medium))
                    .symbolRenderingMode(.hierarchical)
            }
            if let title = item.title {
                Text(title)
                    .font(SkeuFont.bodyEmph)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
        }
        // Ink stays light on both: the label sits on glass over a shaded
        // channel, not on material.
        .foregroundStyle(isSelected ? skeu.ink : skeu.inkMuted)
        .frame(height: lensHeight)
        .frame(maxWidth: equalWidths ? .infinity : nil)
        .padding(.horizontal, SkeuSpace.md)
        .background {
            if isSelected {
                Color.clear
                    .skeuGlass(Capsule(), height: lensHeight)
                    .matchedGeometryEffect(id: "selection", in: namespace)
            }
        }
        .contentShape(Capsule())
    }
}
