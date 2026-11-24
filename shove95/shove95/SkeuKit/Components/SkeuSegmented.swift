//
//  SkeuSegmented.swift
//  shove95
//
//  THE toggle of this design: a trough holding equal-width segments, of which
//  only the selected one wears glass.
//
//  It appears twice — the main screen's tab bar, and every option row in
//  settings — and the two are defined HERE rather than separately, because a
//  settings toggle that differs from the tab bar reads as a different kind of
//  control (founder direction 2026-08-14). Sharing the construction is the
//  only way that stays true as either side is edited.
//
//  Sizes are the tab bar's, resolved from the Figma frame: 148.2 × s × scaleUp
//  for the height, 41 for the label, 22 and 23.771 for the pill's padding,
//  where s = 402/1495 and scaleUp = 37/(107.444 × s). Written out as numbers
//  because SkeuKit cannot see the screen's private frame table.
//

import SwiftUI

enum SkeuToggle {
    static let height: CGFloat = 51.0
    /// Segment labels. This is the TASK text size (`F.label`, 16.4 at the
    /// design step) rather than a figure of its own: the tab bar sits directly
    /// under the list and read a shade smaller than the rows above it, which
    /// makes the bar look like a caption instead of the app's own furniture
    /// (founder direction 2026-08-17).
    static let label: CGFloat = 16.4
    /// Pill padding — horizontal is deliberately tight: four labels have to
    /// share a phone width and "Tomorrow" is the longest word in the app.
    static let padH: CGFloat = 7.6
    static let padV: CGFloat = 8.2
    /// Trough inset — and it IS `padV`, not a figure of its own.
    ///
    /// It was 15.8, the average of the frame's uneven 24.6 leading and 7.1
    /// trailing. But `padV` is what sets the gap above and below the selected
    /// pill, so taking a different number at the ends left the sides at nearly
    /// twice the top and bottom, and the glass read as floating in a wide slot
    /// instead of seated in a channel (founder direction 2026-08-16).
    ///
    /// Derived rather than copied so the four gaps around a pill cannot drift
    /// apart again — the same reason the settings field rows read their
    /// heights from here.
    static var troughPad: CGFloat { padV }
    static let bloomOverhang: CGFloat = 5.3
    static let bloomBlur: CGFloat = 1.85
    /// Between segments. Invisible on a row of labels, where only one segment
    /// is ever drawn — it earns its keep on the theme row, where all five
    /// carry a colour and butted-up capsules read as one striped bar rather
    /// than five pills.
    static let gap: CGFloat = 3

    /// How far a colour sits inside its glass panel. Small — the colour is
    /// still the thing you see — but enough that the rim reads as a frame
    /// around it rather than a highlight across it.
    static let swatchInset: CGFloat = 5.5

}

// MARK: - The trough

/// Holds a row of `SkeuSegment`s.
struct SkeuSegmentedTrough<Content: View>: View {
    @Environment(\.skeu) private var skeu
    @Environment(\.skeuChromeScale) private var chromeScale
    @ViewBuilder var content: Content

    var body: some View {
        let height = SkeuToggle.height * chromeScale

        HStack(spacing: SkeuToggle.gap * chromeScale) {
            content
        }
        .padding(.horizontal, SkeuToggle.troughPad * chromeScale)
        .frame(maxWidth: .infinity)
        .frame(height: height)
        .skeuTrough(Capsule(), height: height)
        // The soft bloom that seats the trough in the ground: light over dark,
        // opposite the trough's own fill, so the bar sits in a shallow dish
        // rather than on flat paint.
        //
        // The lit stop is `materialTop`, not `recessBottom`. `recessBottom` is
        // `base × 0.955` and so is `canvas` — the two are the same brightness,
        // so the top of this bloom was drawn in exactly the tone behind it and
        // the OUTER top edge of every trough had no lift at all. Only the dark
        // half showed, which reads as a shadow under the bar rather than a
        // dish it sits in (founder bug report 2026-08-16).
        .background {
            Capsule()
                .fill(LinearGradient(colors: [skeu.materialTop, skeu.recess],
                                     startPoint: .top, endPoint: .bottom))
                .padding(-SkeuToggle.bloomOverhang * chromeScale)
                .blur(radius: SkeuToggle.bloomBlur)
                // Left un-rasterised: the overhang puts this bloom OUTSIDE the
                // trough's bounds on purpose, and a drawingGroup would clip it
                // back to them. See SkeuGlass.lensStack.
                .allowsHitTesting(false)
        }
    }
}

// MARK: - One segment

/// One choice inside a `SkeuSegmentedTrough`.
///
/// Every segment is laid out IDENTICALLY whether or not it is selected — same
/// font, same padding, same equal-width column — so no label can shift when
/// the selection moves. The glass is a BACKGROUND that only the selected
/// column carries, and the matched-geometry id rides on that background alone;
/// putting it on the whole label animates the text across with the pill, which
/// the founder rejected (2026-08-14).
struct SkeuSegment<Content: View>: View {
    @Environment(\.skeuChromeScale) private var chromeScale
    let isSelected: Bool
    /// Namespace and id for the gliding pill. Segments in the same row share
    /// one namespace and one id.
    var namespace: Namespace.ID
    var geometryID: String
    /// Paints the whole pill, under the glass. Used by the theme row, where
    /// the choice IS a colour and so has to fill the pill rather than sit in
    /// it as a dot (founder direction 2026-08-16).
    ///
    /// A STYLE, not a colour: silver is a gradient, and a flat fill at a
    /// neutral hue is just grey.
    var fill: AnyShapeStyle?
    @ViewBuilder var content: Content

    var body: some View {
        let height = SkeuToggle.height * chromeScale
        let pill = height - SkeuToggle.padV * chromeScale * 2

        content
            .padding(.horizontal, SkeuToggle.padH * chromeScale)
            .padding(.vertical, SkeuToggle.padV * chromeScale)
            .frame(maxWidth: .infinity)
            .background {
                ZStack {
                    if let fill {
                        // The chosen swatch fills its column; the rest are
                        // HALF as wide (founder direction 2026-08-23).
                        //
                        // This has now been decided three ways: the unchosen
                        // ones shrank, then every swatch was held at one size
                        // (2026-08-17, on the reasoning that the glass frame
                        // alone should mark the choice), and now they shrink
                        // again — by a stated half rather than by feel.
                        //
                        // The COLUMN does not move. Only the colour inside it
                        // changes width, so the row keeps its rhythm, the
                        // pill still glides between fixed stops, and every
                        // swatch keeps a full-width target to press.
                        //
                        // The inset is what leaves the selected swatch's glass
                        // rim showing AROUND the colour rather than over it
                        // (founder direction 2026-08-17).
                        GeometryReader { proxy in
                            let inset = SkeuToggle.swatchInset * chromeScale
                            let full = max(0, proxy.size.width - inset * 2)
                            Capsule()
                                .fill(fill)
                                .frame(width: isSelected ? full : full * 0.5,
                                       height: max(0, proxy.size.height - inset * 2))
                                .frame(width: proxy.size.width,
                                       height: proxy.size.height)
                        }
                    }
                    // The glass is a lens with no fill, so it goes OVER the
                    // colour — as a background layer its rim would be hidden
                    // behind it.
                    if isSelected {
                        Color.clear
                            .skeuGlass(Capsule(), height: pill)
                            .matchedGeometryEffect(id: geometryID, in: namespace)
                            // The pill already glides; without this it simply
                            // stops, and the glide read as the whole event.
                            // Swelling on arrival gives the journey an end and
                            // matches what a pressed control does.
                            .skeuLanding(isSelected, active: isSelected)
                    }
                }
            }
            .contentShape(Rectangle())
    }
}

// MARK: - Label

extension View {
    /// The type treatment every segment label shares.
    ///
    /// NOT `fixedSize`: that pins each label to its intrinsic width, so at
    /// large Dynamic Type the row exceeds the screen and pushes the whole
    /// layout off both edges. The scale floor is the last resort for
    /// accessibility sizes; at normal sizes `SkeuToggle.label` is chosen so
    /// nothing shrinks at all.
    /// `role` differs by WHERE the segment is. The tab bar is furniture, so
    /// all four labels stay pixel under Blend; a settings toggle is only
    /// furniture where it is switched on, so the caller passes `.chrome` for
    /// the active option and `.content` for the rest (founder direction
    /// 2026-08-16, which names "the currently pressed/activated toggle").
    func skeuSegmentLabel(_ textScale: CGFloat, role: TextRole = .chrome) -> some View {
        self
            .font(SkeuFont.at(SkeuToggle.label * textScale, role: role))
            .tracking(-0.02 * SkeuToggle.label)
            .lineLimit(1)
            .minimumScaleFactor(0.5)
    }
}
