//
//  CameraPicker.swift
//  shove95
//
//  TASK-044. The camera half of photo capture. `UIImagePickerController` is
//  the deliberate choice over a custom AVFoundation surface: the camera UI is
//  the OS's, not ours, and dressing it in our skin would be costume rather
//  than interface — the same reasoning that keeps the system photo picker.
//
//  Returns raw JPEG bytes; `ImageImport.prepare` does the downscale.
//

import SwiftUI
import UIKit

struct CameraPicker: UIViewControllerRepresentable {
    /// nil = cancelled or the image could not be encoded.
    var onCapture: (Data?) -> Void

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ picker: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(onCapture: onCapture) }

    final class Coordinator: NSObject, UIImagePickerControllerDelegate,
                             UINavigationControllerDelegate {
        let onCapture: (Data?) -> Void

        init(onCapture: @escaping (Data?) -> Void) {
            self.onCapture = onCapture
        }

        func imagePickerController(
            _ picker: UIImagePickerController,
            didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]
        ) {
            let image = info[.originalImage] as? UIImage
            onCapture(image?.jpegData(compressionQuality: 1))
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            onCapture(nil)
        }
    }
}
