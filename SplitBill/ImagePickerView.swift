import SwiftUI

public struct ImagePickerView: UIViewControllerRepresentable {
    private let sourceType: UIImagePickerController.SourceType
    private let onImagePicked: (UIImage, _ isHeic: Bool) -> Void
    @Environment(\.presentationMode) private var presentationMode

    public init(sourceType: UIImagePickerController.SourceType,
                onImagePicked: @escaping (UIImage, _ isHeic: Bool) -> Void) {
        self.sourceType = sourceType
        self.onImagePicked = onImagePicked
    }

    public func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = self.sourceType
        picker.delegate = context.coordinator
        return picker
    }

    public func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    public func makeCoordinator() -> Coordinator {
        Coordinator(
            onDismiss: { self.presentationMode.wrappedValue.dismiss() },
            onImagePicked: self.onImagePicked
        )
    }

    final public class Coordinator: NSObject, UINavigationControllerDelegate, UIImagePickerControllerDelegate {

        private let onDismiss: () -> Void
        private let onImagePicked: (UIImage, _ isHeic: Bool) -> Void

        init(onDismiss: @escaping () -> Void, onImagePicked: @escaping (UIImage, _ isHeic: Bool) -> Void) {
            self.onDismiss = onDismiss
            self.onImagePicked = onImagePicked
        }

        public func imagePickerController(_ picker: UIImagePickerController,
                                          didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            if let image = info[.originalImage] as? UIImage {
                let isHeic = imageIsHeic(info)
                self.onImagePicked(image, isHeic)
            }
            self.onDismiss()
        }

        public func imagePickerControllerDidCancel(_: UIImagePickerController) {
            self.onDismiss()
        }

        public func imageIsHeic(_ info: [UIImagePickerController.InfoKey: Any]) -> Bool {
            if let assetPath = info[UIImagePickerController.InfoKey.referenceURL] as? NSURL,
               let ext = assetPath.pathExtension,
               ext == "HEIC" {
                return true
            }
            return false
        }

    }

}
