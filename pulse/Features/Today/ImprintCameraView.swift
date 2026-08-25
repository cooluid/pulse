import PulseCore
import SwiftUI
import UIKit
import UniformTypeIdentifiers

struct ImprintCameraView: UIViewControllerRepresentable {
    let onCapture: (UIImage, ImprintCameraPosition) -> Void
    let onCancel: () -> Void
    let onFailure: () -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(
            onCapture: onCapture,
            onCancel: onCancel,
            onFailure: onFailure
        )
    }

    func makeUIViewController(context: Context) -> UIImagePickerController {
        precondition(
            UIImagePickerController.isSourceTypeAvailable(.camera),
            "Camera view must only be presented when a camera is available."
        )
        let controller = UIImagePickerController()
        controller.sourceType = .camera
        controller.mediaTypes = [UTType.image.identifier]
        controller.cameraCaptureMode = .photo
        controller.cameraDevice = Self.preferredCameraDevice(
            frontCameraAvailable: UIImagePickerController.isCameraDeviceAvailable(.front)
        )
        controller.allowsEditing = false
        controller.delegate = context.coordinator
        return controller
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    static func preferredCameraDevice(
        frontCameraAvailable: Bool
    ) -> UIImagePickerController.CameraDevice {
        frontCameraAvailable ? .front : .rear
    }

    @MainActor
    final class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let onCapture: (UIImage, ImprintCameraPosition) -> Void
        let onCancel: () -> Void
        let onFailure: () -> Void
        let cameraPosition: (UIImagePickerController) -> ImprintCameraPosition

        init(
            onCapture: @escaping (UIImage, ImprintCameraPosition) -> Void,
            onCancel: @escaping () -> Void,
            onFailure: @escaping () -> Void,
            cameraPosition: @escaping (UIImagePickerController) -> ImprintCameraPosition = {
                $0.cameraDevice == .front ? .front : .rear
            }
        ) {
            self.onCapture = onCapture
            self.onCancel = onCancel
            self.onFailure = onFailure
            self.cameraPosition = cameraPosition
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            onCancel()
        }

        func imagePickerController(
            _ picker: UIImagePickerController,
            didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]
        ) {
            guard let image = info[.originalImage] as? UIImage else {
                onFailure()
                return
            }
            do {
                let materialized = try ImprintImageProcessor.materializeCameraCapture(image)
                onCapture(
                    materialized,
                    cameraPosition(picker)
                )
            } catch {
                onFailure()
            }
        }
    }
}
