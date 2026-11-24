import SwiftUI
import SwiftData
import Shove95Kit

/// Shared sheet construction for Settings and every page opened from it.
/// Fixed header; content and its shadows dissolve beneath the same dock.
struct MacSheetPage<Content: View>: View {
    let title: String
    let close: () -> Void
    var showsScrollIndicators = false
    @EnvironmentObject private var settings: MacSettings
    @ViewBuilder var content: Content
    @Environment(\.skeu) private var skeu
    @State private var scrolled = false
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text(title).font(SkeuFont.title3Chrome).id(settings.face)
                Spacer(minLength: SkeuSpace.sm)
                Button(action: close) {
                    SkeuChromeGlyph(kind: .close, face: settings.face == "Retro" ? .blend : .system, size: SkeuTopBar.icon, tint: skeu.ink)
                }.buttonStyle(GlassButton(circle: true))
                    .accessibilityLabel("Close \(title.lowercased())")
            }
            .padding(.horizontal, SkeuTopBar.margin).padding(.vertical, 12)
            .background(skeu.canvas).zIndex(1)
            ScrollView {
                content
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, SkeuTopBar.margin)
                    .padding(.top, SkeuSpace.xl).padding(.bottom, 46)
                    .background(MacScrollIndicators(hidden: !showsScrollIndicators))
            }.scrollIndicators(showsScrollIndicators ? .visible : .hidden)
                .onScrollGeometryChange(for: Bool.self) { $0.contentOffset.y > 0.5 } action: { _, value in scrolled = value }
                .mask(alignment: .top) {
                    VStack(spacing: 0) {
                        LinearGradient(colors: [.clear, .black], startPoint: .top, endPoint: .bottom)
                            .frame(height: scrolled ? 28 : 20)
                        Rectangle()
                    }
                }
                .id(title)
        }.frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(skeu.canvas).foregroundStyle(skeu.ink)
            .onExitCommand(perform: close)
    }
}

struct MacReadOnlyWell<Content: View>: View {
    let title: String
    var prominent = false
    @ViewBuilder var content: Content
    @Environment(\.skeu) private var skeu
    @Environment(\.skeuTextScale) private var scale
    var body: some View {
        VStack(alignment: .leading, spacing: SkeuSpace.sm) {
            Text(title.uppercased())
                .font(prominent ? SkeuFont.at(12.8 * scale * 1.3, weight: .bold) : SkeuFont.eyebrow)
                .tracking(0.8).foregroundStyle(prominent ? skeu.ink : skeu.inkFaint)
                .padding(.leading, SkeuSpace.sm)
            content.padding(21.3).frame(maxWidth: .infinity, alignment: .leading)
                .skeuTrough(RoundedRectangle(cornerRadius: 30, style: .continuous), height: 56,
                            fillStop: 0.20, shadeScale: 0.42, fillLift: 0.70)
        }
    }
}

struct MacArchiveContent: View {
    let tasks: [TaskItem]
    let delete: (TaskItem) -> Void
    @Environment(\.skeu) private var skeu
    @Environment(\.skeuTextScale) private var scale
    private var days: [(date: Date, tasks: [TaskItem])] {
        Dictionary(grouping: tasks.filter { $0.isArchived(now: .now, calendar: .current) }) {
            Calendar.current.startOfDay(for: $0.completedAt ?? $0.createdAt)
        }.map { (date: $0.key, tasks: $0.value.sorted { ($0.completedAt ?? .distantPast) > ($1.completedAt ?? .distantPast) }) }
            .sorted { $0.date > $1.date }
    }
    var body: some View {
        let statistics = CompletionStatistics(tasks: tasks)
        LazyVStack(alignment: .leading, spacing: SkeuSpace.lg) {
            Text("\(statistics.total) \(statistics.total == 1 ? "task" : "tasks") completed in total · ~\(statistics.dailyAverage.formatted(.number.precision(.fractionLength(1)))) / day")
                .font(SkeuFont.at(12.8 * scale)).foregroundStyle(skeu.inkMuted)
            if days.isEmpty {
                Text("(empty)").font(SkeuFont.at(12.8 * scale)).foregroundStyle(skeu.inkFaint)
                    .frame(maxWidth: .infinity, minHeight: 160, alignment: .leading)
            }
            ForEach(days, id: \.date) { day in
                MacReadOnlyWell(title: day.date.formatted(.dateTime.weekday(.abbreviated).day().month(.abbreviated))) {
                    VStack(spacing: SkeuSpace.sm) {
                        ForEach(day.tasks) { task in
                            HStack(spacing: SkeuSpace.sm) {
                                Text(task.title).font(SkeuFont.at(12.8 * scale))
                                    .strikethrough(color: skeu.inkFaint).foregroundStyle(skeu.inkMuted)
                                    .fixedSize(horizontal: false, vertical: true)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                Button { delete(task) } label: {
                                    Text("Delete").foregroundStyle(skeu.critical)
                                }.buttonStyle(GlassButton(diameter: 30))
                                    .accessibilityLabel("Delete \(task.title) from the archive")
                            }.frame(minHeight: SkeuControl.minTouch)
                        }
                    }
                }
            }
        }
    }
}

struct MacAboutContent: View {
    @Environment(\.skeu) private var skeu
    @Environment(\.skeuTextScale) private var scale
    private var version: String { Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0.1" }
    private var build: String { Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "1" }
    var body: some View {
        VStack(alignment: .leading, spacing: SkeuSpace.lg) {
            VStack(alignment: .leading, spacing: SkeuSpace.sm) {
                Text("to.morrow").font(SkeuFont.display)
                Text("Version \(version) (\(build))").foregroundStyle(skeu.inkMuted)
                Text("Today, Tomorrow, Soon and Live. Drag a task to move it between sections.")
                    .foregroundStyle(skeu.inkMuted).padding(.top, SkeuSpace.xs)
            }
            VStack(alignment: .leading, spacing: SkeuSpace.sm) {
                Text("CREDITS").font(SkeuFont.eyebrow).tracking(0.8).foregroundStyle(skeu.inkFaint)
                VStack(alignment: .leading, spacing: SkeuSpace.md) {
                    Text("Typeface: W95FA by Alina Sava (SIL OFL)").foregroundStyle(skeu.inkMuted)
                    Link("Rate the app", destination: URL(string: "https://apps.apple.com/app/id6798337661?action=write-review")!)
                        .buttonStyle(GlassButton(diameter: 38)).padding(.top, SkeuSpace.sm)
                    Link("Privacy policy", destination: URL(string: "https://lucasmaher-hash.github.io/to.morrow/privacy.html")!)
                        .buttonStyle(GlassButton(diameter: 38)).padding(.top, SkeuSpace.xs)
                }
            }
            Text("© \(Calendar.current.component(.year, from: .now).formatted(.number.grouping(.never))) Lucas Maher")
                .foregroundStyle(skeu.inkFaint)
        }.font(SkeuFont.at(12.8 * scale)).fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct MacHowToContent: View {
    @Environment(\.skeu) private var skeu
    @Environment(\.skeuTextScale) private var scale
    var body: some View {
        LazyVStack(alignment: .leading, spacing: SkeuSpace.lg) {
            MacReadOnlyWell(title: "Go live", prominent: true) {
                VStack(alignment: .leading, spacing: SkeuSpace.md * 1.5) {
                    HStack(spacing: SkeuSpace.sm) {
                        MacLiveGlyph(tint: skeu.ink).frame(width: MacLiveGlyph.diameter, height: MacLiveGlyph.diameter)
                        Text("Live").font(SkeuFont.at(16.4, weight: .medium))
                    }.skeuPulse(true).padding(.horizontal, 20).frame(height: 44.4)
                        .skeuGlass(Capsule(), height: 44.4)
                    Text("Add a live task in the panel on the right. The Live button keeps it in the Mac menu bar until you tick it off. Click the menu-bar ring to open the task. Live tasks also stay in Today.")
                }
            }
            MacReadOnlyWell(title: "Moving tasks", prominent: true) {
                VStack(alignment: .leading, spacing: SkeuSpace.md * 1.5) {
                    MacMovingTaskDemo()
                    Text("Not going to get a task done today? Hold the three lines on its right and drag it to Tomorrow. Drag it back to bring it forward. The other tasks make room as you move.")
                }
            }
            MacReadOnlyWell(title: "Workspaces", prominent: true) {
                VStack(alignment: .leading, spacing: SkeuSpace.md * 1.5) {
                    MacWorkspaceDemo().frame(height: 150, alignment: .topLeading)
                    Text("Switch between workspaces with the button at the top left. Add or rename them in Settings.")
                }
            }
        }.font(SkeuFont.at(12.8 * scale)).foregroundStyle(skeu.inkMuted)
            .fixedSize(horizontal: false, vertical: true)
    }
}

private struct MacMovingTaskDemo: View {
    @Environment(\.skeu) private var skeu
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    var body: some View {
        HStack(spacing: 16) {
            Circle().strokeBorder(skeu.ink, lineWidth: 1.1).frame(width: 26, height: 26)
            Text("To do").font(SkeuFont.at(16.4)).foregroundStyle(skeu.ink)
            Spacer()
            Image(systemName: "line.3.horizontal").foregroundStyle(skeu.inkMuted)
        }.padding(14).background(skeu.canvas.opacity(0.5), in: RoundedRectangle(cornerRadius: 16))
            .phaseAnimator([false, true]) { content, moved in
                content.offset(x: reduceMotion ? 0 : (moved ? 18 : -18))
            } animation: { _ in .spring(response: 1.4, dampingFraction: 0.82) }
            .padding(.horizontal, 18).padding(.vertical, 12)
            .allowsHitTesting(false).accessibilityHidden(true)
    }
}

private struct MacWorkspaceDemo: View {
    @Query(sort: \Workspace.createdAt) private var records: [Workspace]
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var selection = Workspace.defaultID
    @State private var open = false
    var body: some View {
        MacWorkspacePicker(selection: $selection, isOpen: $open) {}
            .task(id: reduceMotion) {
                guard !reduceMotion else { return }
                while !Task.isCancelled {
                    try? await Task.sleep(for: .seconds(1.3))
                    guard !Task.isCancelled else { return }
                    withAnimation(SkeuMotion.layout) { open = true }
                    try? await Task.sleep(for: .seconds(1.3))
                    guard !Task.isCancelled else { return }
                    withAnimation(SkeuMotion.layout) {
                        selection = MacWorkspaceRecords.unique(records).first { $0.id != selection }?.id ?? selection
                        open = false
                    }
                }
            }
    }
}
