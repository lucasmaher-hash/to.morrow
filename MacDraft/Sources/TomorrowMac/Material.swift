import SwiftUI
import AppKit

// Platform glue. Rendering and palettes are ported directly from iOS SkeuKit.
extension Color {
    init(hex: UInt32, alpha: Double = 1) {
        self.init(.sRGB, red: Double((hex >> 16) & 255) / 255, green: Double((hex >> 8) & 255) / 255, blue: Double(hex & 255) / 255, opacity: alpha)
    }
    init(h: Double, s: Double, b: Double, opacity: Double = 1) {
        self.init(hue: h.clamped01, saturation: s.clamped01, brightness: b.clamped01, opacity: opacity)
    }
    var hsb: (h: Double, s: Double, b: Double) {
        let c = NSColor(self).usingColorSpace(.deviceRGB) ?? .gray
        return (Double(c.hueComponent), Double(c.saturationComponent), Double(c.brightnessComponent))
    }
    func shifted(sat: Double = 0, bri: Double = 0, hue: Double = 0) -> Color {
        let c = hsb; return Color(h: c.h + hue, s: c.s + sat, b: c.b + bri)
    }
}
extension Double { var clamped01: Double { min(max(self, 0), 1) } }
extension EnvironmentValues {
    @Entry var skeuTextScale: CGFloat = 1
    @Entry var skeuChromeScale: CGFloat = 1
}
enum SkeuHaptic { static func press() {} }

// Native Buttons retain keyboard/VoiceOver activation; the response uses the
// phone's swell amplitude, timing and Reduce Motion behavior.
struct MacSkeuTapStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        MacSkeuTapBody(pressed: configuration.isPressed) { configuration.label }
    }
}
private struct MacSkeuTapBody<Content: View>: View {
    let pressed: Bool
    @ViewBuilder var content: Content
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var swollen = false
    @State private var release: Task<Void, Never>?
    var body: some View {
        content.scaleEffect(!reduceMotion && swollen ? SkeuMotion.pressGrow : 1)
            .animation(reduceMotion ? SkeuMotion.tint : SkeuMotion.pressSwell, value: swollen)
            .onChange(of: pressed) { _, down in
                guard down else { return }
                release?.cancel()
                swollen = true
                release = Task { @MainActor in
                    try? await Task.sleep(for: .milliseconds(260))
                    guard !Task.isCancelled else { return }
                    swollen = false
                }
            }
            .onDisappear { release?.cancel() }
    }
}

struct GlassButton: ButtonStyle {
    var circle = false
    var selected = true
    var diameter: CGFloat = SkeuTopBar.control
    func makeBody(configuration: Configuration) -> some View {
        MacSkeuTapBody(pressed: configuration.isPressed) {
            if circle {
                configuration.label
                    .font(SkeuFont.at(diameter / 2))
                    .frame(width: diameter, height: diameter)
                    .skeuGlass(Circle(), height: diameter, prominent: selected)
                    .contentShape(Circle())
            } else {
                configuration.label
                    .font(SkeuFont.at(SkeuToggle.label, weight: .medium))
                    .padding(.horizontal, SkeuSpace.lg)
                    .frame(minHeight: diameter)
                    .skeuGlass(Capsule(), height: diameter, prominent: selected)
                    .contentShape(Capsule())
            }
        }
    }
}

// F's private task-row tokens, resolved from the same design frame on iOS.
enum MacTaskMetrics {
    static let scale: CGFloat = 37 / (107.444 * (402.0 / 1495.0))
    static let checkLeft: CGFloat = -5
    static let checkRight: CGFloat = 1.5
    static let check: CGFloat = 26 * scale * 0.75
    static let gap: CGFloat = 29.714 * 37 / 107.444
    static let label: CGFloat = 47.542 * 37 / 107.444
}
struct MacTaskCheck: View {
    @Environment(\.skeu) private var skeu
    @Environment(\.skeuTextScale) private var textScale
    var completed = false
    var tint: Color? = nil
    var important = false
    private var ink: Color { tint ?? (completed ? skeu.inkMuted : skeu.ink) }
    var body: some View {
        ZStack {
            if completed {
                SkeuChromeGlyph(kind: .check, face: SkeuFont.face, size: 11 * 0.75, tint: ink)
            }
        }
        .frame(width: MacTaskMetrics.check, height: MacTaskMetrics.check)
        .overlay { Circle().strokeBorder(ink, lineWidth: MacTaskMetrics.label * textScale * (important ? 0.08 : 0.065)) }
        .frame(width: SkeuControl.minTouch, height: SkeuControl.minTouch)
        .contentShape(Rectangle())
    }
}

struct MacChoice: View {
    @Environment(\.skeu) private var skeu
    @Environment(\.skeuTextScale) private var textScale
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let options: [String]
    @Binding var selection: String
    @Namespace private var space
    var body: some View {
        SkeuSegmentedTrough {
            ForEach(options, id: \.self) { value in
                Button { withAnimation(reduceMotion ? nil : SkeuMotion.layout) { selection = value } } label: {
                    SkeuSegment(isSelected: selection == value, namespace: space, geometryID: "selection") {
                        Text(value).skeuSegmentLabel(textScale, role: .content)
                            .foregroundStyle(selection == value ? skeu.ink : skeu.inkMuted)
                    }
                }.buttonStyle(MacSkeuTapStyle())
                    .accessibilityAddTraits(selection == value ? .isSelected : [])
            }
        }
    }
}


/// Only the gear redraws while the sheet is open; the board stays idle.
struct MacSettingsGear: View {
    var active: Bool
    @Environment(\.skeu) private var skeu
    @EnvironmentObject private var settings: MacSettings
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var started: Date?
    @State private var restingAngle: Double = 0

    private func travel(at date: Date) -> Double {
        guard let started else { return 0 }
        let seconds = max(0, date.timeIntervalSince(started))
        // Fast initial turn, then a steady 45 degrees/second with no seam.
        return 45 * seconds + 135 * (1 - exp(-3 * seconds))
    }
    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 60, paused: !active || reduceMotion)) { timeline in
            SkeuChromeGlyph(kind: .gear, face: settings.face == "Retro" ? .blend : .system, size: SkeuTopBar.icon, tint: skeu.ink)
                .rotationEffect(.degrees(restingAngle + (reduceMotion ? 0 : travel(at: timeline.date))))
        }
        .onChange(of: active) {
            if active { started = .now }
            else { restingAngle += travel(at: .now); started = nil }
        }
        .onAppear { if active { started = .now } }
    }
}
