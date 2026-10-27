//
//  SkeuSecondaryScreens.swift
//  shove95
//
//  Archive and About in the skeu look. Both are read-mostly screens, so they
//  use the settings card as their container and keep the vocabulary already
//  established: cards for grouping, troughs for chrome, glass for controls,
//  plain text on the ground for content.
//
//  Neither screen took its structure from the version that came before — those
//  were built out of window furniture (title bar, sunken well) that has no
//  equivalent here. What IS carried over is their content and their rules: the
//  archive's day grouping and non-actionable rows, About's two licence
//  credits, which are conditions rather than courtesies.
//

import SwiftUI
import StoreKit
import Shove95Kit

private enum S {
    static let label: CGFloat = 12.8
    static let cardRadius: CGFloat = 30
    static let cardRim = 7 * (66.4 / 148.2) // 3.1 — the trough contour width
    static let cardPad: CGFloat = 21.3
    static let margin: CGFloat = 21.5
    static let pillHeight: CGFloat = 30
    /// The ✕ on these sheets. One figure for every circular control in the
    /// look — the settings gear, the sheet ✕, the photo viewer's pair — so
    /// switching between them is not a size change (founder direction
    /// 2026-08-17).
    static let closeCircle: CGFloat = SkeuTopBar.control
}

// MARK: - Shared chrome

/// Header + scrolling body, shared by both screens.
private struct SkeuSheet<Content: View>: View {
    @Environment(AppSettings.self) private var settings
    @Environment(\.skeuTextScale) private var textScale
    @Environment(\.skeuChromeScale) private var chromeScale

    // Dynamic Type (FR-015) — see SkeuTypeScale.
    private var labelSize: CGFloat { S.label * textScale }
    private var pillH: CGFloat { S.pillHeight * chromeScale }
    private var closeSize: CGFloat { S.closeCircle * chromeScale }
    @Environment(\.skeu) private var skeu
    let title: String
    var onClose: () -> Void
    @ViewBuilder var content: Content

    var body: some View {
        ZStack {
            skeu.canvas.ignoresSafeArea()

            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    // CHROME, like the Settings header — a screen's own name
                    // is the app labelling itself, so it holds the pixel face
                    // under Blend (founder bug report 2026-08-17).
                    Text(title)
                        .font(SkeuFont.title3Chrome)
                        .foregroundStyle(skeu.ink)

                    Spacer(minLength: SkeuSpace.sm)

                    // NO Button around this. A Button takes the touch before
                    // the modifier's own gesture can see it, so the ✕ closed
                    // the sheet and never swelled (founder bug report
                    // 2026-08-17). `.skeuPress` is the control.
                    SkeuChromeGlyph(kind: .close, face: settings.skeuFace,
                                    size: SkeuTopBar.icon * chromeScale,
                                    tint: skeu.ink)
                        .frame(width: closeSize, height: closeSize)
                        .skeuGlass(Circle(), height: closeSize)
                        .skeuPress { onClose() }
                        .frame(minWidth: SkeuControl.minTouch, minHeight: SkeuControl.minTouch)
                        .accessibilityAddTraits(.isButton)
                        .accessibilityLabel("Close")
                }
                .padding(.horizontal, S.margin)
                .padding(.vertical, SkeuSpace.md)

                ScrollView {
                    content
                        .padding(.horizontal, S.margin)
                        // Room for the panels' own shadows. They reach about
                        // 16pt above their frame (radius 26.8 minus offset
                        // 10.6), and the scroll view clips to its bounds — so
                        // the first card's top shading was cut straight off
                        // (founder bug report 2026-08-17). The first fix gave
                        // 12pt against a 16pt reach, which only moved the cut
                        // line (founder bug report 2026-08-25) — 20pt actually
                        // clears it.
                        .padding(.top, SkeuSpace.xl)
                        // Clears the home indicator by padding, since the
                        // scroll view now runs past the safe area — the same
                        // fix the settings sheet took (2026-08-16).
                        //
                        // The SAME clearance settings uses, no more. These
                        // three carried an extra band that read as a strip cut
                        // off the bottom of the page (founder bug report
                        // 2026-08-17).
                        .padding(.bottom, SkeuSpace.md + 34)
                }
                .scrollBounceBehavior(.always, axes: .vertical)
                .scrollIndicators(.hidden)
                // The header is docked here too, so content dissolves as it
                // passes under it — the settings sheet got this and Archive,
                // About and How to use were left without it.
                .skeuScrollEdgeFade(28 * chromeScale, edges: .top)
                // ALWAYS-ON, unlike the scroll fade above, and sized to the
                // top clearance so it ends where the first card begins. The
                // panels' wide shadow (radius 49) washes far past any padding
                // the sheet could give it, so at rest — when the scroll fade
                // is off — the wash still met the clip in a hard line
                // (founder bug report 2026-08-25). Ramping it to nothing at
                // the bound is the only thing that reads as falloff rather
                // than as a cut. Masks multiply, so stacking this under the
                // scroll fade only steepens the very top while scrolled.
                .skeuEdgeFade(top: SkeuSpace.xl * chromeScale)
                // LAST, after the fade — the order settings uses.
                //
                // The fade is a MASK, and a mask is built from the bounds of
                // the view it wraps. Reaching past the safe area first and
                // masking afterwards handed the mask the un-expanded size, so
                // the scroll view stopped a home-indicator's height short and
                // sliced the last card off along a hard line, with a dead
                // strip beneath it (founder bug report 2026-08-17, twice —
                // the first attempt changed the clearance, which was never
                // what made the cut).
                .ignoresSafeArea(.container, edges: .bottom)
            }
        }
        .swipeToDismiss(headerHeight: S.closeCircle * chromeScale
                        + SkeuSpace.md * 3,
                        // CLEAR. A canvas-coloured
                        // backdrop was standing in for the screen behind, and
                        // once the sheet started fading it out on its way off
                        // the edge, what it uncovered was the void a
                        // full-screen cover leaves (founder bug report
                        // 2026-08-17). Asking the presentation itself to be
                        // transparent shows the real screen instead.
                        backdrop: .clear, onClose)
        .presentationBackground(.clear)
    }
}

/// The settings card, reused. Kept private to this file rather than shared
/// with SkeuSettingsView: the two will drift, and a "generic card" that both
/// import is the kind of premature abstraction that ends up with six flags.
/// A block CUT INTO the page: an optional label sitting ABOVE the frame, and
/// the content in a shallow trough beneath it.
///
/// This replaced `SkeuPanel`, the raised card these screens used to be. The
/// archive went first (founder direction 2026-08-23) and How to use followed
/// (2026-09-01); About dropped its frames entirely, so nothing raised is left
/// and the old panel went with it. Both remaining screens share THIS type
/// rather than each drawing their own trough, so "the same as the archive"
/// stays true rather than merely starting out true.
///
/// Why a trough. These are read-only screens — records filed away, gestures
/// looked up — and a recess says "filed" where a raised card says "act on me".
/// It is also what made them cheap: a raised panel carried two blurred
/// shadows, radius 26.8 and 49, per frame and none of them baked, while a
/// trough's inner shadows are rasterised once (see InnerShadow).
private struct SkeuWell<Content: View>: View {
    @Environment(\.skeuTextScale) private var textScale
    @Environment(\.skeu) private var skeu
    var title: String?
    /// A HEADING rather than an eyebrow: bigger, bolder and in full ink.
    ///
    /// The archive's dates are captions for a frame full of records, so they
    /// stay faint and small. How to use has only three frames and the words
    /// above them are the screen's structure, which is a different job
    /// (founder direction 2026-09-01).
    var prominentTitle: Bool = false
    @ViewBuilder var content: Content

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: S.cardRadius, style: .continuous)

        VStack(alignment: .leading, spacing: SkeuSpace.sm) {
            if let title {
                // A LABEL for the frame, so it sits above rather than inside.
                Text(title)
                    .font(prominentTitle
                          ? SkeuFont.at(S.label * textScale * 1.3, weight: .bold)
                          : SkeuFont.eyebrow)
                    .textCase(.uppercase)
                    .tracking(0.8)
                    .foregroundStyle(prominentTitle ? skeu.ink : skeu.inkFaint)
                    .padding(.leading, SkeuSpace.sm)
            }

            content
                .padding(S.cardPad)
                .frame(maxWidth: .infinity, alignment: .leading)
                // SHALLOWER than the live box, which the founder asked for by
                // name: the ramp finishes sooner, the shade runs at under half
                // weight and the floor is lifted further. A well holding a few
                // lines of text should read as a recess, not as a pit.
                .skeuTrough(shape, height: 56, fillStop: 0.20, shadeScale: 0.42,
                            fillLift: 0.70)
        }
    }
}

// MARK: - Archive

struct SkeuArchiveView: View {
    @Environment(\.skeuTextScale) private var textScale
    @Environment(\.skeuChromeScale) private var chromeScale

    // Dynamic Type (FR-015) — see SkeuTypeScale.
    private var labelSize: CGFloat { S.label * textScale }
    private var pillH: CGFloat { S.pillHeight * chromeScale }
    private var closeSize: CGFloat { S.closeCircle * chromeScale }
    @Environment(\.skeu) private var skeu
    @Environment(TaskStore.self) private var store
    var onClose: () -> Void

    var body: some View {
        SkeuSheet(title: "Archive", onClose: onClose) {
            let days = store.archivedTasksByDay()

            if days.isEmpty {
                Text("(empty)")
                    .font(SkeuFont.at(labelSize))
                    .foregroundStyle(skeu.inkFaint)
                    .frame(maxWidth: .infinity, minHeight: 160)
            } else {
                // Newest day first; the day itself is the only grouping.
                LazyVStack(alignment: .leading, spacing: SkeuSpace.lg) {
                    ForEach(days, id: \.day) { group in
                        day(group)
                    }
                }
            }
        }
    }

    /// One day's block: the date ABOVE the frame, and the tasks cut into the
    /// page below it (founder direction 2026-08-23). The trough itself lives
    /// in `SkeuWell`, which How to use now shares — see its note.
    @ViewBuilder
    private func day(_ group: (day: Date, tasks: [TaskItem])) -> some View {
        SkeuWell(title: group.day.formatted(
            .dateTime.weekday(.abbreviated).day().month(.abbreviated))) {
            VStack(spacing: SkeuSpace.sm) {
                ForEach(group.tasks, id: \.id) { task in
                    row(task)
                }
            }
        }
    }

    private func row(_ task: TaskItem) -> some View {
        HStack(spacing: SkeuSpace.sm) {
            // Struck through and muted, exactly as it looked the moment it
            // left the list — no live checkbox, nothing here is actionable.
            Text(task.title)
                .font(SkeuFont.at(labelSize))
                .strikethrough(color: skeu.inkFaint)
                .foregroundStyle(skeu.inkMuted)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)

            Text("Delete")
                .font(SkeuFont.at(labelSize * 0.9, weight: .medium))
                .foregroundStyle(skeu.critical)
                .lineLimit(1)
                .padding(.horizontal, SkeuSpace.md)
                .frame(height: pillH)
                .skeuGlass(Capsule(), height: pillH)
                .contentShape(Capsule())
                .onTapGesture {
                    SkeuHaptic.warning()
                    withAnimation(SkeuMotion.layout) { store.delete(task) }
                }
                .accessibilityLabel("Delete \(task.title) from the archive")
        }
        .frame(minHeight: SkeuControl.minTouch)
    }
}

// MARK: - About

struct SkeuAboutView: View {
    @Environment(\.skeuTextScale) private var textScale
    @Environment(\.skeuChromeScale) private var chromeScale

    // Dynamic Type (FR-015) — see SkeuTypeScale.
    private var labelSize: CGFloat { S.label * textScale }
    private var pillH: CGFloat { S.pillHeight * chromeScale }
    private var closeSize: CGFloat { S.closeCircle * chromeScale }
    @Environment(\.skeu) private var skeu
    @Environment(\.openURL) private var openURL
    /// See AboutView: the system prompt, which Apple rate-limits.
    @Environment(\.requestReview) private var requestReview
    var onClose: () -> Void

    /// Published alongside the App Store listing.
    private static let privacyPolicyURL =
        URL(string: "https://lucasmaher-hash.github.io/to.morrow/privacy.html")!

    var body: some View {
        SkeuSheet(title: "About", onClose: onClose) {
            // NO panels here (founder direction 2026-09-01). About is the one
            // screen with nothing to group — a name, a version, two licence
            // lines — so the raised card was drawing a boundary around text
            // that needed none. The words sit on the canvas instead; the
            // section heading, which the panel used to supply, stays.
            VStack(alignment: .leading, spacing: SkeuSpace.lg) {
                VStack(alignment: .leading, spacing: SkeuSpace.sm) {
                    Text("to.morrow")
                        .font(SkeuFont.display)
                        .foregroundStyle(skeu.ink)

                    Text("Version \(version) (\(build))")
                        .font(SkeuFont.at(labelSize))
                        .foregroundStyle(skeu.inkMuted)

                    Text("Four tabs. One swipe moves a task between them.")
                        .font(SkeuFont.at(labelSize))
                        .foregroundStyle(skeu.inkMuted)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.top, SkeuSpace.xs)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                // The eyebrow the panel used to draw, kept verbatim so the
                // credits still announce themselves as a section.
                VStack(alignment: .leading, spacing: SkeuSpace.sm) {
                    Text("Credits")
                        .font(SkeuFont.eyebrow)
                        .textCase(.uppercase)
                        .tracking(0.8)
                        .foregroundStyle(skeu.inkFaint)

                    VStack(alignment: .leading, spacing: SkeuSpace.md) {
                        // A licence condition, not a courtesy: W95FA ships
                        // under the SIL OFL, which requires the attribution.
                        // The font is still bundled and still what "Retro"
                        // selects, so this stays even though the Windows 95
                        // chrome around it does not.
                        //
                        // The Microsoft non-affiliation line that used to sit
                        // here went with that chrome (founder direction
                        // 2026-09-01): nothing in the app imitates Windows 95
                        // any more, so it was disclaiming a resemblance that
                        // no longer exists.
                        Text("Typeface: W95FA by Alina Sava (SIL OFL)")
                            .font(SkeuFont.at(labelSize))
                            .foregroundStyle(skeu.inkMuted)
                            .fixedSize(horizontal: false, vertical: true)

                        // Same pill as Privacy policy below it — one glass
                        // control, two errands. These two stay raised: they
                        // are controls, and a tappable thing that looks like
                        // the prose around it is not tappable-looking at all.
                        Text("Rate the app")
                            .font(SkeuFont.at(labelSize, weight: .medium))
                            .foregroundStyle(skeu.ink)
                            .padding(.horizontal, SkeuSpace.lg)
                            .frame(height: 38)
                            .skeuGlass(Capsule(), height: 38)
                            .frame(minHeight: SkeuControl.minTouch)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                SkeuHaptic.press()
                                requestReview()
                            }
                            .accessibilityAddTraits(.isButton)
                            .padding(.top, SkeuSpace.sm)

                        Text("Privacy policy")
                            .font(SkeuFont.at(labelSize, weight: .medium))
                            .foregroundStyle(skeu.ink)
                            .padding(.horizontal, SkeuSpace.lg)
                            .frame(height: 38)
                            .skeuGlass(Capsule(), height: 38)
                            // Glass pill stays 38; the target is 44.
                            .frame(minHeight: SkeuControl.minTouch)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                SkeuHaptic.press()
                                openURL(Self.privacyPolicyURL)
                            }
                            .accessibilityAddTraits(.isLink)
                            .padding(.top, SkeuSpace.xs)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                Text("© \(year) Lucas Maher")
                    .font(SkeuFont.at(labelSize))
                    .foregroundStyle(skeu.inkFaint)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    private var version: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    }

    private var build: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
    }

    private var year: String {
        Calendar.current.component(.year, from: .now).formatted(.number.grouping(.never))
    }
}

// MARK: - How to use

/// The gestures, listed. Content comes from `HowTo`, which is what kept this
/// screen and the walkthrough from saying different things.
struct SkeuHowToView: View {
    @Environment(\.skeuTextScale) private var textScale
    @Environment(\.skeuChromeScale) private var chromeScale

    private var labelSize: CGFloat { S.label * textScale }
    @Environment(\.skeu) private var skeu
    @Environment(TaskStore.self) private var store
    var onClose: () -> Void

    var body: some View {
        SkeuSheet(title: "How to use", onClose: onClose) {
            LazyVStack(alignment: .leading, spacing: SkeuSpace.lg) {
                // THREE, evenly spaced. The old screen put an extra gap
                // between the essentials and the lookup below them, because
                // the two halves did different jobs. There is no lookup half
                // any more — three blocks, all the same weight — so the odd
                // gap went with it and the stack's own `lg` spacing runs the
                // whole way down (founder direction 2026-09-01).
                ForEach(HowTo.blocks) { block in
                    SkeuWell(title: block.title, prominentTitle: true) {
                        // Half again on the gap under the picture (founder
                        // direction 2026-09-01): two of the three pictures now
                        // MOVE, and a caption sitting as close to a moving
                        // thing as it would to a static glyph reads as part of
                        // it rather than as a line about it.
                        VStack(alignment: .leading, spacing: SkeuSpace.md * 1.5) {
                            // The picture at the TOP, inside the frame. Two of
                            // the three are the live control itself; the third
                            // is still a pictogram, and larger than the row
                            // glyphs it replaces — with three on the screen it
                            // can afford the size.
                            art(block.art)

                            Text(block.body)
                                .font(SkeuFont.at(labelSize))
                                .foregroundStyle(skeu.inkMuted)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func art(_ art: HowTo.Art) -> some View {
        switch art {
        case .glyph(let glyph):
            HowToGlyph(glyph: glyph, tint: skeu.inkMuted, size: 36 * chromeScale)
        case .liveTab:
            SkeuGoLiveDemo()
        case .workspacePill:
            SkeuWorkspacePillDemo(names: workspaceNames)
        case .swipeRows:
            // Left FIRST, then right (founder direction 2026-09-01). Note the
            // paragraph below names them the other way round — worth keeping
            // an eye on if either is ever reworded.
            // BOUNDED, the way the screen edge bounds a real swipe. The rows
            // travel their whole width to leave; clipping them at the card's
            // padding is what makes them read as going off the list rather
            // than as drawing over the page.
            SkeuSwipeSequenceDemo()
                .clipShape(RoundedRectangle(cornerRadius: SkeuRadius.md,
                                            style: .continuous))
        }
    }

    /// The reader's OWN two workspaces where there are two, so the pill in the
    /// picture carries the names they will actually see. A single workspace
    /// has nothing to switch between, so the demonstration borrows the two
    /// names the app ships with rather than showing a pill that cannot open.
    private var workspaceNames: [String] {
        let names = store.workspaces().map(\.name).filter { !$0.isEmpty }
        return names.count >= 2 ? Array(names.prefix(2)) : ["Personal", "Work"]
    }

}
