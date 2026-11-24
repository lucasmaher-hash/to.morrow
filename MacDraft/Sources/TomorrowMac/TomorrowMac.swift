import SwiftUI
import SwiftData
import AppKit
import Shove95Kit

@main
struct TomorrowMac: App {
    @NSApplicationDelegateAdaptor(MacCloudAppDelegate.self) private var appDelegate
    let container: ModelContainer
    @StateObject private var live: MacLiveController
    @StateObject private var settings: MacSettings
    @StateObject private var cloud: MacCloudSync
    @Environment(\.scenePhase) private var scenePhase
    init() {
        do {
            let (created, mode) = try MacCloudStore.open()
            _cloud = StateObject(wrappedValue: MacCloudSync(mode: mode))
            container = created
            let preferences = MacSettings()
            _settings = StateObject(wrappedValue: preferences)
            _live = StateObject(wrappedValue: MacLiveController(context: created.mainContext, settings: preferences))
        } catch { fatalError("Could not open the Mac draft store: \(error)") }
    }
    var body: some Scene {
        WindowGroup("to.morrow — Mac draft") {
            SkeuHost(settings: settings) {
                BoardView().modelContainer(container).environmentObject(live).environmentObject(cloud)
                    .onChange(of: scenePhase) { _, phase in if phase == .active { cloud.refresh(); live.reloadFromStore() } }
            }.frame(minWidth: 960, minHeight: 600)
        }
        .defaultSize(width: 1180, height: 760)
        .windowStyle(.hiddenTitleBar)
        .commands {
            BoardCommands()
            MacZoomCommands(settings: settings)
            CommandMenu("Live") {
                Button("Open Live Task") { live.show() }.keyboardShortcut("l", modifiers: [.command, .shift])
                Button("Complete Live Task") { live.complete() }
                    .disabled(live.note == nil || live.completing)
            }
        }

    }
}

struct BoardView: View {
    @EnvironmentObject private var cloud: MacCloudSync
    @EnvironmentObject private var live: MacLiveController
    @EnvironmentObject private var settings: MacSettings
    @Query(sort: \Workspace.createdAt) private var workspaceRecords: [Workspace]
    private var workspaces: [Workspace] { MacWorkspaceRecords.unique(workspaceRecords) }
    @Environment(\.skeu) private var skeu
    @Environment(\.skeuTextScale) private var textScale
    @Environment(\.modelContext) private var context
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Query(sort: \TaskItem.sortOrder) private var allTasks: [TaskItem]
    @State private var workspace = Workspace.defaultID
    @State private var search = ""
    @State private var archive = false
    @State private var showFocus = true
    @State private var newTaskRequest = false
    @State private var errorMessage: String?
    @State private var searchVisible = false
    @State private var workspaceOpen = false
    @State private var settingsPresented = false
    @State private var rowMenu: MacRowMenuRequest?
    @State private var photoPreview = MacPhotoPreview()
    @State private var transfer = MacTaskTransferCoordinator()
    @FocusState private var searchFocused: Bool

    private var tasks: [TaskItem] {
        allTasks.filter { task in
            let id = task.workspaceID ?? Workspace.defaultID
            let displayed = workspaces.contains(where: { $0.id == id }) ? id : Workspace.defaultID
            return displayed == workspace &&
                (search.isEmpty || task.title.localizedCaseInsensitiveContains(search))
        }
    }

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .topLeading) {
                boardDividers(size: geometry.size)
                HStack(spacing: 0) {
                    VStack(alignment: .leading, spacing: 12) {
                        Color.clear.frame(height: SkeuTopBar.control)

                        taskColumns
                    }.padding(.top, 6).padding(.bottom, 4)
                    if showFocus {
                        VStack(alignment: .leading, spacing: 0) {
                            Color.clear.frame(height: SkeuTopBar.control)
                                .padding(.bottom, 12)
                            Text("Live").font(SkeuFont.at(16, weight: .medium, role: .chrome))
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .frame(height: SkeuTopBar.control)
                                .padding(.top, 6)
                            LiveWell(live: live, workspaceID: workspace == Workspace.defaultID ? nil : workspace, transfer: transfer).padding(.top, 18)
                            Spacer(minLength: 0)
                        }.padding(.horizontal, 22).padding(.top, 6).padding(.bottom, 8.8).frame(width: 320)
                            .transition(.move(edge: .trailing).combined(with: .opacity))
                    }
                }.frame(width: geometry.size.width, height: geometry.size.height, alignment: .topLeading)
                if workspaceOpen {
                    Color.clear.contentShape(Rectangle())
                        .onTapGesture { closeWorkspaces() }
                        .accessibilityLabel("Close workspace list")
                }
                boardHeader
                    .frame(width: geometry.size.width)
                    .padding(.top, 6)
                if let request = rowMenu {
                    MacTaskMenuOverlay(request: request, bounds: geometry.size,
                        close: dismissRowMenu, focus: { live.activate(request.task); showFocus = true },
                        remove: { remove(request.task) })
                        .zIndex(10)
                }
                if let task = transfer.task {
                    TaskRow(task: task, bucket: settings.bucket(for: task), menuSelected: false, carried: true,
                        showMenu: { _ in }, complete: {}, focus: {}, move: { _ in }, remove: {}, release: { _ in })
                        .frame(width: transfer.frame.width, height: transfer.frame.height, alignment: .top)
                        .scaleEffect(reduceMotion ? 1 : (transfer.isLifted ? 1.03 : 1))
                        .shadow(color: skeu.shadow.opacity(transfer.isLifted ? 0.16 : 0), radius: transfer.isLifted ? 10 : 0, x: -3, y: transfer.isLifted ? 8 : 0)
                        .animation(reduceMotion ? SkeuMotion.tint : MacTaskTransferCoordinator.liftAnimation, value: transfer.isLifted)
                        .position(x: transfer.frame.midX, y: transfer.frame.midY)
                        .allowsHitTesting(false).accessibilityHidden(true).zIndex(20)
                }
            }.coordinateSpace(name: "macBoard")

        }
        .allowsHitTesting(!settingsPresented)
        .accessibilityHidden(settingsPresented)
        .overlay {
            if settingsPresented {
                GeometryReader { geometry in
                    ZStack {
                        skeu.shadow.opacity(0.35).ignoresSafeArea().onTapGesture(perform: dismissSettings)
                        MacSettingsView(initialPage: archive ? "Archive" : nil, workspaceID: workspace, onClose: dismissSettings)
                            .frame(width: min(540, geometry.size.width - 48), height: min(740, geometry.size.height - 48))
                            .clipShape(RoundedRectangle(cornerRadius: SkeuRadius.lg, style: .continuous))
                            .skeuGlass(RoundedRectangle(cornerRadius: SkeuRadius.lg, style: .continuous), height: 37, frosted: true)
                            .shadow(color: skeu.shadow.opacity(0.22), radius: 30, y: 14)
                    }.frame(width: geometry.size.width, height: geometry.size.height)
                }.transition(.opacity)
            }
        }
        .overlay {
            if let photo = photoPreview.photo {
                MacPhotoViewer(photo: photo) { photoPreview.photo = nil }.id(photo.id)
            }
        }
        .environment(photoPreview)
        .environment(transfer)
        .onChange(of: transfer.targetFrame) { _, target in
            guard target != nil else { return }
            let session = transfer.sessionID
            withAnimation(reduceMotion ? nil : transfer.flight, completionCriteria: .removed) {
                transfer.flyToTarget()
            } completion: { transfer.finish(session: session) }
            Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(220))
                withAnimation(reduceMotion ? nil : SkeuMotion.layout) { transfer.lower(session: session) }
            }
        }
        .onChange(of: transfer.taskID) { if transfer.taskID != nil { dismissRowMenu(); closeWorkspaces() } }
        .onChange(of: workspace) { transfer.reset() }
        .onChange(of: showFocus) { transfer.reset() }
        .onChange(of: settingsPresented) { if settingsPresented { transfer.reset() } }
        .onDisappear { transfer.reset() }
        .background(EditingFocusDismissal())
        .background(WindowControlsVisibility(hidden: settingsPresented))
        .background(skeu.canvas).foregroundStyle(skeu.ink).font(.system(size: 15 * textScale))
        .animation(reduceMotion ? nil : SkeuMotion.present, value: settingsPresented)
        .animation(reduceMotion ? nil : SkeuMotion.layout, value: showFocus)
        .animation(reduceMotion ? nil : SkeuMotion.layout, value: workspace)
        .animation(reduceMotion ? nil : SkeuMotion.layout, value: allTasks.map { "\($0.id)-\($0.sortOrder)-\($0.dueDate?.description ?? "")" })
        .focusedSceneValue(\.settingsPresented, $settingsPresented)
        .focusedSceneValue(\.completedTasks, $archive)
        .focusedSceneValue(\.newTaskRequested, $newTaskRequest)
        .focusedSceneValue(\.searchRequested, $searchVisible)
        .onChange(of: settingsPresented) {
            if settingsPresented { NSApp.keyWindow?.makeFirstResponder(nil) }
        }
        .onChange(of: archive) { if archive { settingsPresented = true } }
        .onChange(of: searchVisible) {
            searchFocused = searchVisible
            if !searchVisible { search = "" }
        }
        .onChange(of: newTaskRequest) { archive = false }
        .task {
            // Never upload preview examples into a real iCloud account.
            if cloud.mode != .cloud { seed(); seedWorkspaces() }
        }
        .onChange(of: allTasks.map { "\($0.id)-\($0.isLiveNote)-\($0.isPinned)-\($0.isCompleted)-\($0.title)" }) { live.reloadFromStore() }
        .onChange(of: workspaces.map(\.id)) {
            if !workspaces.contains(where: { $0.id == workspace }) { workspace = Workspace.defaultID }
        }
        .alert("Couldn’t save this change", isPresented: Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })) {
            Button("OK") { errorMessage = nil }
        } message: { Text(errorMessage ?? "") }
    }

    private func dismissSettings() {
        NSApp.keyWindow?.makeFirstResponder(nil)
        withAnimation(reduceMotion ? nil : SkeuMotion.present) { settingsPresented = false; archive = false }
    }
    private func dismissRowMenu() {
        withAnimation(reduceMotion ? nil : SkeuMotion.layout) { rowMenu = nil }
    }
    private func boardDividers(size: CGSize) -> some View {
        let mainWidth = size.width - (showFocus ? 320 : 0)
        return ZStack(alignment: .topLeading) {
            ForEach(1...2, id: \.self) { index in
                Rectangle().fill(skeu.seam.opacity(0.25)).frame(width: 1, height: size.height)
                    .offset(x: mainWidth * CGFloat(index) / 3)
            }
            if showFocus {
                Rectangle().fill(skeu.seam.opacity(0.25)).frame(width: 1, height: size.height).offset(x: mainWidth)
            }
        }.allowsHitTesting(false)
    }
    private var taskColumns: some View {
        HStack(alignment: .top, spacing: 0) {
            ForEach(Bucket.line, id: \.self) { bucket in
                TaskColumn(bucket: bucket,
                    tasks: MacTaskActions.orderedForDisplay(tasks.filter { settings.visible($0, in: bucket) }),
                    newTaskRequest: $newTaskRequest,
                    add: { add($0, to: bucket) }, complete: complete,
                    focus: { live.activate($0); showFocus = true },
                    menu: { task, rect in
                        NSApp.keyWindow?.makeFirstResponder(nil)
                        withAnimation(reduceMotion ? nil : SkeuMotion.layout) { rowMenu = MacRowMenuRequest(task: task, row: rect) }
                    },
                    selectedMenuID: rowMenu?.task.id,
                    move: move, reorder: reorder, remove: remove,
                    release: finishBoardDrag)
            }
        }
    }
    private var boardHeader: some View {
        HStack(spacing: 12) {
            MacWorkspacePicker(selection: $workspace, isOpen: $workspaceOpen) { archive = false }
            Button {
                closeWorkspaces()
                dismissRowMenu()
                settingsPresented = true
            } label: {
                MacSettingsGear(active: settingsPresented)
            }.buttonStyle(GlassButton(circle: true))
                .help("Settings").accessibilityLabel("Settings")
            Spacer(minLength: 0)
            if searchVisible {
                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass").foregroundStyle(skeu.inkMuted)
                    TextField("Search", text: $search).textFieldStyle(.plain)
                        .focused($searchFocused)
                        .onExitCommand { search = ""; searchVisible = false }
                }.padding(.horizontal, 12).frame(width: 160, height: 34.6)
                    .skeuTrough(Capsule(), height: 34.6)
            }
            boardActions
        }.padding(.horizontal, 22).frame(height: SkeuTopBar.control)
    }
    private var boardActions: some View {
        Button { closeWorkspaces(); showFocus.toggle() } label: {
            MacLiveGlyph(tint: skeu.ink)
                .frame(width: MacLiveGlyph.diameter, height: MacLiveGlyph.diameter)
                .skeuPulse(live.note?.isPinned == true)
        }.buttonStyle(GlassButton(circle: true))
            .help(showFocus ? "Hide Live panel" : "Show Live panel")
            .accessibilityLabel(showFocus ? "Hide Live panel" : "Show Live panel")
    }
    private func closeWorkspaces() {
        withAnimation(reduceMotion ? nil : SkeuMotion.layout) { workspaceOpen = false }
    }

    private func save() { do { try context.save() } catch { errorMessage = error.localizedDescription } }
    private func add(_ title: String, to bucket: Bucket) {
        let clean = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty else { return }
        let task = TaskItem(); task.title = clean
        task.workspaceID = workspace == Workspace.defaultID ? nil : workspace
        task.dueDate = DateEngine.targetDate(for: bucket, now: .now, calendar: .current)
        task.sortOrder = (allTasks.map(\.sortOrder).max() ?? 0) + 100
        settings.place(task, in: bucket)
        context.insert(task); save()
    }
    private func complete(_ task: TaskItem) {
        NSApp.keyWindow?.makeFirstResponder(nil)
        withAnimation(reduceMotion ? nil : SkeuMotion.press) { _ = MacTaskActions.toggleCompleted(task) }
        save(); live.reloadFromStore()
    }
    private func move(_ task: TaskItem, to bucket: Bucket) {
        MacTaskActions.placeOnBoard(task, in: bucket, before: nil, tasks: allTasks, settings: settings)
        save(); live.reloadFromStore()
    }
    private func reorder(_ id: String, before target: TaskItem) -> Bool {
        guard let task = allTasks.first(where: { $0.id.uuidString == id }), task.id != target.id else { return false }
        MacTaskActions.reorder(task, before: target, tasks: allTasks, settings: settings)
        save(); return true
    }
    private func finishBoardDrag(velocity: CGSize) {
        guard let task = transfer.task else { return }
        if transfer.isOverLive, !live.completing, !task.isCompleted {
            NSApp.keyWindow?.makeFirstResponder(nil)
            transfer.prepareLive(velocity: velocity)
            live.activate(task, revealPopover: false)

            return
        }
        guard let drop = transfer.boardDrop else { transfer.returnHome(); return }
        if settings.bucket(for: task) == drop.section.bucket {
            let section = tasks.filter { !$0.isCompleted && settings.visible($0, in: drop.section.bucket) }
            let order = section.map(\.id)
            var preview = order.filter { $0 != task.id }
            let index = drop.before.flatMap { preview.firstIndex(of: $0) } ?? preview.count
            preview.insert(task.id, at: index)
            if order == preview { transfer.returnHome(); return }
        }
        withAnimation(reduceMotion ? nil : .easeOut(duration: 0.24)) { transfer.prepareBoard(velocity: velocity) }
        withAnimation(reduceMotion ? nil : MacTaskTransferCoordinator.listShift) {
            MacTaskActions.placeOnBoard(task, in: drop.section.bucket, before: drop.before, tasks: allTasks, settings: settings)
        }
        save()
    }
    private func remove(_ task: TaskItem) {
        _ = MacTaskActions.remove(task)
        save(); live.reloadFromStore()
    }
    private func seedWorkspaces() {
        for (id, name) in [(Workspace.defaultID, "Personal"), (Workspace.workID, "Work")] {
            // Work may intentionally have been deleted; only migrate the initial pair once.
            guard !UserDefaults.standard.bool(forKey: "mac.workspacesSeeded") else { return }
            if !workspaces.contains(where: { $0.id == id }) { context.insert(Workspace(id: id, name: name)) }
        }
        do { try context.save(); UserDefaults.standard.set(true, forKey: "mac.workspacesSeeded") }
        catch { errorMessage = error.localizedDescription }
    }
    private func seed() {
        guard !UserDefaults.standard.bool(forKey: "macDraftSeeded") else { return }
        let examples: [(String, Bucket, String)] = [
            ("Refine the to.morrow Mac layout", .today, Workspace.defaultID),
            ("Pick up the film scans", .today, Workspace.defaultID),
            ("Book a table for Friday", .today, Workspace.defaultID),
            ("Go for a walk", .today, Workspace.defaultID),
            ("Send the portfolio update", .tomorrow, Workspace.defaultID),
            ("Get groceries", .tomorrow, Workspace.defaultID),
            ("Plan the next little trip", .general, Workspace.defaultID),
            ("Read the book on my desk", .general, Workspace.defaultID),
            ("Review the new prototypes", .today, Workspace.workID),
            ("Prepare the workshop", .tomorrow, Workspace.workID)]
        for (index, item) in examples.enumerated() {
            let task = TaskItem(); task.title = item.0
            task.dueDate = DateEngine.targetDate(for: item.1, now: .now, calendar: .current)
            task.workspaceID = item.2 == Workspace.defaultID ? nil : item.2
            task.sortOrder = Double(index * 100); task.isImportant = index == 0
            context.insert(task)
        }
        do { try context.save(); UserDefaults.standard.set(true, forKey: "macDraftSeeded") }
        catch { errorMessage = error.localizedDescription }
    }
}

struct TaskColumn: View {
    @Environment(MacTaskTransferCoordinator.self) private var transfer
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @EnvironmentObject private var settings: MacSettings
    @Environment(\.skeu) private var skeu
    @Environment(\.skeuTextScale) private var textScale
    let bucket: Bucket
    let tasks: [TaskItem]
    @Binding var newTaskRequest: Bool
    let add: (String) -> Void
    let complete: (TaskItem) -> Void
    let focus: (TaskItem) -> Void
    let menu: (TaskItem, CGRect) -> Void
    let selectedMenuID: UUID?
    let move: (TaskItem, Bucket) -> Void
    let reorder: (String, TaskItem) -> Bool
    let remove: (TaskItem) -> Void
    let release: (CGSize) -> Void
    @State private var draft = ""
    @FocusState private var editing: Bool

    var body: some View {
        GeometryReader { columnGeometry in
        VStack(alignment: .leading, spacing: 9) {
            HStack(alignment: .firstTextBaseline) {
                Text(settings.name(bucket)).font(SkeuFont.at(16, weight: .medium, role: .chrome))
                Spacer()
            }.frame(height: SkeuTopBar.control).padding(.horizontal, 10)
                // Retain the heading baseline, but release its blank lower
                // slot so the visible heading-to-task gap is halved too.
                .padding(.bottom, -16)
            ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 6) {
                    ForEach(tasks.filter { !$0.isCompleted }) { task in
                        let source = transfer.isBoardPreview && transfer.taskID == task.id
                        VStack(spacing: 0) {
                            insertionGap(before: task.id)
                            TaskRow(task: task, bucket: bucket, menuSelected: selectedMenuID == task.id,
                                showMenu: { menu(task, $0) }, complete: { complete(task) }, focus: { focus(task) },
                                move: { move(task, $0) }, remove: { remove(task) }, release: release)
                                .opacity(transfer.taskID == task.id ? 0 : 1)
                        }.frame(height: source ? 0 : nil, alignment: .top)
                            .padding(.bottom, source ? -6 : 0).opacity(source ? 0 : 1)
                            .id(task.id.uuidString)
                    }
                    insertionGap(before: nil)
                    if tasks.contains(where: \.isCompleted) {
                        Color.clear.frame(height: 6)
                        ForEach(tasks.filter(\.isCompleted)) { task in
                            TaskRow(task: task, bucket: bucket, menuSelected: selectedMenuID == task.id,
                                showMenu: { menu(task, $0) }, complete: { complete(task) }, focus: { focus(task) },
                                move: { move(task, $0) }, remove: { remove(task) }, release: release)
                                .id(task.id.uuidString)
                        }
                    }
                    HStack(spacing: MacTaskMetrics.checkRight) {
                        Button { editing = true } label: {
                            MacTaskCheck(tint: skeu.inkFaint)
                        }.buttonStyle(MacSkeuTapStyle()).accessibilityLabel("Add task to \(bucket.displayName)")
                        TextField("", text: $draft,
                                  prompt: Text("add").foregroundStyle(skeu.inkFaint), axis: .vertical)
                            .textFieldStyle(.plain).lineLimit(1...4)
                            .font(SkeuFont.at(MacTaskMetrics.label * textScale)).tracking(-0.02 * MacTaskMetrics.label).foregroundStyle(skeu.ink)
                            .focused($editing)
                            .onSubmit(commitDraft)
                            .onKeyPress(.return) { commitDraft(); return .handled }
                    }.padding(.leading, MacTaskMetrics.checkLeft).padding(.trailing, 0).padding(.vertical, (44 * MacTaskMetrics.scale - SkeuControl.minTouch) / 2)

                }.padding(.horizontal, 4).padding(.bottom, 8)
                    .frame(width: max(0, columnGeometry.size.width - 28), alignment: .leading)
                    .background(MacScrollIndicators())
                    .animation(reduceMotion ? nil : MacTaskTransferCoordinator.displace, value: transfer.boardDrop)
                    .animation(reduceMotion ? nil : MacTaskTransferCoordinator.displace, value: transfer.isBoardDrag)
                    .animation(reduceMotion ? nil : MacTaskTransferCoordinator.displace, value: transfer.phase)
            }
            .scrollIndicators(.hidden)
            .scrollDisabled(transfer.taskID != nil)
            .onGeometryChange(for: CGRect.self) { $0.frame(in: .named("macBoard")) } action: { transfer.recordBoardViewport($0, in: bucket) }
            .onChange(of: transfer.destination) {
                guard transfer.destination == bucket, let id = transfer.taskID else { return }
                Task { @MainActor in
                    await Task.yield()
                    guard transfer.taskID == id, transfer.isWaiting else { return }
                    var transaction = Transaction(animation: nil); transaction.disablesAnimations = true
                    withTransaction(transaction) { proxy.scrollTo(id.uuidString, anchor: .center) }
                }
            }
            .task(id: transfer.isBoardDrag) {
                while transfer.isBoardDrag, transfer.phase == .dragging, !Task.isCancelled {
                    if let target = transfer.boardScrollTarget(in: bucket, order: tasks.map(\.id)) {
                        withAnimation(reduceMotion ? nil : .linear(duration: 0.12)) {
                            proxy.scrollTo(target.id.uuidString, anchor: target.downward ? .bottom : .top)
                        }
                    }
                    try? await Task.sleep(for: .milliseconds(120))
                }
            }
            }
        }.padding(.horizontal, 14).padding(.top, 6)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .onChange(of: newTaskRequest) { if bucket == .today { editing = true } }
        }
    }

    @ViewBuilder private func insertionGap(before id: UUID?) -> some View {
        let height = transfer.boardGapHeight(in: .init(bucket: bucket), before: id, rowGap: id == nil ? 0 : 6)
        if height > 0 {
            Color.clear.frame(height: height)
                .onGeometryChange(for: CGRect.self) { $0.frame(in: .named("macBoard")) } action: {
                    transfer.recordBoardGap($0, drop: .init(section: .init(bucket: bucket), before: id))
                }
                .allowsHitTesting(false).accessibilityHidden(true)
        }
    }

    private func commitDraft() {
        guard !draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        add(draft); draft = ""
    }
}

struct TaskRow: View {
    @Environment(MacTaskTransferCoordinator.self) private var transfer
    @Environment(\.skeu) private var skeu
    @Environment(\.skeuTextScale) private var textScale
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.modelContext) private var context
    @Bindable var task: TaskItem
    let bucket: Bucket
    let menuSelected: Bool
    var carried = false
    let showMenu: (CGRect) -> Void
    let complete: () -> Void
    let focus: () -> Void
    let move: (Bucket) -> Void
    let remove: () -> Void
    let release: (CGSize) -> Void
    @State private var showingAttachments = false
    @State private var hover = false
    @State private var rowFrame: CGRect = .zero
    @GestureState private var isHolding = false
    @FocusState private var editing: Bool
    private var liveLanding: Bool { carried && transfer.isLiveLanding }
    private var marked: Bool { menuSelected || isHolding || (carried && transfer.isLifted) }
    // Anchor the first line instead of recentering the editor whenever its
    // intrinsic height changes (including AppKit's caret/layout updates).
    private var titleInset: CGFloat { max(0, (SkeuControl.minTouch - MacTaskMetrics.label * textScale * 1.2) / 2) }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
        HStack(alignment: liveLanding ? .center : .top, spacing: liveLanding ? 0 : MacTaskMetrics.gap) {
            HStack(alignment: liveLanding ? .center : .top, spacing: liveLanding ? 0 : MacTaskMetrics.checkRight) {
                MacTaskCheck(completed: task.isCompleted, tint: task.isCompleted ? skeu.inkMuted : (task.isImportant ? skeu.critical : skeu.ink), important: task.isImportant && !task.isCompleted)
                    .frame(width: liveLanding ? 0 : nil).clipped().opacity(liveLanding ? 0 : 1)
                    .onTapGesture(perform: complete)
                    .accessibilityAddTraits(.isButton)
                    .accessibilityAction { complete() }
                    .accessibilityLabel(task.isCompleted ? "Restore \(task.title)" : "Complete \(task.title)")
                title
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, liveLanding ? 0 : titleInset)
            }.contentShape(Rectangle())
                // The grip is a sibling, never a child of the menu gesture.
                .simultaneousGesture(LongPressGesture(minimumDuration: 0.45, maximumDistance: 12)
                    .updating($isHolding) { value, state, _ in state = value }
                    .onEnded { _ in
                        guard !carried, transfer.taskID == nil else { return }
                        editing = false; showMenu(rowFrame)
                    })
            if carried ? transfer.carriedWasLive : (task.isLiveNote && !task.isCompleted) {
                MacLiveGlyph(tint: task.isImportant && !liveLanding ? skeu.critical : skeu.ink)
                    .frame(width: liveLanding ? 0 : MacLiveGlyph.diameter, height: MacLiveGlyph.diameter).skeuPulse(task.isPinned)
                    .opacity(liveLanding ? 0 : 1)
                    .padding(.top, liveLanding ? 0 : (SkeuControl.minTouch - 18.5) / 2)
                    .allowsHitTesting(false).accessibilityLabel(task.isPinned ? "Live task" : "Live task, off air")
            }
            if !task.isCompleted {
            if (editing || showingAttachments) && !carried {
                MacAttachmentButton(task: task, keepEditing: { editing = true }, presenting: $showingAttachments)
                    .frame(width: 28, height: SkeuControl.minTouch, alignment: .center)
            } else {
            Image(systemName: "line.3.horizontal").font(.system(size: 18.5))
                .foregroundStyle(skeu.inkMuted.opacity(hover || carried ? 1 : 0.35))
                .frame(width: liveLanding ? 0 : 28, height: SkeuControl.minTouch).clipped().opacity(liveLanding ? 0 : 1)
                .contentShape(Rectangle()).macGrabCursor()
                .highPriorityGesture(DragGesture(minimumDistance: 0, coordinateSpace: .named("macBoard"))
                    .onChanged { value in
                        guard !carried, transfer.liftBoard(task, from: rowFrame) else { return }
                        editing = false
                        transfer.trackBoard(value.translation, at: value.location)
                    }
                    .onEnded { value in
                        guard !carried, transfer.taskID == task.id, transfer.phase == .dragging else { return }
                        release(value.velocity)
                    })
                .accessibilityLabel("Drag \(task.title)")
            }
            }
        }
        if !task.orderedPhotos.isEmpty && !liveLanding {
            MacTaskPhotoStrip(task: task)
                .padding(.leading, SkeuControl.minTouch + MacTaskMetrics.checkRight)
        }
        }.padding(.leading, liveLanding ? 20 : MacTaskMetrics.checkLeft).padding(.trailing, liveLanding ? 20 : 0)
            .padding(.vertical, liveLanding ? 20 : (44 * MacTaskMetrics.scale - SkeuControl.minTouch) / 2)
            .frame(maxHeight: liveLanding ? .infinity : nil)
            .background {
                RoundedRectangle(cornerRadius: SkeuRadius.md, style: .continuous)
                    .fill(skeu.isDark ? skeu.materialTop : skeu.recess)
                    .opacity(liveLanding ? 0 : (marked ? (skeu.isDark ? 0.55 : 0.35) : (hover && !carried ? 0.12 : 0)))
                    .animation(carried && !transfer.isLifted && !reduceMotion ? .easeOut(duration: 0.24) : SkeuMotion.tint, value: marked)
            }
            .background {
                if carried { RoundedRectangle(cornerRadius: SkeuRadius.md, style: .continuous).fill(skeu.canvas).opacity(liveLanding ? 0 : 1) }
            }
            .scaleEffect(reduceMotion ? 1 : (isHolding ? 0.97 : 1))
            .animation(reduceMotion ? nil : SkeuMotion.press, value: isHolding)
            .onGeometryChange(for: CGRect.self) { $0.frame(in: .named("macBoard")) } action: { frame in
                guard !carried else { return }
                rowFrame = frame
                if !task.isCompleted {
                    transfer.recordBoardRow(frame, id: task.id, section: .init(bucket: bucket))
                    transfer.report(frame, taskID: task.id, in: bucket)
                }
            }
            .onDisappear { if !carried { transfer.forgetBoardRow(task.id, section: .init(bucket: bucket)) } }
            .onHover { hover = $0 }
            .accessibilityAction(named: Text("Task actions")) {
                guard !carried, transfer.taskID == nil else { return }
                editing = false; showMenu(rowFrame)
            }
    }
    @ViewBuilder private var title: some View {
        Group {
            if task.isCompleted {
                Text(task.title).strikethrough(color: skeu.inkMuted)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else if carried { Text(task.title).multilineTextAlignment(liveLanding ? .center : .leading)
                    .frame(maxWidth: .infinity, alignment: liveLanding ? .center : .leading) }
            else {
                TextField("Task", text: $task.title, axis: .vertical)
                    .textFieldStyle(.plain).focused($editing)
                    .onSubmit { editing = false; try? context.save() }
                    .onChange(of: editing) { if !editing { try? context.save() } }
            }
        }.font(SkeuFont.at((liveLanding ? 22 : MacTaskMetrics.label) * textScale, weight: liveLanding ? .medium : (task.isImportant && !task.isCompleted ? .semibold : .regular)))
            .tracking(liveLanding ? 0 : -0.02 * MacTaskMetrics.label).lineLimit(1...).strikethrough(task.isCompleted)
            .foregroundStyle(task.isCompleted ? skeu.inkMuted : (task.isImportant && !liveLanding ? skeu.critical : skeu.ink))
    }
}
