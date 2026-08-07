import SwiftUI

#if canImport(UIKit)
import UIKit

/// The system camera, for photographing where you sit today.
///
/// `UIImagePickerController` rather than a hand-rolled `AVCaptureSession` on
/// purpose: the scrapbook needs one picture of a desk, not a camera app. The
/// system sheet brings its own permission prompt, its own flip/flash controls,
/// and its own retake screen, and costs this app none of the maintenance.
///
/// Always check `isAvailable` before offering this — the simulator has no
/// camera, and `UIImagePickerController` with an unavailable source type
/// raises rather than degrading. Call sites hide the camera entirely when it
/// is not there: a button for hardware the device does not have is not a
/// feature, it is an apology.
struct CameraPicker: UIViewControllerRepresentable {
    /// Called with the shot exactly as taken. Orientation is the importer's
    /// problem — `SnapshotImport.prepare` bakes it in — so nothing here
    /// touches the pixels.
    let onCapture: (UIImage) -> Void
    @Environment(\.dismiss) private var dismiss

    /// False on the simulator and on the vanishingly rare cameraless device.
    static var isAvailable: Bool {
        UIImagePickerController.isSourceTypeAvailable(.camera)
    }

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    final class Coordinator: NSObject, UIImagePickerControllerDelegate,
                             UINavigationControllerDelegate {
        private let parent: CameraPicker

        init(_ parent: CameraPicker) { self.parent = parent }

        func imagePickerController(
            _ picker: UIImagePickerController,
            didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]
        ) {
            if let image = info[.originalImage] as? UIImage {
                parent.onCapture(image)
            }
            parent.dismiss()
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.dismiss()
        }
    }
}
#endif
