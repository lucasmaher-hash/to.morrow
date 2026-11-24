//
//  SkeuMenu.swift
//  shove95
//
//  The row menu. The COORDINATION lives apart from the drawing —
//  MenuCoordinator and RowMenuRequest know nothing about either — and the
//  panel here is a raised card in the settings-panel construction: material
//  fill, the mirrored contour stroke, floating shadows.
//
//  Placement logic came from the menu overlay this replaced: global
//  row frame → overlay space, drop below the row unless the panel would run
//  off-screen, then flip above and clamp to the visible bounds. Oversized
//  menus scroll inside those bounds. Height is CALCULATED from the item table, not
//  measured — a PreferenceKey round-trip reports zero on the first pass and
//  the flip decision is made on that pass (the original's hard-won lesson).
//

import SwiftUI
import Shove95Kit

private enum M {
    static let itemHeight: CGFloat = 44
    static let width: CGFloat = 210
    static let label: CGFloat = 12.8
    static let padding: CGFloat = 10
    static let radius: CGFloat = SkeuRadius.lg
    static let separator: CGFloat = 9 // 1pt line + 4pt breathing room each side
}

// MARK: - Panel

struct SkeuMenu: View {
    @Environment(\.skeu) private var skeu
    @Environment(TaskStore.self) private var store
    @Environment(MenuCoordinator.self) private var menu

    let task: TaskItem
    var maximumSize = CGSize(width: M.width, height: CGFloat.greatestFiniteMagnitude)

    private var bucket: Bucket {
        task.bucket(now: store.now(), calendar: store.calendar)
    }

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: M.radius, style: .continuous)

        ScrollView(.vertical) {
        VStack(alignment: .leading, spacing: 0) {
            item("Delete", destructive: true) { store.delete(task) }
            separator
            item(task.isImportant ? "Unmark Important" : "Mark as Important") {
                withAnimation(SkeuMotion.layout) { store.toggleImportant(task) }
            }
            .allowsHitTesting(!task.isCompleted).opacity(task.isCompleted ? 0.4 : 1)
            item("Go Live", mark: true) {
                withAnimation(SkeuMotion.layout) { menu.goLive(task, store: store) }
            }
            .allowsHitTesting(!task.isCompleted).opacity(task.isCompleted ? 0.4 : 1)
            separator
            workspaceMenu

        }
        .padding(M.padding)
        }
        .frame(width: min(M.width, maximumSize.width),
               height: min(Self.estimatedHeight(for: task, store: store), maximumSize.height))
        .scrollBounceBehavior(.basedOnSize)
        .scrollIndicators(.hidden)
        .clipShape(shape)
        // THE SAME GLASS every other floating piece wears, frosted (founder
        // direction 2026-08-16). It used to be a flat gradient fill under a
        // contour stroke — a solid card sitting ON the app. `skeuGlass` gives
        // it the real construction: the five-layer lens, the rim, the glow,
        // the paired shadows. Frosting only stops the list beneath from
        // reading through the labels.
        //
        // HEIGHT IS NOT THE PANEL'S HEIGHT, and it is not the old contour's
        // either. `skeuGlass` is parameterised on a PILL height: every lens
        // inset, the rim width and all three shadows scale off it.
        //
        // The first attempt passed 110 to reproduce the 3.1 contour this
        // panel used to wear — and 3.1 is a TROUGH contour, a line drawn
        // around a channel. A glass rim is a different thing: the round
        // buttons are 37 tall, so theirs comes out at 1.05. At three times
        // that the panel read as an outlined card, which is exactly what the
        // founder saw (2026-08-16). Passing 37 makes this the same edge those
        // buttons have.
        .skeuGlass(shape, height: 37, frosted: true)
        // Floating depth on top of the glass's own contact shadows: this
        // panel hovers over the list, further from the page than a pill lying
        // on it.
        .shadow(color: drop(0.22), radius: 20, x: -4, y: 10)
        .shadow(color: drop(0.16), radius: 40, x: -12, y: 26)
    }

    /// `mark` puts the Live ring before the label.

    private var workspaceMenu: some View {
        Menu {
            ForEach(store.workspaces(), id: \.id) { workspace in
                Button {
                    menu.dismiss()
                    withAnimation(SkeuMotion.layout) {
                        store.move(task, toWorkspace: workspace)
                    }
                } label: {
                    if task.workspaceID == workspace.taskStampID {
                        Label(workspace.name, systemImage: "checkmark")
                    } else {
                        Text(workspace.name)
                    }
                }
            }
        } label: {
            HStack {
                Text("Switch Workspace")
                Spacer()
                Image(systemName: "chevron.right")
            }
            .font(SkeuFont.at(M.label))
            .foregroundStyle(skeu.ink)
            .padding(.horizontal, SkeuSpace.md)
            .frame(minHeight: M.itemHeight)
            .contentShape(Rectangle())
        }
    }
    ///
    /// The move rows carry chevrons that say how FAR along the line they go.
    /// Live is not on that line, so it has no distance to state — it gets the
    /// same mark the tab wears instead, which says where rather than how far
    /// (founder direction 2026-08-17).
    private func item(_ label: String, destructive: Bool = false,
                      mark: Bool = false,
                      action: @escaping () -> Void) -> some View {
        HStack(spacing: SkeuSpace.sm) {
            if mark {
                LiveGlyph(tint: skeu.ink, lineWidth: 1.4)
                    .frame(width: M.label * 0.82, height: M.label * 0.82)
            }
            Text(label)
                .font(SkeuFont.at(M.label))
                .tracking(-0.02 * M.label)
                .foregroundStyle(destructive ? skeu.critical : skeu.ink)
                .lineLimit(1)
        }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, SkeuSpace.md)
            .frame(minHeight: M.itemHeight)
            .contentShape(Rectangle())
            .onTapGesture {
                SkeuHaptic.selection()
                menu.dismiss()
                action()
            }
            .accessibilityAddTraits(.isButton)
    }

    private var separator: some View {
        Rectangle()
            .fill(skeu.outline.opacity(0.35))
            .frame(height: 1)
            .padding(.horizontal, SkeuSpace.sm)
            .padding(.vertical, 4)
    }

    private func drop(_ alpha: Double) -> Color {
        skeu.shadow.opacity(alpha * skeu.shadowIntensity)
    }

    /// The item table is known, so the height is arithmetic — see file header.
    static func estimatedHeight(for task: TaskItem, store: TaskStore) -> CGFloat {
        return 4 * M.itemHeight + 2 * M.separator + M.padding * 2
    }
}

// MARK: - Overlay

/// Places the menu near the row, clamped inside the screen. No scrim — a tap
/// anywhere else dismisses.
struct SkeuMenuOverlay: View {
    @Environment(MenuCoordinator.self) private var menu
    @Environment(TaskStore.self) private var store

    static func menuFrame(for row: CGRect, in bounds: CGRect,
                          menuSize: CGSize, gap: CGFloat) -> CGRect {
        let width = min(menuSize.width, max(0, bounds.width))
        let height = min(menuSize.height, max(0, bounds.height))
        let below = row.maxY + gap
        let preferredY = below + height <= bounds.maxY ? below : row.minY - gap - height
        return CGRect(x: max(bounds.minX, min(row.minX, bounds.maxX - width)),
                      y: max(bounds.minY, min(preferredY, bounds.maxY - height)),
                      width: width, height: height)
    }

    var body: some View {
        GeometryReader { geo in
            if let request = menu.request,
               let task = store.task(withID: request.taskID) {
                // The row reports GLOBAL coordinates; this overlay draws in its
                // own space, which starts below the status bar.
                let origin = geo.frame(in: .global).origin
                let row = request.rowFrame.offsetBy(dx: -origin.x, dy: -origin.y)
                let gap = SkeuSpace.sm
                let height = SkeuMenu.estimatedHeight(for: task, store: store)
                let bounds = CGRect(origin: .zero, size: geo.size).insetBy(dx: gap, dy: gap)
                let placement = Self.menuFrame(for: row, in: bounds,
                                                menuSize: CGSize(width: M.width, height: height), gap: gap)
                let dropsBelow = placement.midY > row.midY

                ZStack(alignment: .topLeading) {
                    Color.clear
                        .contentShape(Rectangle())
                        .onTapGesture { menu.dismiss() }

                    SkeuMenu(task: task, maximumSize: placement.size)
                        .position(x: placement.midX, y: placement.midY)
                        .transition(.scale(scale: 0.86,
                                           anchor: dropsBelow ? .topLeading : .bottomLeading)
                            .combined(with: .opacity))
                }
            }
        }
    }
}
