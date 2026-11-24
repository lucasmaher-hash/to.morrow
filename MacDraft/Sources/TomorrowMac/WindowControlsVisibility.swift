import SwiftUI
import AppKit

/// Settings belongs to the board window, including in native fullscreen.
/// Hide only the window buttons while that mobile-style overlay is presented.
struct WindowControlsVisibility: NSViewRepresentable {
    let hidden: Bool
    func makeNSView(context: Context) -> ControlsView { ControlsView() }
    func updateNSView(_ view: ControlsView, context: Context) { view.hideControls = hidden; view.apply() }
    final class ControlsView: NSView {
        var hideControls = false
        override func viewDidMoveToWindow() { super.viewDidMoveToWindow(); apply() }
        func apply() {
            for kind: NSWindow.ButtonType in [.closeButton, .miniaturizeButton, .zoomButton] {
                window?.standardWindowButton(kind)?.isHidden = hideControls
            }
        }
    }
}
