//
//  ZoomableImageView.swift
//  shove95
//
//  The photo inside the viewer window: pinch and double-tap to zoom, and
//  Apple's own Live Text on top so writing in a photo can be selected,
//  copied, or looked up.
//
//  Both are UIKit. A UIScrollView is the zoom implementation on iOS — writing
//  it by hand means reimplementing rubber-banding, momentum and zoom anchoring
//  badly. Live Text is `VisionKit`'s `ImageAnalysisInteraction`, which is
//  literally what Photos uses; a hand-rolled version would be worse and would
//  never match the selection UI people already know.
//
//  Deliberately NOT skinned. The costume stops at the frame: text selection
//  handles and the lookup menu are OS furniture, and dressing them up would
//  break the one interaction people already understand.
//

import SwiftUI
import UIKit
import VisionKit

/// Lays the image out in `layoutSubviews`, because at `makeUIView` time the
/// scroll view has no bounds yet — sizing there left the image at zero and the
/// window rendered empty grey (2026-08-04).
final class ZoomScrollView: UIScrollView {
    let imageView = UIImageView()

    override init(frame: CGRect) {
        super.init(frame: frame)
        addSubview(imageView)
    }

    required init?(coder: NSCoder) { fatalError("not used") }

    override func layoutSubviews() {
        super.layoutSubviews()
        // Only while unzoomed: once the user zooms, the scroll view owns the
        // frame and re-imposing bounds would fight them.
        guard zoomScale == minimumZoomScale else { return }
        imageView.frame = bounds
        contentSize = bounds.size
    }
}

struct ZoomableImageView: UIViewRepresentable {
    let image: UIImage
    /// Reports whether the reader has zoomed in.
    ///
    /// The viewer around this closes on a downward drag, and while zoomed a
    /// downward drag is how you look at the bottom of the picture. Whoever
    /// owns the dismiss gesture has to be able to stand down, so the zoom
    /// state has to leave this view (2026-08-23).
    var onZoomChange: ((Bool) -> Void)?

    func makeUIView(context: Context) -> ZoomScrollView {
        let scrollView = ZoomScrollView()
        scrollView.delegate = context.coordinator
        scrollView.minimumZoomScale = 1
        scrollView.maximumZoomScale = 6
        scrollView.bouncesZoom = true
        scrollView.showsHorizontalScrollIndicator = false
        scrollView.showsVerticalScrollIndicator = false
        scrollView.backgroundColor = .clear
        // The window already frames the image; a second inset would look like
        // a mistake.
        scrollView.contentInsetAdjustmentBehavior = .never

        let imageView = scrollView.imageView
        imageView.image = image
        imageView.contentMode = .scaleAspectFit
        imageView.isUserInteractionEnabled = true // Live Text needs this
        context.coordinator.imageView = imageView
        context.coordinator.scrollView = scrollView

        let doubleTap = UITapGestureRecognizer(
            target: context.coordinator,
            action: #selector(Coordinator.handleDoubleTap(_:)))
        doubleTap.numberOfTapsRequired = 2
        scrollView.addGestureRecognizer(doubleTap)

        context.coordinator.attachLiveText(to: imageView, image: image)
        return scrollView
    }

    func updateUIView(_ scrollView: ZoomScrollView, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(onZoomChange: onZoomChange) }

    final class Coordinator: NSObject, UIScrollViewDelegate {
        weak var imageView: UIImageView?
        weak var scrollView: UIScrollView?
        private let interaction = ImageAnalysisInteraction()
        private let onZoomChange: ((Bool) -> Void)?
        /// Reported only on a CHANGE. `scrollViewDidZoom` fires continuously
        /// through a pinch, and handing SwiftUI the same value sixty times a
        /// second is state churn for nothing.
        private var wasZoomed = false

        init(onZoomChange: ((Bool) -> Void)?) {
            self.onZoomChange = onZoomChange
        }

        func viewForZooming(in scrollView: UIScrollView) -> UIView? { imageView }

        /// Keeps the image centred as it shrinks below the viewport, so zooming
        /// out doesn't strand it in a corner.
        func scrollViewDidZoom(_ scrollView: UIScrollView) {
            guard let imageView else { return }
            let extraX = max(0, (scrollView.bounds.width - imageView.frame.width) / 2)
            let extraY = max(0, (scrollView.bounds.height - imageView.frame.height) / 2)
            scrollView.contentInset = UIEdgeInsets(top: extraY, left: extraX,
                                                   bottom: extraY, right: extraX)

            let zoomed = scrollView.zoomScale > scrollView.minimumZoomScale + 0.01
            guard zoomed != wasZoomed else { return }
            wasZoomed = zoomed
            onZoomChange?(zoomed)
        }

        @objc func handleDoubleTap(_ gesture: UITapGestureRecognizer) {
            guard let scrollView else { return }
            if scrollView.zoomScale > scrollView.minimumZoomScale {
                scrollView.setZoomScale(scrollView.minimumZoomScale, animated: true)
            } else {
                // Zoom toward the tap rather than the centre — zooming into the
                // middle when you asked for a corner is the classic annoyance.
                let point = gesture.location(in: imageView)
                let scale = min(scrollView.maximumZoomScale, 3)
                let size = CGSize(width: scrollView.bounds.width / scale,
                                  height: scrollView.bounds.height / scale)
                scrollView.zoom(to: CGRect(x: point.x - size.width / 2,
                                           y: point.y - size.height / 2,
                                           width: size.width, height: size.height),
                                animated: true)
            }
        }

        /// Live Text. Analysis is asynchronous and best-effort: if the device
        /// can't do it, or the photo has no text, nothing appears and nothing
        /// is said about it.
        func attachLiveText(to imageView: UIImageView, image: UIImage) {
            guard ImageAnalyzer.isSupported else { return }
            imageView.addInteraction(interaction)
            interaction.preferredInteractionTypes = .automatic

            Task { @MainActor in
                let analyzer = ImageAnalyzer()
                let configuration = ImageAnalyzer.Configuration([.text, .machineReadableCode])
                if let analysis = try? await analyzer.analyze(image, configuration: configuration) {
                    interaction.analysis = analysis
                }
            }
        }
    }
}
