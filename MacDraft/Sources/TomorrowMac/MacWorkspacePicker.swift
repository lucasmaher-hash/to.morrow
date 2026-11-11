import SwiftUI
import Shove95Kit
import SwiftData
import AppKit

/// The phone's expanding glass pill. The header keeps its footprint while the
/// same surface grows downward, so neither the gear nor the lists move.
struct MacWorkspacePicker: View {
    @EnvironmentObject private var settings: MacSettings
    @Binding var selection: String
    @Binding var isOpen: Bool
    let selected: () -> Void
    @Environment(\.skeu) private var skeu
    @Environment(\.skeuTextScale) private var textScale
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var swollen = false
    @State private var pressToken = 0
    @Query(sort: \Workspace.createdAt) private var workspaceRecords: [Workspace]
    private var workspaces: [Workspace] { MacWorkspaceRecords.unique(workspaceRecords) }
    private var choices: [(String, String)] { workspaces.map { ($0.id, $0.name) } }
    private var current: String { choices.first { $0.0 == selection }?.1 ?? "Personal" }
    private var width: CGFloat {
        let font = settings.face == "Retro" ? (NSFont(name: AppFace.pixelPostScriptName, size: labelSize * 1.22) ?? NSFont.systemFont(ofSize: labelSize)) : NSFont.systemFont(ofSize: labelSize)
        let widest = choices.map { ($0.1 as NSString).size(withAttributes: [.font: font]).width }.max() ?? 80
        return min(270, max(70.4, widest + gap + labelSize * 0.55 + horizontalPadding * 2))
    }
    private var sizeScale: CGFloat { SkeuTopBar.control / ((145.8 - 23.771 * 2) * 37 / 107.444 * 1.2) }
    private var height: CGFloat { SkeuTopBar.control }
    private var horizontalPadding: CGFloat { 35.656 * 37 / 107.444 * 1.2 * sizeScale }
    private var gap: CGFloat { 29.714 * 37 / 107.444 * 1.2 * sizeScale }
    private var labelSize: CGFloat { MacTaskMetrics.label * 1.2 * sizeScale * textScale }

    var body: some View {
        Color.clear.frame(width: width, height: height)
            .overlay(alignment: .topLeading) {
                VStack(spacing: 0) {
                    Button {
                        pressToken += 1
                        withAnimation(reduceMotion ? nil : SkeuMotion.layout) { isOpen.toggle() }
                    } label: {
                        HStack(spacing: gap) {
                            Text(current).font(settings.face == "Retro" ? .custom(AppFace.pixelPostScriptName, fixedSize: labelSize * 1.22) : SkeuFont.at(labelSize, role: .content))
                                .tracking(-0.02 * labelSize)
                                .lineLimit(1).minimumScaleFactor(0.6)
                            Spacer(minLength: 0)
                            WorkspaceChevron().stroke(skeu.ink,
                                style: StrokeStyle(lineWidth: 1.92 * sizeScale, lineCap: .round, lineJoin: .round))
                                .frame(width: labelSize * 0.55, height: labelSize * 0.32)
                                .rotationEffect(.degrees(isOpen ? 180 : 0))
                        }.frame(height: height).contentShape(Rectangle())
                    }.buttonStyle(.plain)
                        .accessibilityLabel("Workspace: \(current)")
                        .accessibilityHint(isOpen ? "Closes the workspace list" : "Opens the workspace list")
                    ScrollView {
                    VStack(spacing: 0) {
                    ForEach(choices.filter { $0.0 != selection }, id: \.0) { choice in
                        Button {
                            withAnimation(reduceMotion ? nil : SkeuMotion.layout) {
                                selection = choice.0
                                selected()
                                isOpen = false
                            }
                        } label: {
                            Text(choice.1).font(SkeuFont.at(labelSize, role: .chrome))
                                .tracking(-0.02 * labelSize).foregroundStyle(skeu.inkMuted)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .frame(height: height).contentShape(Rectangle())
                        }.buttonStyle(.plain)
                            .opacity(isOpen ? 1 : 0)
                            .allowsHitTesting(isOpen).accessibilityHidden(!isOpen)
                    }
                    }.background(MacScrollIndicators())
                    }.frame(height: min(CGFloat(max(0, choices.count - 1)) * height, 300))
                        .scrollIndicators(.hidden)
                }
                .padding(.horizontal, horizontalPadding)
                .frame(width: width, height: isOpen ? height + min(CGFloat(max(0, choices.count - 1)) * height, 300) : height, alignment: .top)
                .clipped()
                .skeuGlass(RoundedRectangle(cornerRadius: height / 2, style: .continuous), height: height, rasterized: false)
                .background(RoundedRectangle(cornerRadius: height / 2, style: .continuous).fill(skeu.canvas))
                .scaleEffect(reduceMotion || !swollen ? 1 : SkeuMotion.pressGrow, anchor: .topLeading)
                .animation(reduceMotion ? nil : SkeuMotion.pressSwell, value: swollen)
            }
            .task(id: pressToken) {
                guard pressToken > 0 else { return }
                swollen = true
                try? await Task.sleep(for: .milliseconds(260))
                guard !Task.isCancelled else { return }
                swollen = false
            }
            .onExitCommand { withAnimation(reduceMotion ? nil : SkeuMotion.layout) { isOpen = false } }
    }
}
private struct WorkspaceChevron: Shape {
    func path(in rect: CGRect) -> Path {
        Path { path in
            path.move(to: CGPoint(x: rect.minX, y: rect.minY))
            path.addLine(to: CGPoint(x: rect.midX, y: rect.maxY))
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        }
    }
}

private struct SettingsPresentedKey: FocusedValueKey { typealias Value = Binding<Bool> }
private struct NewTaskKey: FocusedValueKey { typealias Value = Binding<Bool> }
private struct SearchKey: FocusedValueKey { typealias Value = Binding<Bool> }
private struct CompletedTasksKey: FocusedValueKey { typealias Value = Binding<Bool> }
extension FocusedValues {
    var settingsPresented: Binding<Bool>? {
        get { self[SettingsPresentedKey.self] }
        set { self[SettingsPresentedKey.self] = newValue }
    }
    var newTaskRequested: Binding<Bool>? {
        get { self[NewTaskKey.self] }
        set { self[NewTaskKey.self] = newValue }
    }
    var searchRequested: Binding<Bool>? {
        get { self[SearchKey.self] }
        set { self[SearchKey.self] = newValue }
    }
    var completedTasks: Binding<Bool>? {
        get { self[CompletedTasksKey.self] }
        set { self[CompletedTasksKey.self] = newValue }
    }
}
struct BoardCommands: Commands {
    @FocusedBinding(\.settingsPresented) private var settings: Bool?
    @FocusedBinding(\.newTaskRequested) private var newTask: Bool?
    @FocusedBinding(\.searchRequested) private var search: Bool?
    @FocusedBinding(\.completedTasks) private var completed: Bool?
    var body: some Commands {
        CommandGroup(replacing: .appSettings) {
            Button("Settings…") { settings = true }.keyboardShortcut(",").disabled(settings == nil)
        }
        CommandGroup(after: .newItem) {
            Button("New Task") { newTask?.toggle() }.keyboardShortcut("n").disabled(newTask == nil)
        }
        CommandGroup(after: .textEditing) {
            Button("Find Tasks") { search = true }.keyboardShortcut("f").disabled(search == nil)
        }
        CommandGroup(after: .sidebar) {
            Toggle("Show Completed Tasks", isOn: Binding(get: { completed ?? false }, set: { completed = $0 }))
                .keyboardShortcut("a", modifiers: [.command, .shift])
                .disabled(completed == nil)
        }
    }
}
