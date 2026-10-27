//
//  SkeuGlassBakery.swift
//  shove95
//
//  The glass lens stack, rendered once and reused — the old trick, applied to
//  a new toolkit.
//
//  Skeuomorphic interfaces were never slow. The iOS that looked like this
//  drew leather and felt and brushed steel on hardware a fraction of what a
//  phone has now, and it did it at sixty frames a second, because none of it
//  was being COMPUTED while you scrolled. It was pictures. The chip copied a
//  texture into place and moved on (founder direction 2026-08-22).
//
//  What was expensive here was never the drawing — a device trace put the GPU
//  at 5% of its budget. It was the BUILDING: five concentric shapes, five
//  padding pairs, a Gaussian blur and a gradient, constructed and diffed for
//  every glass object on screen, on every update. SwiftUI's cost there is
//  generic-metadata lookup and tree comparison, and the profile showed exactly
//  that — `getGenericMetadata`, `initializeWithCopy`, `AGGraph` compares.
//
//  An Image is ONE node. That is the whole idea.
//
//  Keyed on everything the picture depends on and nothing else: the shape, the
//  size it is drawn at, whether it is prominent, and the palette. Content is
//  deliberately absent from the key — the lens stack never depended on what
//  sits inside it, which is precisely why it can be baked at all.
//

import SwiftUI

@MainActor
enum SkeuGlassBakery {
    /// The picture depends on these and nothing else.
    private struct Key: Hashable {
        let shape: String
        let width: Int
        let height: Int
        let prominent: Bool
    }

    private static var cache: [Key: Image] = [:]
    /// One palette is live at a time, so the cache is generational rather than
    /// keyed by theme: when the palette changes, every picture in it is stale
    /// at once and the cheapest thing to do is drop the lot.
    private static var bakedFor: SkeuPalette?

    /// How far the blur is allowed to spread past the frame before being
    /// clipped. Rendering at exactly the frame size is what cut the highlight
    /// off square at the rim (founder bug report 2026-08-16) — the note in
    /// SkeuGlass refusing `drawingGroup` is about this. Baking with room
    /// around it reproduces the un-rasterised result instead of arguing
    /// with it.
    static func bleed(k: CGFloat) -> CGFloat { ceil(3.281 * k * 3) }

    /// The baked lens stack, or nil if it could not be rendered — callers fall
    /// back to building it live, so a failure here costs speed and never
    /// correctness.
    static func background<S: InsettableShape>(
        shape: S,
        size: CGSize,
        k: CGFloat,
        prominent: Bool,
        skeu: SkeuPalette
    ) -> Image? {
        guard size.width > 0, size.height > 0,
              size.width.isFinite, size.height.isFinite else { return nil }

        if bakedFor != skeu {
            cache.removeAll()
            bakedFor = skeu
        }

        let pad = bleed(k: k)
        let key = Key(shape: String(describing: shape),
                      width: Int((size.width + pad * 2).rounded()),
                      height: Int((size.height + pad * 2).rounded()),
                      prominent: prominent)
        if let hit = cache[key] { return hit }

        let renderer = ImageRenderer(
            content: SkeuGlassBackground(shape: shape, k: k, prominent: prominent)
                .environment(\.skeu, skeu)
                .frame(width: size.width, height: size.height)
                .padding(pad)
        )
        // The CURRENT trait collection, not `UIScreen.main` — that was
        // deprecated in iOS 26 (the app's deployment target) and was always
        // the wrong question to ask on a device that can drive a second
        // display. The trait carries the scale of whatever this view is
        // actually being drawn on.
        renderer.scale = UITraitCollection.current.displayScale
        // Opaque would fill the transparent ground black; the lens stack is
        // almost entirely alpha.
        renderer.isOpaque = false
        guard let rendered = renderer.uiImage else { return nil }

        let image = Image(uiImage: rendered)
        cache[key] = image
        return image
    }
}

/// The lens stack and its glow, as a view of its own so the same code can be
/// drawn live or handed to the renderer above. Nothing in here reads the
/// content it will sit behind — that is what makes it bakeable.
struct SkeuGlassBackground<S: InsettableShape>: View {
    @Environment(\.skeu) private var skeu
    let shape: S
    let k: CGFloat
    var prominent: Bool = true

    /// The five lens insets, (vertical, horizontal), in frame units.
    private let lenses: [(v: CGFloat, h: CGFloat)] = [
        (0, 0), (2.46, 1.70), (7.39, 5.09), (15.59, 10.74), (31.99, 22.03),
    ]

    var body: some View {
        ZStack {
            lensStack
            if prominent { glow }
            if shadesInward { innerRelief }
        }
    }

    /// Whether this piece carries the light-mode relief: a prominent one, on a
    /// light page.
    private var shadesInward: Bool { !skeu.isDark && prominent }

    /// The inside of the piece: lit at the top, shaded at the bottom, and
    /// drawn in at the sides.
    ///
    /// It lives HERE, in the baked half, and not as an overlay on the live
    /// one. The side layer is a blurred stroke, and a blur per glass piece per
    /// frame is exactly the bill the whole bakery exists to stop paying — the
    /// app has forty-odd of these on a full screen. Baked, it is drawn once
    /// per shape, size and palette and then blitted.
    ///
    /// Being baked also puts it UNDER the label rather than over it, which is
    /// where a material belongs.
    ///
    /// TWO layers, because they answer to different axes and the founder tuned
    /// them separately (2026-08-23):
    ///
    ///   - The vertical one is the bevel. On a light page the lit rim has
    ///     nowhere brighter to go, so a prominent piece was a pale shape on a
    ///     pale page; this gives it an actual lit band at the top and a shade
    ///     rising to the bottom edge.
    ///   - The horizontal one is a ring, masked to the left and right, so it
    ///     draws the sides in without adding to the bevel it sits over.
    ///
    /// The figures are the founder's, arrived at over five passes. The RIM is
    /// not part of this: it is the frame round the piece and stays live.
    private var innerRelief: some View {
        ZStack {
            shape
                .fill(LinearGradient(
                    stops: [.init(color: skeu.edgeLight.opacity(0.392), location: 0.00),
                            .init(color: skeu.edgeLight.opacity(0.123), location: 0.14),
                            .init(color: .clear, location: 0.34),
                            .init(color: .clear, location: 0.60),
                            .init(color: skeu.edgeShade.opacity(0.102), location: 0.80),
                            .init(color: skeu.edgeShade.opacity(0.24), location: 1.00)],
                    startPoint: .top, endPoint: .bottom))

            shape
                .strokeBorder(skeu.edgeShade.opacity(0.128), lineWidth: 13 * k)
                .blur(radius: 9 * k)
                .mask {
                    LinearGradient(
                        stops: [.init(color: .black, location: 0.00),
                                .init(color: .clear, location: 0.30),
                                .init(color: .clear, location: 0.70),
                                .init(color: .black, location: 1.00)],
                        startPoint: .leading, endPoint: .trailing)
                }
                .clipShape(shape)
        }
        .allowsHitTesting(false)
    }

    /// Five concentric layers at 1% white each. Thickness, not a highlight.
    private var lensStack: some View {
        ZStack {
            ForEach(Array(lenses.enumerated()), id: \.offset) { _, inset in
                shape
                    .fill(.white.opacity(0.01))
                    .padding(.vertical, inset.v * k)
                    .padding(.horizontal, inset.h * k)
            }
        }
        .blur(radius: 3.281 * k)
        .allowsHitTesting(false)
    }

    /// Rises from below the bottom edge; additive, so it lifts the material
    /// underneath without staining it.
    private var glow: some View {
        shape.fill(
            EllipticalGradient(
                stops: [.init(color: .white.opacity(0.50), location: 0.0),
                        .init(color: .white.opacity(0.00), location: 1.0)],
                center: UnitPoint(x: 0.5, y: 1.20),
                startRadiusFraction: 0,
                endRadiusFraction: 0.62)
        )
        .blendMode(.plusLighter)
        .allowsHitTesting(false)
    }
}
