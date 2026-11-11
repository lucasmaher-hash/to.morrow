import SwiftUI
import SwiftData
import Shove95Kit

struct MacRowMenuRequest {
    let task: TaskItem
    let row: CGRect
}

/// Mobile SkeuMenu / SkeuMenuOverlay construction, using Mac commands/store.
struct MacTaskMenuOverlay: View {
    let request: MacRowMenuRequest
    let bounds: CGSize
    let close: () -> Void
    let focus: () -> Void
    let remove: () -> Void
    @EnvironmentObject private var settings: MacSettings
    @Environment(\.skeu) private var skeu
    @Environment(\.modelContext) private var context
    @Query(sort: \TaskItem.sortOrder) private var tasks: [TaskItem]
    @Query(sort: \Workspace.createdAt) private var workspaceRecords: [Workspace]
    private var workspaces: [Workspace] { MacWorkspaceRecords.unique(workspaceRecords) }
    private var task: TaskItem { request.task }
    @State private var choosingWorkspace = false
    private var height: CGFloat {
        choosingWorkspace ? CGFloat(workspaces.count + 1) * 44 + 20 : 4 * 44 + 18 + 20
    }
    var body: some View {
        let frame = Self.menuFrame(row: request.row, bounds: CGRect(origin: .zero, size: bounds).insetBy(dx: 8, dy: 8), size: CGSize(width: 210, height: height))
        let shape = RoundedRectangle(cornerRadius: SkeuRadius.lg, style: .continuous)
        ZStack(alignment: .topLeading) {
            Color.clear.contentShape(Rectangle()).onTapGesture(perform: close)
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    if choosingWorkspace {
                        item("‹ Back") { choosingWorkspace = false }
                        ForEach(workspaces) { workspace in
                            Button {
                                close(); task.workspaceID = workspace.taskStampID; try? context.save()
                            } label: {
                                HStack {
                                    Text(workspace.name).lineLimit(1)
                                    Spacer()
                                    if task.workspaceID == workspace.taskStampID { Image(systemName: "checkmark") }
                                }.font(SkeuFont.at(12.8)).foregroundStyle(skeu.ink)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(.horizontal, 12).frame(height: 44).contentShape(Rectangle())
                            }.buttonStyle(.plain)
                        }
                    } else {
                        item("Delete", destructive: true, dismiss: true, action: remove)
                        separator
                        item(task.isImportant ? "Unmark Important" : "Mark as Important", dismiss: true) {
                            withAnimation(SkeuMotion.layout) { MacTaskActions.toggleImportant(task, tasks: tasks, settings: settings) }; try? context.save()
                        }
                        .disabled(task.isCompleted)
                        item("Go Live", mark: true, dismiss: true, action: focus).disabled(task.isCompleted)
                        separator
                        item("Switch Workspace", disclosure: true) { choosingWorkspace = true }
                            .disabled(workspaces.count < 2)
                    }
                }.padding(10).background(MacScrollIndicators())
            }.scrollIndicators(.hidden)
                .frame(width: frame.width, height: frame.height)
                .clipShape(shape)
                .skeuGlass(shape, height: 37, frosted: true)
                .shadow(color: skeu.shadow.opacity(0.22 * skeu.shadowIntensity), radius: 20, x: -4, y: 10)
                .shadow(color: skeu.shadow.opacity(0.16 * skeu.shadowIntensity), radius: 40, x: -12, y: 26)
                .position(x: frame.midX, y: frame.midY)
                .transition(.scale(scale: 0.86, anchor: frame.midY > request.row.midY ? .topLeading : .bottomLeading).combined(with: .opacity))
        }.animation(SkeuMotion.layout, value: choosingWorkspace)
            .onExitCommand { if choosingWorkspace { choosingWorkspace = false } else { close() } }
    }
    private func item(_ title: String, destructive: Bool = false, mark: Bool = false, disclosure: Bool = false, dismiss: Bool = false, action: @escaping () -> Void) -> some View {
        Button { if dismiss { close() }; action() } label: {
            HStack(spacing: 8) {
                if mark { LiveGlyph(tint: skeu.ink, lineWidth: 1.4).frame(width: 12.8 * 0.82, height: 12.8 * 0.82) }
                Text(title).font(SkeuFont.at(12.8)).tracking(-0.02 * 12.8)
                    .foregroundStyle(destructive ? skeu.critical : skeu.ink).lineLimit(1)
                if disclosure { Spacer(); Image(systemName: "chevron.right").font(SkeuFont.at(12.8)).foregroundStyle(skeu.ink) }
            }.frame(maxWidth: .infinity, alignment: .leading).padding(.horizontal, 12).frame(height: 44).contentShape(Rectangle())
        }.buttonStyle(.plain)
    }
    private var separator: some View {
        Rectangle().fill(skeu.outline.opacity(0.35)).frame(height: 1).padding(.horizontal, 8).padding(.vertical, 4)
    }
    static func menuFrame(row: CGRect, bounds: CGRect, size: CGSize) -> CGRect {
        let width = min(size.width, max(0, bounds.width)), height = min(size.height, max(0, bounds.height))
        let below = row.maxY + 8
        let y = below + height <= bounds.maxY ? below : row.minY - 8 - height
        return CGRect(x: max(bounds.minX, min(row.minX, bounds.maxX - width)), y: max(bounds.minY, min(y, bounds.maxY - height)), width: width, height: height)
    }
}
