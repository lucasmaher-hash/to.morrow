//
//  SkeuSettingsView.swift
//  shove95
//
//  Settings.
//
//  Construction transcribed from the founder's menu study (shove95 file, node
//  2:182, the "Dashboard / Projects 10 / Account / Support" card):
//
//    CARD    a raised sheet: material fill, white rim (7.69 at frame scale),
//            soft shadows falling down-left. ONE CARD PER SETTING — the founder
//            was explicit (2026-08-13) that each setting is its own panel, not
//            sections sharing a sheet. The frame also carries a leather texture
//            and two glow blobs — the texture is out (hard rule: no texture
//            assets; depth from light only), the glows are approximated by a
//            diagonal gradient on the fill.
//    TROUGH  inside each card, the same channel the bars use — gradient,
//            contour, four inner shadows — holding that setting's options.
//    OPTION  a glass pill. Selected = prominent (bright rim, glow, ink label).
//            Resting = subdued (half rim, no glow, muted label) — nodes 1:87
//            vs 1:101.
//
//  Scale: the frame draws its pill text at 27.692 where the phone wants 12.8,
//  so every transcribed value is × 0.4622.
//

import SwiftUI
import Shove95Kit

private enum G {
    static let q: CGFloat = 12.8 / 27.692   // 0.4622 — the frame-to-phone scale

    /// Between one setting and the next — i.e. the air ABOVE each heading.
    /// Raised from the transcribed 21.3 (founder direction 2026-08-16): with
    /// the outer cards gone, that figure was doing two jobs it used to share
    /// with a card edge, and seven settings ran together as one column.
    static let sectionGap: CGFloat = 44

    /// Heading → the control it labels. Raised from `SkeuSpace.sm` (12),
    /// which read tight under this heading's line box; 16 lands the two side
    /// by side (founder direction 2026-08-17).
    static let headingGap: CGFloat = 16

    static let pillPadH = 36.923 * q        // 17.1
    static let pillHeight: CGFloat = 38     // 12.8 text + 2 × 11.4, rounded
    static let label: CGFloat = 12.8

    /// Input rows are the TOGGLE, taken apart: the field is the toggle's
    /// trough and the button beside it is the toggle's inner pill (founder
    /// direction 2026-08-16). Read from `SkeuToggle` rather than copied, so
    /// the two families cannot drift apart the way they already did once.
    static let fieldHeight = SkeuToggle.height
    static let rowButtonH = SkeuToggle.height - SkeuToggle.padV * 2

    /// The width of a button standing BESIDE a field. Fixed, not intrinsic:
    /// Default, Delete and Add stack in one column down the sheet, and three
    /// different widths there read as three different kinds of control.
    /// Sized for "Default", the longest of the three.
    static let rowButtonW: CGFloat = 88

    /// How far a panel dissolves as it passes under the docked header. Matches
    /// the home screen's bars — see `F.edgeFade` there.
    static let edgeFade: CGFloat = 28

    /// Room under the last panel for the home indicator, now that the scroll
    /// view runs past the safe area to the physical bottom edge.
    static let bottomClearance: CGFloat = 34
}

struct SkeuSettingsView: View {
    @Environment(\.skeuTextScale) private var textScale
    @Environment(\.skeuChromeScale) private var chromeScale

    // Dynamic Type (FR-015): text on the full curve, chrome at half. Without
    // this the eyebrow headings scaled (they use SkeuFont tokens) while every
    // field label stayed fixed — giant titles over tiny controls.
    private var labelSize: CGFloat { G.label * textScale }
    private var fieldH: CGFloat { G.fieldHeight * chromeScale }
    private var pillH: CGFloat { G.pillHeight * chromeScale }
    // No `\.skeuFace` here: this view observes AppSettings, so a face change
    // already re-runs its body. Only the leaf views below, which don't, need
    // to declare that dependency.
    @Environment(\.skeu) private var skeu
    @Environment(AppSettings.self) private var settings
    @Environment(TaskStore.self) private var store
    @Environment(SyncStatus.self) private var sync
    @State private var showArchive = false
    @State private var showAbout = false
    @State private var showHowTo = false
    /// The workspace waiting on a yes. Its tasks are not destroyed either way
    /// — they fold into the default — but the label is gone for good.
    @State private var pendingDelete: Workspace?
    /// The tab whose menu is open, if any.
    @State private var timeRulesFor: Bucket?
    @State private var newWorkspace = ""
    @FocusState private var addWorkspaceFocused: Bool
    // One namespace per toggle row: the gliding pill must travel WITHIN its
    // own row, and a shared namespace would let it fly between panels.
    @Namespace private var themeNS
    @Namespace private var faceNS
    @Namespace private var designNS
    @Namespace private var appearanceNS
    var onClose: () -> Void

    var body: some View {
        ZStack {
            skeu.canvas.ignoresSafeArea()

            // The header is a SIBLING of the scroll view, not its first row:
            // it stays put and only the contents travel (founder direction
            // 2026-08-16). Scrolled inside, the title and the ✕ rode up under
            // the status bar and the first panel collided with the clock.
            VStack(alignment: .leading, spacing: 0) {
                header
                    // Lands the ✕ on exactly the gear's y — see SkeuTopBar.
                    .padding(.top, SkeuTopBar.inset)
                    .padding(.horizontal, SkeuTopBar.margin)
                    // A band of its own. Without it the panels travel a few
                    // points under the word "Settings" and read as a collision
                    // rather than a dock.
                    .padding(.bottom, SkeuSpace.md)

                ScrollView {
                // LAZY, not a plain VStack. Seven cards, each carrying a
                // trough (four inner shadows apiece) and the selected option's
                // glass (five blurred lens layers, two additive gradients,
                // three shadows) — all of it was being rasterised on the first
                // frame, while the sheet was still sliding up. That is what
                // made the presentation stutter (founder bug report
                // 2026-08-14). Only the cards actually on screen now render.
                LazyVStack(alignment: .leading, spacing: G.sectionGap) {
                    // The "Design" row that used to sit between Typeface and
                    // Light & dark is gone: there is one look now (founder
                    // direction 2026-08-22), and a picker offering a single
                    // option is a question with no answer.
                    panel("Theme") {
                        ForEach(SkeuTheme.all) { theme in
                            swatchOption(theme,
                                         selected: settings.skeuTheme.id == theme.id,
                                         in: themeNS) {
                                settings.themeID = theme.id
                            }
                        }
                    }

                    panel("Typeface") {
                        ForEach(AppFace.allCases, id: \.self) { face in
                            option(face.label,
                                   selected: settings.skeuFace == face,
                                   in: faceNS) {
                                settings.skeuFace = face
                            }
                        }
                    }

                    panel("Light & dark") {
                        ForEach(AppearanceMode.allCases, id: \.self) { mode in
                            option(mode.label,
                                   selected: settings.appearance == mode,
                                   in: appearanceNS) {
                                settings.appearance = mode
                            }
                        }
                    }

                    tabNamesPanel
                    workspacesPanel
                    dataPanel
                }
                .padding(.horizontal, SkeuTopBar.margin) // the root's screen margin
                .padding(.top, SkeuSpace.md)
                // Clears the home indicator by PADDING rather than by stopping
                // the scroll view short — see the `ignoresSafeArea` below.
                .padding(.bottom, SkeuSpace.md + G.bottomClearance)
                }
                .scrollIndicators(.hidden)
                // A swipe puts the keyboard away rather than leaving it
                // standing over what you scrolled to.
                .scrollDismissesKeyboard(.interactively)
                // The header is docked and the panels run under it, so they
                // dissolve on the way rather than being cut — and only once
                // something has scrolled past. See SkeuEdgeFade.
                .skeuScrollEdgeFade(G.edgeFade * chromeScale, edges: .top)
                // Runs to the BOTTOM OF THE SCREEN. Stopping at the safe area
                // left a dead band under the last panel that read as a bar
                // (the same fault fixed in the well on 2026-08-04).
                // Content travels through it; the padding above is what keeps
                // the last row reachable above the home indicator.
                .ignoresSafeArea(.container, edges: .bottom)
            }
        }
        // The tab menu, over the whole sheet rather than inside a card — it
        // is a decision about the tab, not another control in the list.
        .overlay {
            if let bucket = timeRulesFor {
                SkeuTabMenu(bucket: bucket) {
                    withAnimation(SkeuMotion.layout) { timeRulesFor = nil }
                }
            }
        }
        // In from the left edge, or down from the header — see SwipeToDismiss.
        // The band covers the title AND its ✕, with the header's own padding
        // either side — measured from below the safe area.
        .swipeToDismiss(headerHeight: SkeuTopBar.inset
                        + SkeuTopBar.control * chromeScale
                        + SkeuSpace.md * 2,
                        // CLEAR. A canvas-coloured
                        // backdrop was standing in for the screen behind, and
                        // once the sheet started fading it out on its way off
                        // the edge, what it uncovered was the void a
                        // full-screen cover leaves (founder bug report
                        // 2026-08-17). Asking the presentation itself to be
                        // transparent shows the real screen instead.
                        backdrop: .clear, onClose)
        .presentationBackground(.clear)
        .fullScreenCover(isPresented: $showArchive) {
            SkeuArchiveView { showArchive = false }
        }
        .fullScreenCover(isPresented: $showAbout) {
            SkeuAboutView { showAbout = false }
        }
        .fullScreenCover(isPresented: $showHowTo) {
            SkeuHowToView { showHowTo = false }
        }
        .overlay {
            if let workspace = pendingDelete {
                SkeuPinReplaceDialog(
                    outgoing: workspace.name,
                    title: "Delete workspace",
                    message: "\u{201C}\(workspace.name)\u{201D} goes for good. Its tasks are not deleted — they move to the default workspace.",
                    confirmLabel: "Delete",
                    confirmTint: skeu.critical
                ) {
                    if settings.currentWorkspaceID == workspace.id {
                        settings.currentWorkspaceID = Workspace.defaultID
                    }
                    store.deleteWorkspace(workspace)
                    pendingDelete = nil
                } onCancel: {
                    pendingDelete = nil
                }
                .transition(.opacity)
            }
        }
        .animation(SkeuMotion.present, value: pendingDelete?.id)
    }

    // MARK: Tab names

    /// One trough per tab, each holding its field and a Default pill. The
    /// pill fades out when the name already IS the default — a control that
    /// would do nothing shouldn't invite a press.
    private var tabNamesPanel: some View {
        card("Tab names") {
            VStack(spacing: SkeuSpace.sm) {
                ForEach(Bucket.line, id: \.self) { bucket in
                    SkeuNameField(bucket: bucket) { timeRulesFor = bucket }
                }
            }
        }
    }


    /// Below Workspaces and above Data — the last thing you SET, before the
    /// section that only shows you things.
    // MARK: Workspaces

    private var workspacesPanel: some View {
        card("Workspaces") {
            VStack(spacing: SkeuSpace.sm) {
                ForEach(store.workspaces(), id: \.id) { workspace in
                    SkeuWorkspaceRow(workspace: workspace) {
                        // Asked, not done. Deleting a workspace is the second
                        // weighty question in the app, so it is put the same
                        // way the pin swap is (founder direction 2026-08-17).
                        withAnimation(SkeuMotion.present) { pendingDelete = workspace }
                    }
                }

                HStack(spacing: SkeuSpace.sm) {
                    field(text: $newWorkspace.limited(to: AppSettings.maxNameLength),
                          prompt: "New workspace",
                          focused: $addWorkspaceFocused)
                        // Return ADDS it. Dismissing the keyboard and leaving
                        // the name sitting there asks the reader to press Add
                        // for something they have already finished saying
                        // (founder direction 2026-08-17).
                        .onSubmit(addWorkspace)

                    SkeuRowButton(title: "Add") {
                        SkeuHaptic.press()
                        addWorkspace()
                    }
                }
            }
        }
    }

    private func addWorkspace() {
        // See SettingsView.add(): a refused name keeps its text and its
        // focus rather than being silently swallowed.
        guard store.addWorkspace(named: newWorkspace) != nil else { return }
        newWorkspace = ""
        addWorkspaceFocused = false
    }

    // MARK: Data

    /// Archive, one line of sync status, About. The status is a LINE, not a
    /// control: sync is silent, so there is nothing here to press or retry.
    private var dataPanel: some View {
        card("Data") {
            VStack(alignment: .leading, spacing: SkeuSpace.md) {
                HStack(spacing: SkeuSpace.sm) {
                    actionPill("Archive") { showArchive = true }
                    actionPill("How to use") { showHowTo = true }
                    actionPill("About") { showAbout = true }
                    Spacer(minLength: 0)
                }

                Text(sync.summary)
                    .font(SkeuFont.at(labelSize))
                    .foregroundStyle(sync.isDegraded ? skeu.critical : skeu.inkMuted)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var header: some View {
        HStack {
            // CHROME, and typed out with the rest: the screen's own name is a
            // heading like the section eyebrows are, so it keeps the pixel
            // face under Blend (founder direction 2026-08-16).
            TypedText(text: "Settings", face: settings.skeuFace, role: .chrome)
                .font(SkeuFont.title3Chrome)
                .foregroundStyle(skeu.ink)

            Spacer(minLength: SkeuSpace.sm)

            Group {
                // Same size, same glyph weight and same corner as the gear
                // this sheet opened from — see SkeuTopBar.
                let size = SkeuTopBar.control * chromeScale
                SkeuChromeGlyph(kind: .close, face: settings.skeuFace,
                                size: SkeuTopBar.icon * chromeScale, tint: skeu.ink)
                    .frame(width: size, height: size)
                    .skeuGlass(Circle(), height: size)
            }
            .skeuPress { onClose() }
            .frame(minWidth: SkeuControl.minTouch, minHeight: SkeuControl.minTouch)
            .accessibilityAddTraits(.isButton)
            .accessibilityLabel("Close settings")
        }
    }

    // MARK: Panels

    /// One setting = a heading and a trough of options. NO outer card.
    ///
    /// The card was the Figma menu study's construction, but stacking seven of
    /// them put a frame inside a frame on every row (founder direction
    /// 2026-08-14): the home screen does not wrap its four tabs in a card, and
    /// these are the same control. The eyebrow now labels the trough directly,
    /// and the trough is the only surface — which also removes seven raised
    /// cards' worth of gradients and shadows from the sheet's first frame.
    private func panel<C: View>(_ title: String,
                                @ViewBuilder options: () -> C) -> some View {
        VStack(alignment: .leading, spacing: G.headingGap) {
            TypedText(text: title.uppercased(), face: settings.skeuFace, role: .chrome)
                .font(SkeuFont.eyebrow)
                .tracking(0.8)
                .foregroundStyle(skeu.inkFaint)

            SkeuSegmentedTrough { options() }
        }
    }

    /// One option — the SAME segment the home screen's tab bar is built from.
    ///
    /// `group` is the matched-geometry namespace: each settings row is its own
    /// toggle, so its pill must glide within that row and not toward some
    /// other panel's selection.
    private func option(_ title: String,
                        selected: Bool,
                        in group: Namespace.ID,
                        action: @escaping () -> Void) -> some View {
        SkeuSegment(isSelected: selected, namespace: group, geometryID: "pill") {
            // Types itself out on a face change, like the headings — these are
            // the labels most obviously "set" in the chosen face, since one of
            // them names it.
            // CONTENT, selected or not. The active toggle was pixel for one
            // round and the founder reversed it (2026-08-16): in settings only
            // the HEADINGS carry the face, so the options read as a row of
            // equals and the choice is marked by the glass, not by the type.
            TypedText(text: title, face: settings.skeuFace, role: .content)
                .skeuSegmentLabel(textScale, role: .content)
                .foregroundStyle(selected ? skeu.ink : skeu.inkMuted)
        }
        // Swells on every press, including when it is ALREADY the answer —
        // acknowledging the touch is the difference between "that did nothing"
        // and "that is already chosen" (founder direction 2026-08-17).
        .skeuPress(haptic: false) {
            SkeuHaptic.selection()
            withAnimation(SkeuMotion.layout) { action() }
        }
        .accessibilityAddTraits(selected ? [.isButton, .isSelected] : .isButton)
    }

    /// The theme row's segment. The colour FILLS the pill (founder direction
    /// 2026-08-16) — a dot floating in a segment made the choice look like an
    /// icon beside an absent label, when the colour is the whole answer.
    ///
    /// The content is a blank line of the same type the other rows set, so a
    /// colour pill comes out exactly the size of a label pill and the theme
    /// row lines up with Typeface, Design and Light & dark above it.
    private func swatchOption(_ theme: SkeuTheme,
                              selected: Bool,
                              in group: Namespace.ID,
                              action: @escaping () -> Void) -> some View {
        SkeuSegment(isSelected: selected, namespace: group, geometryID: "pill",
                    fill: theme.swatchStyle) {
            Text(" ").skeuSegmentLabel(textScale)
        }
        .skeuPress(haptic: false) {
            SkeuHaptic.selection()
            withAnimation(SkeuMotion.layout) { action() }
        }
        .accessibilityLabel("\(theme.name) theme")
        .accessibilityAddTraits(selected ? [.isButton, .isSelected] : .isButton)
    }

    /// A heading over free-form content — the field stacks and the Data row.
    /// Card-less for the same reason `panel` is: those fields already sit in
    /// troughs of their own, so an outer frame was a frame inside a frame.
    private func card<C: View>(_ title: String,
                               @ViewBuilder content: () -> C) -> some View {
        VStack(alignment: .leading, spacing: G.headingGap) {
            TypedText(text: title.uppercased(), face: settings.skeuFace, role: .chrome)
                .font(SkeuFont.eyebrow)
                .tracking(0.8)
                .foregroundStyle(skeu.inkFaint)

            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// A text field in a trough. §9.7: inputs are recessed — the same channel
    /// everything else uses.
    ///
    /// Nothing else goes in here. The Default / Delete / Add buttons used to
    /// sit inside this trough, which made a control live in a container that
    /// is meant to read as a hole in the surface; they stand beside it now
    /// (founder direction 2026-08-16) — see `SkeuRowButton`.
    private func field(text: Binding<String>,
                       prompt: String,
                       focused: FocusState<Bool>.Binding) -> some View {
        TextField("", text: text,
                  prompt: Text(prompt).foregroundStyle(skeu.inkFaint))
            .font(SkeuFont.at(labelSize))
            .foregroundStyle(skeu.ink)
            .focused(focused)
            .submitLabel(.done)
            .padding(.horizontal, SkeuSpace.lg)
            .frame(height: fieldH)
            .skeuTrough(Capsule(), height: fieldH)
    }

    /// A standalone action pill — no trough behind it, it IS the control.
    private func actionPill(_ title: String, action: @escaping () -> Void) -> some View {
        Text(title)
            .font(SkeuFont.at(labelSize, weight: .medium))
            .foregroundStyle(skeu.ink)
            .padding(.horizontal, G.pillPadH)
            .frame(height: pillH)
            .skeuGlass(Capsule(), height: pillH)
            .skeuPress {
                action()
            }
            .accessibilityAddTraits(.isButton)
    }
}

// MARK: - Row button

/// The button that stands BESIDE a field: Default, Delete, Add.
///
/// It is the toggle's inner pill, standing outside a trough instead of in
/// one: same height, same glass, so a field row and an option row are visibly
/// the same construction (founder direction 2026-08-16). One fixed width
/// across all three so they line up down the sheet.
private struct SkeuRowButton: View {
    @Environment(\.skeu) private var skeu
    @Environment(\.skeuTextScale) private var textScale
    @Environment(\.skeuChromeScale) private var chromeScale
    /// Read only to re-render on a typeface change — see `\.skeuFace`.
    @Environment(\.skeuFace) private var face
    let title: String
    /// Colour comes from the caller — Delete is the one destructive word on
    /// this screen and says so.
    var tint: Color?
    var prominent = true
    var action: () -> Void

    var body: some View {
        let height = G.rowButtonH * chromeScale

        Text(title)
            .font(SkeuFont.at(G.label * textScale, weight: .medium))
            .foregroundStyle(tint ?? skeu.ink)
            .lineLimit(1)
            // The width is fixed, so an accessibility size has to shrink the
            // word rather than push the field off the screen.
            .minimumScaleFactor(0.6)
            .frame(width: G.rowButtonW * chromeScale, height: height)
            .skeuGlass(Capsule(), height: height, prominent: prominent)
            .skeuPress(action)
            .accessibilityAddTraits(.isButton)
    }
}

// MARK: - Tab name field

/// Its own view so the draft state belongs to the row, not the whole screen.
private struct SkeuNameField: View {
    @Environment(\.skeuTextScale) private var textScale
    @Environment(\.skeuChromeScale) private var chromeScale

    // Dynamic Type (FR-015): text on the full curve, chrome at half. Without
    // this the eyebrow headings scaled (they use SkeuFont tokens) while every
    // field label stayed fixed — giant titles over tiny controls.
    private var labelSize: CGFloat { G.label * textScale }
    private var fieldH: CGFloat { G.fieldHeight * chromeScale }
    @Environment(\.skeu) private var skeu
    /// Read only to re-render on a typeface change — see `\.skeuFace`.
    @Environment(\.skeuFace) private var face
    @Environment(AppSettings.self) private var settings
    let bucket: Bucket
    /// Opens the tab's own menu. The field renames; this is everything else
    /// about the tab (founder direction 2026-08-17).
    let onEdit: () -> Void

    @State private var draft = ""
    @FocusState private var focused: Bool

    private var isDefault: Bool {
        settings.name(for: bucket) == bucket.displayName
    }

    var body: some View {
        HStack(spacing: SkeuSpace.sm) {
            // The field always holds the REAL current name at full strength —
            // a greyed placeholder reads as empty.
            TextField("", text: $draft.limited(to: AppSettings.maxNameLength),
                      prompt: Text(bucket.displayName).foregroundStyle(skeu.inkFaint))
                .font(SkeuFont.at(labelSize))
                .foregroundStyle(skeu.ink)
                .focused($focused)
                .submitLabel(.done)
                .onSubmit(commit)
                .onChange(of: focused) { _, isFocused in
                    if !isFocused { commit() }
                }
                .padding(.horizontal, SkeuSpace.lg)
                .frame(height: fieldH)
                .skeuTrough(Capsule(), height: fieldH)

            // A trough LOOKS like a place text lives, not a place text is
            // changed — nothing about it says you may type here, so the row
            // needed something that does (founder direction 2026-08-17).
            // Round, because it holds a mark rather than a word, and this
            // look's word-buttons are all capsules.
            // Sized to the Default pill beside it, NOT to the field: a circle
            // as tall as the trough towered over the button it stands next to
            // (founder direction 2026-08-17). The mark keeps its own size —
            // only the disc around it comes down.
            Image(systemName: "square.and.pencil")
                .font(.system(size: labelSize * 0.95))
                .foregroundStyle(skeu.ink)
                .frame(width: G.rowButtonH * chromeScale,
                       height: G.rowButtonH * chromeScale)
                .skeuGlass(Circle(), height: G.rowButtonH * chromeScale)
                // A filled Circle is hittable only where the ink lands.
                .contentShape(Circle())
                .skeuPress {
                    SkeuHaptic.press()
                    focused = false
                    onEdit()
                }
                .accessibilityLabel("Settings for \(settings.name(for: bucket))")

            // Fades when the name already IS the default — a control that
            // would do nothing shouldn't invite a press.
            SkeuRowButton(title: "Default", prominent: !isDefault) {
                guard !isDefault else { return }
                SkeuHaptic.press()
                focused = false
                draft = bucket.displayName
                settings.resetName(for: bucket)
            }
            .opacity(isDefault ? 0.35 : 1)
            .animation(SkeuMotion.tint, value: isDefault)
            .accessibilityLabel("Restore default name for \(bucket.displayName)")
        }
        .task { draft = settings.name(for: bucket) }
    }

    private func commit() {
        settings.setName(draft == bucket.displayName ? "" : draft, for: bucket)
        draft = settings.name(for: bucket)
    }
}


// MARK: - Workspace row

private struct SkeuWorkspaceRow: View {
    @Environment(\.skeuTextScale) private var textScale
    @Environment(\.skeuChromeScale) private var chromeScale

    // Dynamic Type (FR-015): text on the full curve, chrome at half. Without
    // this the eyebrow headings scaled (they use SkeuFont tokens) while every
    // field label stayed fixed — giant titles over tiny controls.
    private var labelSize: CGFloat { G.label * textScale }
    private var fieldH: CGFloat { G.fieldHeight * chromeScale }
    @Environment(\.skeu) private var skeu
    /// Read only to re-render on a typeface change — see `\.skeuFace`.
    @Environment(\.skeuFace) private var face
    @Environment(TaskStore.self) private var store
    let workspace: Workspace
    var onDelete: () -> Void

    @State private var draft = ""
    @FocusState private var focused: Bool

    var body: some View {
        HStack(spacing: SkeuSpace.sm) {
            TextField("", text: $draft.limited(to: AppSettings.maxNameLength),
                      prompt: Text(workspace.name).foregroundStyle(skeu.inkFaint))
                .font(SkeuFont.at(labelSize))
                .foregroundStyle(skeu.ink)
                .focused($focused)
                .submitLabel(.done)
                .onSubmit(commit)
                .onChange(of: focused) { _, isFocused in
                    if !isFocused { commit() }
                }
                .padding(.horizontal, SkeuSpace.lg)
                .frame(height: fieldH)
                .skeuTrough(Capsule(), height: fieldH)

            // The default workspace can't be deleted — there must always be
            // somewhere for tasks to live. Its slot is HELD rather than
            // collapsed, so that one row's field isn't wider than the rest.
            if workspace.isDefault {
                Color.clear
                    .frame(width: G.rowButtonW * chromeScale,
                           height: G.rowButtonH * chromeScale)
            } else {
                SkeuRowButton(title: "Delete", tint: skeu.critical) {
                    SkeuHaptic.warning()
                    onDelete()
                }
                .accessibilityLabel("Delete workspace \(workspace.name)")
            }
        }
        .task { draft = workspace.name }
    }

    private func commit() {
        store.renameWorkspace(workspace, to: draft)
        draft = workspace.name
    }
}


// MARK: - Tab menu

/// One tab's own settings, over the sheet. Today it holds a single decision;
/// it is a menu rather than a switch in the row because that decision is about
/// the TAB, and the row is about its name.
private struct SkeuTabMenu: View {
    @Environment(\.skeu) private var skeu
    @Environment(\.skeuTextScale) private var textScale
    @Environment(\.skeuChromeScale) private var chromeScale
    @Environment(AppSettings.self) private var settings
    let bucket: Bucket
    let onClose: () -> Void

    /// The gliding pill's namespace — both segments share it.
    @Namespace private var pill

    private var enabled: Bool { settings.timeRulesEnabled(for: bucket) }

    var body: some View {
        ZStack {
            // Tapping off closes it — the same way every other overlay here
            // behaves.
            // 0.45 over a dark canvas was barely a veil — the page read
            // straight through it (founder bug report 2026-08-17).
            skeu.shadow.opacity(0.72)
                .ignoresSafeArea()
                .contentShape(Rectangle())
                .onTapGesture(perform: onClose)

            // NOT SkeuCard — that is a fixed-height ROW (67pt), and this is a
            // container. Wrapped in one, the title, the label, the
            // explanation and the button were all crushed into a single band
            // beside the toggle (founder bug report 2026-08-17). The
            // confirmation dialog's surface is the right one: a card at the
            // top of the depth ladder, floating above what it covers.
            VStack(alignment: .leading, spacing: SkeuSpace.lg) {
                Text(settings.name(for: bucket))
                    .font(SkeuFont.title3)
                    .foregroundStyle(skeu.ink)

                if bucket == .general {
                    // Honest rather than disabled-and-silent: General has no
                    // time rules, so there is nothing here to switch.
                    Text("General never moves anything on its own. There is no time rule here to turn off.")
                        .font(SkeuFont.callout)
                        .foregroundStyle(skeu.inkMuted)
                        .fixedSize(horizontal: false, vertical: true)
                } else {
                    Text("Time rules")
                        .font(SkeuFont.callout)
                        .foregroundStyle(skeu.ink)

                    SkeuSegmentedTrough {
                        HStack(spacing: 0) {
                            choice("On", isOn: true)
                            choice("Off", isOn: false)
                        }
                    }

                    Text(enabled
                         ? "Tasks roll over at midnight, arrive in Today when their day comes, and are marked when they are late."
                         : "Nothing moves on its own. Tasks stay where you put them, like General.")
                        .font(SkeuFont.at(G.label * textScale * 0.92))
                        .foregroundStyle(skeu.inkMuted)
                        .fixedSize(horizontal: false, vertical: true)
                }

                SkeuRowButton(title: "Done", action: onClose)
                    .frame(maxWidth: .infinity, alignment: .trailing)
                    .accessibilityLabel("Close tab settings")
            }
            .padding(SkeuSpace.xl)
            .frame(maxWidth: 340)
            .skeuSurface(RoundedRectangle(cornerRadius: SkeuRadius.lg, style: .continuous),
                         depth: .overlay)
            .padding(.horizontal, SkeuSpace.xl)
        }
        .transition(.opacity)
    }

    private func choice(_ title: String, isOn: Bool) -> some View {
        SkeuSegment(isSelected: enabled == isOn,
                    namespace: pill,
                    geometryID: "tab.timeRules") {
            Text(title)
                .font(SkeuFont.at(G.label * textScale, weight: .medium))
                .foregroundStyle(skeu.ink)
                .frame(maxWidth: .infinity)
        }
        .contentShape(Rectangle())
        .onTapGesture {
            SkeuHaptic.press()
            withAnimation(SkeuMotion.layout) {
                settings.setTimeRules(isOn, for: bucket)
            }
        }
        // The traits every other segmented control in the app carries. Without
        // them these read as two pieces of static text, and since selection is
        // otherwise carried purely by the glass pill, a VoiceOver user had no
        // way to tell which of On/Off was active (found in review 2026-08-26).
        .accessibilityAddTraits(enabled == isOn ? [.isButton, .isSelected] : .isButton)
    }
}
