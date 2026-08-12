import PulseCore
import SwiftUI
import UIKit

struct ImprintCameraView: UIViewControllerRepresentable {
    let onCapture: (UIImage, ImprintCameraPosition) -> Void
    let onCancel: () -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onCapture: onCapture, onCancel: onCancel)
    }

    func makeUIViewController(context: Context) -> UIImagePickerController {
        precondition(
            UIImagePickerController.isSourceTypeAvailable(.camera),
            "Camera view must only be presented when a camera is available."
        )
        let controller = UIImagePickerController()
        controller.sourceType = .camera
        controller.mediaTypes = ["public.image"]
        controller.cameraCaptureMode = .photo
        controller.cameraDevice = .rear
        controller.allowsEditing = false
        controller.delegate = context.coordinator
        context.coordinator.controller = controller
        return controller
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    final class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let onCapture: (UIImage, ImprintCameraPosition) -> Void
        let onCancel: () -> Void
        weak var controller: UIImagePickerController?

        init(
            onCapture: @escaping (UIImage, ImprintCameraPosition) -> Void,
            onCancel: @escaping () -> Void
        ) {
            self.onCapture = onCapture
            self.onCancel = onCancel
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            onCancel()
        }

        func imagePickerController(
            _ picker: UIImagePickerController,
            didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]
        ) {
            guard let image = info[.originalImage] as? UIImage else {
                onCancel()
                return
            }
            onCapture(image, picker.cameraDevice == .front ? .front : .rear)
        }
    }
}
