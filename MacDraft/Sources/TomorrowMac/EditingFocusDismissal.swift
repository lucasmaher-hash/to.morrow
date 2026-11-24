import SwiftUI
import AppKit

/// AppKit does not resign a text editor when clicking inert SwiftUI ground.
/// Observe the existing event without consuming it: a click outside the current
/// editor ends editing, and the clicked control still receives its action.
struct EditingFocusDismissal: NSViewRepresentable {
    func makeNSView(context: Context) -> FocusView { FocusView() }
    func updateNSView(_ nsView: FocusView, context: Context) {}
    static func dismantleNSView(_ view: FocusView, coordinator: ()) { view.stop() }
    final class FocusView: NSView {
        private var monitor: Any?
        private weak var initializedWindow: NSWindow?
        override var acceptsFirstResponder: Bool { true }
        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            stop()
            guard let window else { return }
            if initializedWindow !== window {
                initializedWindow = window
                // AppKit otherwise selects the first editable task at launch.
                // A window responder leaves keyboard navigation available, but
                // starts editing only after the user chooses a text field.
                window.initialFirstResponder = self
                DispatchQueue.main.async { [weak self, weak window] in
                    guard let self, let window, self.window === window else { return }
                    window.makeFirstResponder(self)
                }
            }
            monitor = NSEvent.addLocalMonitorForEvents(matching: .leftMouseDown) { [weak self] event in
                guard let self, let window = self.window, event.window === window,
                      let editor = window.firstResponder as? NSTextView else { return event }
                if MacEditingRegions.keepsFocus(editor: editor, event: event) { return event }
                let target = (editor.delegate as? NSTextField) ?? editor
                let point = target.convert(event.locationInWindow, from: nil)
                if !target.bounds.contains(point) { window.makeFirstResponder(nil) }
                return event
            }
        }
        func stop() { if let monitor { NSEvent.removeMonitor(monitor) }; monitor = nil }
    }
}
private struct MacGrabCursor: ViewModifier {
    @State private var pushed = false
    func body(content: Content) -> some View {
        content.onHover { over in
            if over && !pushed { NSCursor.openHand.push(); pushed = true }
            if !over && pushed { NSCursor.pop(); pushed = false }
        }.onDisappear { if pushed { NSCursor.pop(); pushed = false } }
    }
}
extension View { func macGrabCursor() -> some View { modifier(MacGrabCursor()) } }

/// SwiftUI's indicator preference can be overridden by macOS's “Always” scroll
/// bar setting. Configure only the enclosing scroll view, never a global style.
struct MacScrollIndicators: NSViewRepresentable {
    var hidden = true
    func makeNSView(context: Context) -> Probe { let view = Probe(); view.hiddenIndicators = hidden; return view }
    func updateNSView(_ view: Probe, context: Context) { view.hiddenIndicators = hidden; view.applyWhenAttached() }
    final class Probe: NSView {
        var hiddenIndicators = true
        override func viewDidMoveToWindow() { super.viewDidMoveToWindow(); applyWhenAttached() }
        override func viewDidMoveToSuperview() { super.viewDidMoveToSuperview(); applyWhenAttached() }
        override func layout() { super.layout(); apply() }
        func applyWhenAttached() { DispatchQueue.main.async { [weak self] in self?.apply() } }
        private func apply() {
            guard let scroll = enclosingScrollView else { return }
            // Legacy scrollers reserve a horizontal gutter even after SwiftUI
            // hides their paint. Overlay style makes the viewport use it too.
            let style: NSScroller.Style = hiddenIndicators ? .overlay : .legacy
            if scroll.scrollerStyle != style { scroll.scrollerStyle = style }
            if scroll.hasVerticalScroller == hiddenIndicators { scroll.hasVerticalScroller = !hiddenIndicators }
            if scroll.hasHorizontalScroller { scroll.hasHorizontalScroller = false }
            scroll.autohidesScrollers = hiddenIndicators
        }
        override func hitTest(_ point: NSPoint) -> NSView? { nil }
    }
}

/// Controls belonging to an editor act on its current draft before ending
/// editing. Avoid the board's outside-click monitor committing a new Live note
/// on mouse-down, then treating the very same Go click as a toggle-off.
@MainActor enum MacEditingRegions {
    static let views = NSHashTable<NSView>.weakObjects()
    static func keepsFocus(editor: NSView, event: NSEvent) -> Bool {
        views.allObjects.contains { region in
            region.window === event.window && region.window === editor.window &&
            region.bounds.intersects(region.convert(editor.bounds, from: editor)) &&
            region.bounds.contains(region.convert(event.locationInWindow, from: nil))
        }
    }
}
