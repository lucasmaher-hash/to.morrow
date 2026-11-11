import AppKit
import SwiftUI
import SwiftData
import Shove95Kit
import Combine

/// One Live note shared by every Mac window and its persistent menu-bar control.
/// Uses the iOS model flags, but never starts an iPhone ActivityKit activity.
@MainActor
final class MacLiveController: NSObject, ObservableObject, NSPopoverDelegate {
    @Published private(set) var note: TaskItem?
    @Published private(set) var completing = false
    @Published private(set) var stroke: CGFloat = 0
    @Published private(set) var completionOpacity: Double = 1
    @Published var error: String?
    @Published private(set) var removed: TaskItem?
    private let context: ModelContext
    private let settings: MacSettings
    private var preferenceObserver: AnyCancellable?
    private var item: NSStatusItem!
    private let popover = NSPopover()
    private var completion: Task<Void, Never>?
    private var localDismissMonitor: Any?
    private var globalDismissMonitor: Any?
    private var activationObserver: AnyCancellable?

    init(context: ModelContext, presentUI: Bool = true, settings: MacSettings? = nil) {
        self.context = context
        self.settings = settings ?? MacSettings()
        super.init()
        note = (try? context.fetch(FetchDescriptor<TaskItem>(predicate: #Predicate { $0.isLiveNote && !$0.isCompleted })))?.first
        guard presentUI else { return }
        item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        item.button?.target = self
        item.button?.action = #selector(toggle)
        // Own dismissal so a status-button click cannot auto-close on mouse
        // down and reopen again when the button action arrives.
        item.button?.sendAction(on: .leftMouseDown)
        item.button?.image?.isTemplate = true
        popover.behavior = .applicationDefined
        popover.animates = true
        popover.delegate = self
        popover.contentViewController = NSHostingController(rootView: SkeuHost(settings: self.settings) { MacLivePanel(live: self) })
        preferenceObserver = self.settings.$menuTitle.combineLatest(self.settings.$face).receive(on: RunLoop.main).sink { [weak self] _ in
            Task { @MainActor in self?.refreshLabel() }
        }
        refreshLabel()
    }

    /// Remote changes can replace/complete Live while this process stays open.
    func reloadFromStore() {
        guard !completing else { return }
        note = (try? context.fetch(FetchDescriptor<TaskItem>(
            predicate: #Predicate { $0.isLiveNote && !$0.isCompleted },
            sortBy: [SortDescriptor(\TaskItem.createdAt, order: .reverse)])))?.first
        refreshLabel()
    }

    @objc private func toggle() {
        if popover.isShown { popover.performClose(nil) } else { show() }
    }

    func show() {
        reloadFromStore()
        guard let button = item?.button else { return }
        guard !popover.isShown else { return }
        NSApp.activate()
        popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        popover.contentViewController?.view.window?.makeKey()
        button.highlight(true)
        installDismissal()
    }

    func popoverWillClose(_ notification: Notification) {
        popover.contentViewController?.view.window?.makeFirstResponder(nil)
        NotificationCenter.default.post(name: .livePopoverWillClose, object: self)
        item?.button?.highlight(false)
        if let localDismissMonitor { NSEvent.removeMonitor(localDismissMonitor) }
        if let globalDismissMonitor { NSEvent.removeMonitor(globalDismissMonitor) }
        localDismissMonitor = nil; globalDismissMonitor = nil; activationObserver = nil
    }

    private func installDismissal() {
        guard localDismissMonitor == nil else { return }
        localDismissMonitor = NSEvent.addLocalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown, .keyDown]) { [weak self] event in
            guard let self, self.popover.isShown else { return event }
            if event.type == .keyDown {
                if event.keyCode == 53 { self.popover.performClose(nil); return nil }
                return event
            }
            // Status clicks are handled once by the button's mouse-down action.
            if event.window === self.item?.button?.window { return event }
            if event.window !== self.popover.contentViewController?.view.window { self.popover.performClose(nil) }
            return event
        }
        globalDismissMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            MainActor.assumeIsolated { self?.popover.performClose(nil) }
        }
        activationObserver = NotificationCenter.default.publisher(for: NSApplication.didResignActiveNotification)
            .sink { [weak self] _ in MainActor.assumeIsolated { self?.popover.performClose(nil) } }
    }

    func activate(_ task: TaskItem, revealPopover: Bool = false) {
        guard !completing, !task.isCompleted else { return }
        do {
            let arriving = task.bucket(now: .now, calendar: .current) != .today
            let all = try context.fetch(FetchDescriptor<TaskItem>())
            if arriving {
                task.sortOrder = (all.filter { $0.id != task.id && $0.workspaceID == task.workspaceID && $0.bucket(now: .now, calendar: .current) == .today }.map(\.sortOrder).max() ?? 0) + 100
            }
            // Replacing Live only removes focus; the previous task stays in Today.
            for held in try context.fetch(FetchDescriptor<TaskItem>()) where held.id != task.id && (held.isPinned || held.isLiveNote) && !held.isCompleted {
                if held.isLiveNote { held.dueDate = DateEngine.targetDate(for: .today, now: .now, calendar: .current) }
                held.isLiveNote = false; held.isPinned = false
            }
            task.dueDate = DateEngine.targetDate(for: .today, now: .now, calendar: .current)
            settings.place(task, in: .today)
            task.isLiveNote = true; task.isPinned = true
            try context.save()
            note = task; stroke = 0; error = nil; refreshLabel(); if revealPopover { show() }
        } catch { self.error = error.localizedDescription }
    }

    func write(_ raw: String, workspaceID: String? = nil) {
        guard !completing else { return }
        let title = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty else { return }
        if let note {
            note.title = title
            persist()
        } else {
            let task = TaskItem(); task.title = title; task.workspaceID = workspaceID
            context.insert(task); activate(task)
        }
    }

    /// Matches the iPhone commit boundary: Return, Go or leaving the field.
    /// An empty draft ends the current note; a stale editor cannot replace a
    /// newer note received from another presentation or device.
    @discardableResult
    func commitDraft(_ raw: String, editingNoteID: UUID?, workspaceID: String? = nil) -> Bool {
        guard !completing else { return false }
        if let editingNoteID, note?.id != editingNoteID { return false }
        let title = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if title.isEmpty {
            guard let task = note else { return true }
            context.delete(task)
            do { try context.save(); note = nil; error = nil; refreshLabel(); return true }
            catch { context.rollback(); self.error = error.localizedDescription; return false }
        }
        if title != note?.title { write(title, workspaceID: workspaceID) }
        return error == nil
    }

    @discardableResult
    func completeDraft(_ raw: String, editingNoteID: UUID?, workspaceID: String? = nil) -> Task<Void, Never>? {
        guard !raw.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              commitDraft(raw, editingNoteID: editingNoteID, workspaceID: workspaceID) else { return nil }
        return complete()
    }

    func setVisible(_ visible: Bool) {
        guard !completing, let note else { return }
        note.isPinned = visible; persist()
    }

    func clear() {
        guard !completing, let task = note else { return }
        task.isPinned = false; task.isLiveNote = false; task.isCompleted = true; task.completedAt = .now
        // A removed Live note stays recoverable in Completed, rather than
        // destroying an existing task or its photo attachments.
        do {
            try context.save(); removed = task; note = nil; refreshLabel()
        } catch { context.rollback(); self.error = error.localizedDescription }
    }

    func undoClear() {
        guard let task = removed, note == nil else { return }
        task.isCompleted = false; task.completedAt = nil
        activate(task); removed = nil
    }

    private func persist() {
        do { try context.save(); error = nil; objectWillChange.send(); refreshLabel() }
        catch { self.error = error.localizedDescription }
    }

    private func refreshLabel() {
        guard let button = item?.button else { return }
        let glyph = MacLiveGlyph(tint: .black).environmentObject(settings)
            .frame(width: MacLiveGlyph.diameter, height: MacLiveGlyph.diameter)
        let renderer = ImageRenderer(content: glyph)
        renderer.scale = 2
        if let image = renderer.cgImage {
            button.image = NSImage(cgImage: image, size: NSSize(width: MacLiveGlyph.diameter, height: MacLiveGlyph.diameter))
        }
        button.image?.isTemplate = true
        button.imagePosition = .imageLeading
        button.title = note?.isPinned == true && settings.menuTitle ? "  " + String((note?.title ?? "").prefix(26)) : ""
        button.toolTip = note?.isPinned == true ? note?.title : "to.morrow — open Live"
        button.setAccessibilityLabel(note?.isPinned == true ? "to.morrow Live: \(note?.title ?? "")" : "to.morrow Live")
    }

    @discardableResult
    func complete() -> Task<Void, Never>? {
        guard let task = note, !completing else { return nil }
        let reduce = NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
        completing = true; stroke = 0; completionOpacity = 1; error = nil
        completion = Task { @MainActor [weak self] in
            guard let self else { return }
            do {
                try await Task.sleep(for: .milliseconds(reduce ? 0 : 70))
                withAnimation(reduce ? nil : .linear(duration: 0.65)) { self.stroke = 1 }
                try await Task.sleep(for: .milliseconds(reduce ? 0 : 650))
                // Keep the fully crossed-out task readable for a full second.
                try await Task.sleep(for: .seconds(1))
                withAnimation(reduce ? nil : .easeOut(duration: 0.30)) { self.completionOpacity = 0 }
                try await Task.sleep(for: .milliseconds(reduce ? 0 : 300))
                guard self.note?.id == task.id else {
                    self.completing = false; self.stroke = 0; self.completionOpacity = 1; return
                }
                task.isCompleted = true; task.completedAt = .now; task.isPinned = false
                task.isLiveNote = false; task.overduePlaced = false
                task.dueDate = DateEngine.targetDate(for: .today, now: .now, calendar: .current)
                do { try self.context.save() }
                catch {
                    self.context.rollback(); self.error = error.localizedDescription
                    self.completing = false; self.stroke = 0; self.completionOpacity = 1; return
                }
                self.popover.performClose(nil)
                self.note = nil; self.refreshLabel()
                self.completing = false; self.stroke = 0; self.completionOpacity = 1
                self.reloadFromStore()
            } catch { self.completing = false; self.stroke = 0; self.completionOpacity = 1 }
        }
        return completion
    }

}

struct MacLivePanel: View {
    @ObservedObject var live: MacLiveController
    @Environment(\.skeu) private var skeu
    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack {
                HStack(spacing: SkeuSpace.sm) {
                    MacLiveGlyph(tint: skeu.ink).frame(width: 14, height: 14)
                    Text("Live").font(.system(size: 14, weight: .medium))
                }
                Spacer()
            }
            LiveWell(live: live)
        }.padding(22).frame(width: 360).background(skeu.canvas).foregroundStyle(skeu.ink)
    }
}

/// The mobile Live field's geometry and EXACT trough parameters are retained.
/// Board and menu-bar presentations share editing and completion controls.
struct LiveWell: View {
    @ObservedObject var live: MacLiveController
    @Environment(\.skeu) private var skeu
    @Environment(\.skeuTextScale) private var textScale
    var workspaceID: String? = nil
    var transfer: MacTaskTransferCoordinator? = nil
    @State private var draft = ""
    @State private var editingNoteID: UUID?
    @FocusState private var focused: Bool
    @State private var ownerWindow: NSWindow?
    var body: some View {
        VStack(spacing: 20) {
            Group {
                if live.completing {
                    Text(live.note?.title ?? draft).font(SkeuFont.at(22 * textScale, weight: .medium))
                        .textRenderer(LiveStrikeRenderer(progress: live.stroke))
                } else {
                    // Keep the editor mounted even before it receives focus.
                    // Gating its existence on its own FocusState loses the
                    // first click before AppKit can create a field editor.
                    TextField("", text: $draft, axis: .vertical)
                        .accessibilityLabel("Live task")
                        .accessibilityHint("What are you doing?")
                        .multilineTextAlignment(.center)
                        .textFieldStyle(.plain).font(SkeuFont.at(22 * textScale, weight: .medium))
                        .frame(maxWidth: .infinity)
                        .overlay {
                            // AppKit's native placeholder ignores multiline
                            // alignment. Draw it in the same centred field slot.
                            if draft.isEmpty {
                                Text("What are you doing?")
                                    .font(SkeuFont.at(22 * textScale, weight: .medium))
                                    .foregroundStyle(skeu.inkFaint)
                                    .multilineTextAlignment(.center)
                                    .frame(maxWidth: .infinity, alignment: .center)
                                    .allowsHitTesting(false).accessibilityHidden(true)
                            }
                        }
                        .focused($focused).onSubmit { commit(); focused = false }
                        .onChange(of: draft) { _, value in
                            if value.contains("\n") { draft = value.replacingOccurrences(of: "\n", with: " "); commit(); focused = false }
                        }

                }
            }
            .opacity(transfer?.isLiveTransfer == true ? 0 : live.completionOpacity)
            .multilineTextAlignment(.center).foregroundStyle(skeu.ink)
            .frame(maxWidth: .infinity).padding(20).frame(height: 260)
            .skeuTrough(RoundedRectangle(cornerRadius: SkeuRadius.lg, style: .continuous), height: 64, fillStop: 0.26, shadeScale: 0.65, fillLift: 0.55)
            .onGeometryChange(for: CGRect.self) { $0.frame(in: .named("macBoard")) } action: { transfer?.recordLiveWell($0) }
            .onDisappear { transfer?.recordLiveWell(nil) }
            .contentShape(RoundedRectangle(cornerRadius: SkeuRadius.lg)).onTapGesture { if !live.completing { focused = true } }
            HStack(spacing: SkeuSpace.md) {
                Button(action: toggleLive) {
                    Group {
                        if live.note == nil && !draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            HStack(spacing: SkeuSpace.sm) {
                                MacLiveGlyph(tint: skeu.ink)
                                    .frame(width: MacLiveGlyph.diameter, height: MacLiveGlyph.diameter)
                                Text("Go").font(SkeuFont.at(SkeuToggle.label * textScale, weight: .medium))
                            }
                        } else {
                            HStack(spacing: SkeuSpace.sm) {
                                MacLiveGlyph(tint: onAir ? skeu.ink : skeu.inkMuted)
                                    .frame(width: MacLiveGlyph.diameter, height: MacLiveGlyph.diameter)
                                Text(onAir ? "Live" : "Off air")
                                    .font(SkeuFont.at(SkeuToggle.label * textScale, weight: .medium))
                                    .foregroundStyle(onAir ? skeu.ink : skeu.inkMuted)
                            }.skeuPulse(onAir).opacity(onAir ? 1 : 0.55)
                                .animation(SkeuMotion.tint, value: onAir)
                        }
                    }.padding(.horizontal, SkeuSpace.lg)
                        .frame(maxWidth: .infinity).frame(height: SkeuTopBar.control)
                        .skeuGlass(Capsule(), height: SkeuTopBar.control, prominent: true)
                        .contentShape(Capsule())
                }.buttonStyle(MacSkeuTapStyle())
                    .accessibilityLabel(onAir ? "Showing in the menu bar" : "Show task in menu bar")
                Button {
                    live.completeDraft(draft, editingNoteID: editingNoteID, workspaceID: workspaceID)
                    focused = false
                } label: {
                    SkeuChromeGlyph(kind: .check, face: SkeuFont.face, size: 15.4, tint: skeu.ink)
                        .foregroundStyle(skeu.ink).opacity(hasText ? 1 : 0.55)
                        .animation(SkeuMotion.tint, value: hasText)
                        .frame(width: SkeuTopBar.control, height: SkeuTopBar.control)
                        .skeuGlass(Circle(), height: SkeuTopBar.control)
                        .contentShape(Circle())
                }.buttonStyle(MacSkeuTapStyle())
                    .disabled(!hasText).help("Complete Live task").accessibilityLabel("Complete Live task")
            }.disabled(live.completing)
            if let error = live.error { Text(error).font(.system(size: 12)).foregroundStyle(skeu.critical) }
        }
        .background(LiveWindowReader { ownerWindow = $0 })
        .onChange(of: focused) { _, isFocused in
            if isFocused { editingNoteID = live.note?.id } else { commit() }
        }
        .onReceive(NotificationCenter.default.publisher(for: .livePopoverWillClose)) { _ in
            if focused { commit(); focused = false }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSWindow.didResignKeyNotification)) { notification in
            guard let window = notification.object as? NSWindow, window === ownerWindow else { return }
            if focused { commit(); focused = false }
        }
        .onDisappear { if focused { commit(); focused = false } }
        .onAppear { draft = live.note?.title ?? "" }
        .onChange(of: live.note?.id) { if !focused { draft = live.note?.title ?? "" } }
        .onChange(of: live.note?.title) { _, title in if !focused { draft = title ?? "" } }
    }
    private var onAir: Bool { live.note?.isPinned == true }
    private var hasText: Bool { !draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    private func toggleLive() {
        guard !live.completing else { return }
        if live.note != nil { live.setVisible(!onAir) }
        else if hasText { commit(); focused = false }
        else { focused = true }
    }
    private func commit() {
        if !live.commitDraft(draft, editingNoteID: editingNoteID, workspaceID: workspaceID) {
            draft = live.note?.title ?? ""
        }
    }
}

/// Draw against the actual text-line bounds, so a wrapped title is fully
/// readable and each strike starts at the line's left edge, never its centre.
struct LiveStrikeRenderer: TextRenderer, Animatable {
    @Environment(\.skeu) private var skeu
    var progress: CGFloat
    var animatableData: CGFloat {
        get { progress }
        set { progress = newValue }
    }
    func draw(layout: Text.Layout, in context: inout GraphicsContext) {
        for line in layout {
            for run in line { context.draw(run) }
            let bounds = line.typographicBounds.rect
            var path = Path()
            path.move(to: CGPoint(x: bounds.minX, y: bounds.midY))
            path.addLine(to: CGPoint(x: bounds.minX + bounds.width * max(0, min(1, progress)), y: bounds.midY))
            context.stroke(path, with: .color(skeu.ink), style: StrokeStyle(lineWidth: progress > 0 ? 1.5 : 0, lineCap: .round))
        }
    }
}


private extension Notification.Name {
    static let livePopoverWillClose = Notification.Name("to.morrow.livePopoverWillClose")
}

/// Scope key-window notifications to this Live editor's own presentation.
private struct LiveWindowReader: NSViewRepresentable {
    let changed: (NSWindow?) -> Void
    func makeNSView(context: Context) -> Probe { let view = Probe(); view.changed = changed; return view }
    func updateNSView(_ view: Probe, context: Context) { view.changed = changed }
    static func dismantleNSView(_ view: Probe, coordinator: ()) { MacEditingRegions.views.remove(view); view.changed?(nil) }
    final class Probe: NSView {
        var changed: ((NSWindow?) -> Void)?
        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            MacEditingRegions.views.remove(self)
            if window != nil { MacEditingRegions.views.add(self) }
            DispatchQueue.main.async { [weak self] in self?.changed?(self?.window) }
        }
        override func hitTest(_ point: NSPoint) -> NSView? { nil }
    }
}
