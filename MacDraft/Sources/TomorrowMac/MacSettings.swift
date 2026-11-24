import SwiftUI
import Combine
import SwiftData
import Shove95Kit
import CoreText

@MainActor final class MacSettings: ObservableObject {
    private let defaults: UserDefaults
    @Published var theme: String { didSet { defaults.set(theme, forKey: "mac.theme") } }
    @Published var appearance: String { didSet { defaults.set(appearance, forKey: "mac.appearance") } }
    @Published var textSize: Double { didSet { defaults.set(textSize, forKey: "mac.textSize") } }
    @Published var menuTitle: Bool { didSet { defaults.set(menuTitle, forKey: "mac.menuTitle") } }
    @Published var face: String { didSet {
        defaults.set(face, forKey: "mac.face")
        SkeuFont.face = face == "Retro" ? .blend : .system
    } }
    @Published var names: [String: String] { didSet { defaults.set(names, forKey: "mac.names") } }
    @Published var rules: [String: Bool] { didSet { defaults.set(rules, forKey: "mac.rules") } }
    @Published var frozen: [String: String] { didSet { defaults.set(frozen, forKey: "mac.frozen") } }
    func name(_ bucket: Bucket) -> String {
        let value = names[bucket.rawValue]?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return value.isEmpty ? bucket.displayName : value
    }
    func timeRules(_ bucket: Bucket) -> Bool { bucket != .general && rules[bucket.rawValue] != false }
    func visible(_ task: TaskItem, in bucket: Bucket) -> Bool {
        if task.isLiveNote { return task.isVisible(in: bucket, now: .now, calendar: .current) }
        if let held = frozen[task.id.uuidString], rules[held] == false {
            return held == bucket.rawValue && !task.isLiveNote && !task.isArchived(now: .now, calendar: .current)
        }
        return task.isVisible(in: bucket, now: .now, calendar: .current)
    }
    func bucket(for task: TaskItem) -> Bucket {
        if task.isLiveNote { return .today }
        if let held = frozen[task.id.uuidString], rules[held] == false,
           let bucket = Bucket(rawValue: held) { return bucket }
        return task.bucket(now: .now, calendar: .current)
    }
    func place(_ task: TaskItem, in bucket: Bucket) {
        frozen[task.id.uuidString] = timeRules(bucket) || bucket == .general ? nil : bucket.rawValue
    }
    func setRules(_ enabled: Bool, for bucket: Bucket, tasks: [TaskItem]) {
        guard bucket != .general else { return }
        if !enabled {
            for task in tasks where visible(task, in: bucket) { frozen[task.id.uuidString] = bucket.rawValue }
        } else { frozen = frozen.filter { $0.value != bucket.rawValue } }
        rules[bucket.rawValue] = enabled
    }
    func zoom(_ delta: Double) { textSize = min(24, max(11, textSize + delta)) }
    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        let fontURL = Bundle.main.url(forResource: "W95FA", withExtension: "otf")
            ?? URL(fileURLWithPath: #filePath).deletingLastPathComponent().appendingPathComponent("../../Assets/W95FA.otf").standardizedFileURL
        CTFontManagerRegisterFontsForURL(fontURL as CFURL, .process, nil)
        face = defaults.string(forKey: "mac.face") ?? "Modern"
        names = defaults.dictionary(forKey: "mac.names") as? [String: String] ?? [:]
        rules = defaults.dictionary(forKey: "mac.rules") as? [String: Bool] ?? [:]
        frozen = defaults.dictionary(forKey: "mac.frozen") as? [String: String] ?? [:]
        theme = defaults.string(forKey: "mac.theme") ?? "slate"
        appearance = defaults.string(forKey: "mac.appearance") ?? "System"
        textSize = defaults.object(forKey: "mac.textSize") as? Double ?? 15
        menuTitle = defaults.object(forKey: "mac.menuTitle") as? Bool ?? true
        SkeuFont.face = face == "Retro" ? .blend : .system
    }
}
struct SkeuHost<Content: View>: View {
    @ObservedObject var settings: MacSettings
    @Environment(\.colorScheme) private var scheme
    @ViewBuilder var content: Content
    var body: some View {
        let dark = settings.appearance == "Dark" || (settings.appearance == "System" && scheme == .dark)
        content.environment(\.skeu, SkeuTheme.named(settings.theme).palette(dark: dark))
            .environment(\.skeuTextScale, settings.textSize / MacTaskMetrics.label).environmentObject(settings)
            .preferredColorScheme(settings.appearance == "System" ? nil : (dark ? .dark : .light))
    }
}
struct MacSettingsView: View {
    @EnvironmentObject private var cloud: MacCloudSync
    let onClose: () -> Void
    @EnvironmentObject private var settings: MacSettings
    @Environment(\.skeu) private var skeu
    @Environment(\.skeuTextScale) private var textScale
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.modelContext) private var context
    @Query(sort: \Workspace.createdAt) private var workspaceRecords: [Workspace]
    private var workspaces: [Workspace] { MacWorkspaceRecords.unique(workspaceRecords) }
    @Query(sort: \TaskItem.sortOrder) private var tasks: [TaskItem]
    @State private var newWorkspace = ""
    @State private var pendingDelete: Workspace?
    @State private var panel: String?
    @State private var timeRulesFor: Bucket?
    @State private var error: String?
    private let workspaceID: String
    init(initialPage: String? = nil, workspaceID: String = Workspace.defaultID, onClose: @escaping () -> Void) {
        self.onClose = onClose
        self.workspaceID = workspaceID
        _panel = State(initialValue: initialPage)
    }
    private var archiveTasks: [TaskItem] {
        tasks.filter { task in
            let id = task.workspaceID ?? Workspace.defaultID
            let resolved = workspaces.contains { $0.id == id } ? id : Workspace.defaultID
            return resolved == workspaceID
        }
    }
    @Namespace private var themeSpace
    var body: some View {
        MacSheetPage(title: "Settings", close: onClose) {
        LazyVStack(alignment: .leading, spacing: 44) {
            group("THEME") {
                SkeuSegmentedTrough {
                    ForEach(SkeuTheme.all) { theme in
                        Button {
                            withAnimation(reduceMotion ? nil : SkeuMotion.layout) { settings.theme = theme.id }
                        } label: {
                            SkeuSegment(isSelected: settings.theme == theme.id,
                                        namespace: themeSpace, geometryID: "theme", fill: theme.swatchStyle) {
                                Text(" ").skeuSegmentLabel(textScale)
                            }
                        }.buttonStyle(MacSkeuTapStyle())
                            .accessibilityLabel("\(theme.name) theme")
                            .accessibilityAddTraits(settings.theme == theme.id ? .isSelected : [])
                            .help(theme.name)
                    }
                }
            }
            group("TYPEFACE") { MacChoice(options: ["Retro", "Modern"], selection: $settings.face) }
            group("LIGHT & DARK") { MacChoice(options: ["System", "Light", "Dark"], selection: $settings.appearance) }
            group("TAB NAMES") {
                VStack(spacing: 10) {
                    ForEach(Bucket.line, id: \.self) { bucket in
                        HStack(spacing: SkeuSpace.sm) {
                            nameField(Binding(get: { settings.name(bucket) }, set: { settings.names[bucket.rawValue] = String($0.prefix(24)) }), prompt: bucket.displayName)
                            Button {
                                withAnimation(reduceMotion ? nil : SkeuMotion.present) { timeRulesFor = bucket }
                            } label: {
                                Image(systemName: "square.and.pencil")
                                    .font(.system(size: 16.4 * textScale * 0.95))
                            }.buttonStyle(GlassButton(circle: true, diameter: 34.6))
                                .accessibilityLabel("Settings for \(settings.name(bucket))")
                            Button { settings.names[bucket.rawValue] = nil } label: {
                                Text("Default").frame(width: 56)
                            }.buttonStyle(GlassButton(selected: settings.name(bucket) != bucket.displayName, diameter: 34.6))
                                .opacity(settings.name(bucket) == bucket.displayName ? 0.35 : 1)
                                .disabled(settings.name(bucket) == bucket.displayName)
                        }
                    }
                }
            }
            group("WORKSPACES") {
                VStack(spacing: 10) {
                    ForEach(workspaces) { workspace in
                        HStack(spacing: 8) {
                            nameField(Binding(get: { workspace.name }, set: { workspace.name = String($0.prefix(24)); save() }), prompt: "Workspace name")
                            Color.clear.frame(width: 34.6, height: 34.6)
                            if workspace.isDefault {
                                Color.clear.frame(width: 88, height: 34.6)
                            } else {
                                Button { pendingDelete = workspace } label: { Text("Delete").frame(width: 56).foregroundStyle(skeu.critical) }
                                    .buttonStyle(GlassButton(diameter: 34.6))
                                    .accessibilityLabel("Delete workspace \(workspace.name)")
                            }
                        }
                    }
                    HStack(spacing: 8) {
                        nameField($newWorkspace, prompt: "New workspace").onSubmit(addWorkspace)
                        Color.clear.frame(width: 34.6, height: 34.6)
                        Button(action: addWorkspace) { Text("Add").frame(width: 56) }.buttonStyle(GlassButton(diameter: 34.6))
                            .disabled(newWorkspace.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                }
            }
            group("LIVE") {
                HStack(spacing: 20) {
                    Text("Task title in menu bar").font(SkeuFont.at(SkeuToggle.label * textScale))
                    MacChoice(options: ["On", "Off"], selection: Binding(
                        get: { settings.menuTitle ? "On" : "Off" },
                        set: { settings.menuTitle = $0 == "On" }))
                        .frame(width: 170)
                }
            }
            group("DATA") {
                HStack(spacing: 8) {
                    ForEach(["Archive", "How to use", "About"], id: \.self) { title in
                        Button(title) { panel = title }.buttonStyle(GlassButton(diameter: 34.6))
                    }
                }
            }
            group("ACCOUNT & ICLOUD") {
                VStack(alignment: .leading, spacing: 12) {
                    Label(cloud.title, systemImage: "icloud").font(SkeuFont.bodyEmph)
                    Text(cloud.detail).font(SkeuFont.at(13 * textScale)).foregroundStyle(skeu.inkMuted)
                    if let date = cloud.lastTransfer {
                        Text("Last iCloud transfer: " + date.formatted(date: .abbreviated, time: .shortened))
                            .font(SkeuFont.at(12 * textScale)).foregroundStyle(skeu.inkMuted)
                    }
                    if let message = cloud.syncError {
                        Text(message).font(SkeuFont.at(12 * textScale)).foregroundStyle(skeu.critical)
                    }
                    Button("Apple Account Settings") {
                        NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preferences.AppleIDPrefPane")!)
                    }.buttonStyle(GlassButton(diameter: 34.6))
                }
            }
            if let error { Text(error).foregroundStyle(skeu.critical) }
        }
        }
            .accessibilityHidden(timeRulesFor != nil || panel != nil)
            .overlay {
                if let bucket = timeRulesFor {
                    MacTimeRulesPanel(bucket: bucket, tasks: tasks) {
                        withAnimation(reduceMotion ? nil : SkeuMotion.present) { timeRulesFor = nil }
                    }.transition(.opacity)
                }
            }
            .overlay {
                if panel != nil {
                    settingsDetail.frame(maxWidth: .infinity, maxHeight: .infinity).background(skeu.canvas)
                }
            }
            .confirmationDialog("Delete workspace? Its tasks move to the default workspace.", isPresented: Binding(get: { pendingDelete != nil }, set: { if !$0 { pendingDelete = nil } })) {
                Button("Delete workspace", role: .destructive) {
                    guard let workspace = pendingDelete else { return }
                    for task in tasks where task.workspaceID == workspace.id { task.workspaceID = nil }
                    for record in workspaceRecords where record.id == workspace.id { context.delete(record) }
                    save(); pendingDelete = nil
                }
                Button("Cancel", role: .cancel) { pendingDelete = nil }
            }
    }
    private func nameField(_ text: Binding<String>, prompt: String) -> some View {
        TextField(prompt, text: text).textFieldStyle(.plain)
            .font(SkeuFont.at(16.4 * textScale)).padding(.horizontal, 16)
            .frame(height: SkeuToggle.height).skeuTrough(Capsule(), height: SkeuToggle.height)
    }
    private func addWorkspace() {
        let name = String(newWorkspace.trimmingCharacters(in: .whitespacesAndNewlines).prefix(24))
        guard !name.isEmpty, !workspaces.contains(where: { $0.name.localizedCaseInsensitiveCompare(name) == .orderedSame }) else { return }
        context.insert(Workspace(id: UUID().uuidString, name: name)); save(); newWorkspace = ""
    }
    private func save() { do { try context.save(); error = nil } catch { self.error = error.localizedDescription } }
    private var settingsDetail: some View {
        MacSheetPage(title: panel ?? "Settings", close: { panel = nil }, showsScrollIndicators: panel == "Archive") {
            switch panel {
            case "Archive":
                MacArchiveContent(tasks: archiveTasks) { task in
                    context.delete(task); save()
                }
            case "How to use": MacHowToContent()
            default: MacAboutContent()
            }
        }
    }
    private func group<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(title).font(SkeuFont.eyebrow).tracking(0.8).foregroundStyle(skeu.inkFaint)
            content()
        }
    }
}

struct MacZoomCommands: Commands {
    @ObservedObject var settings: MacSettings
    var body: some Commands {
        CommandGroup(after: .sidebar) {
            Button("Increase Text Size") { settings.zoom(1) }.keyboardShortcut("+", modifiers: .command)
            Button("Increase Text Size") { settings.zoom(1) }.keyboardShortcut("=", modifiers: .command).hidden()
            Button("Decrease Text Size") { settings.zoom(-1) }.keyboardShortcut("-", modifiers: .command)
            Button("Actual Text Size") { settings.textSize = 15 }.keyboardShortcut("0", modifiers: .command)
        }
    }
}

/// Matches SkeuTabSettingsMenu: floating surface, one inset On/Off channel,
/// and a circular edit trigger next to the tab-name field.
private struct MacTimeRulesPanel: View {
    let bucket: Bucket
    let tasks: [TaskItem]
    let close: () -> Void
    @EnvironmentObject private var settings: MacSettings
    @Environment(\.skeu) private var skeu
    @Environment(\.skeuTextScale) private var textScale
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Namespace private var pill
    private var enabled: Bool { settings.timeRules(bucket) }
    var body: some View {
        ZStack {
            skeu.shadow.opacity(0.72).ignoresSafeArea().contentShape(Rectangle())
                .onTapGesture(perform: close)
            VStack(alignment: .leading, spacing: SkeuSpace.lg) {
                Text(settings.name(bucket)).font(SkeuFont.title3)
                if bucket == .general {
                    Text("General never moves anything on its own. There is no time rule here to turn off.")
                        .font(SkeuFont.callout).foregroundStyle(skeu.inkMuted)
                        .fixedSize(horizontal: false, vertical: true)
                } else {
                    Text("Time rules").font(SkeuFont.callout)
                    SkeuSegmentedTrough {
                        HStack(spacing: 0) {
                            choice("On", on: true)
                            choice("Off", on: false)
                        }
                    }
                    Text(enabled
                         ? "Tasks roll over at midnight, arrive in Today when their day comes, and are marked when they are late."
                         : "Nothing moves on its own. Tasks stay where you put them, like General.")
                        .font(SkeuFont.at(16.4 * textScale * 0.92))
                        .foregroundStyle(skeu.inkMuted)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Button("Done", action: close).buttonStyle(GlassButton(diameter: 34.6))
                    .frame(maxWidth: .infinity, alignment: .trailing)
                    .keyboardShortcut(.defaultAction)
                    .accessibilityLabel("Close tab settings")
            }.foregroundStyle(skeu.ink).padding(SkeuSpace.xl).frame(maxWidth: 340)
                .skeuSurface(RoundedRectangle(cornerRadius: SkeuRadius.lg, style: .continuous), depth: .overlay)
                .padding(SkeuSpace.xl)
        }.onExitCommand(perform: close)
    }
    private func choice(_ title: String, on: Bool) -> some View {
        Button {
            withAnimation(reduceMotion ? nil : SkeuMotion.layout) { settings.setRules(on, for: bucket, tasks: tasks) }
        } label: {
            SkeuSegment(isSelected: enabled == on, namespace: pill, geometryID: "tab.timeRules") {
                Text(title).font(SkeuFont.at(16.4 * textScale, weight: .medium))
                    .foregroundStyle(skeu.ink).frame(maxWidth: .infinity)
            }
        }.buttonStyle(MacSkeuTapStyle()).accessibilityAddTraits(enabled == on ? .isSelected : [])
    }
}
