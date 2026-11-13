import SwiftUI
import UIKit
import VisionKit

/// A79 (Kelly Ke49 "Fota sidor"): the camera stays open for several pages in a row. Apple's document camera finds
/// the page, straightens it and takes the next one; "Spara" gives all of them. Where it is not supported (the
/// Simulator) the single-photo picker stands in.
struct PageScanner: UIViewControllerRepresentable {
    let onPages: ([UIImage]) -> Void
    let onCancel: () -> Void

    static var isAvailable: Bool { VNDocumentCameraViewController.isSupported }

    func makeUIViewController(context: Context) -> VNDocumentCameraViewController {
        let camera = VNDocumentCameraViewController()
        camera.delegate = context.coordinator
        return camera
    }

    func updateUIViewController(_ uiViewController: VNDocumentCameraViewController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(onPages: onPages, onCancel: onCancel) }

    @MainActor
    final class Coordinator: NSObject, VNDocumentCameraViewControllerDelegate {
        let onPages: ([UIImage]) -> Void
        let onCancel: () -> Void

        init(onPages: @escaping ([UIImage]) -> Void, onCancel: @escaping () -> Void) {
            self.onPages = onPages
            self.onCancel = onCancel
        }

        // nonisolated + assumeIsolated: right whether or not the SDK marks this delegate as main-actor (iOS calls it on
        // the main thread either way).
        nonisolated func documentCameraViewController(_ controller: VNDocumentCameraViewController,
                                                      didFinishWith scan: VNDocumentCameraScan) {
            let pages = (0..<scan.pageCount).map { scan.imageOfPage(at: $0) }
            MainActor.assumeIsolated { onPages(pages) }
        }

        nonisolated func documentCameraViewControllerDidCancel(_ controller: VNDocumentCameraViewController) {
            MainActor.assumeIsolated { onCancel() }
        }

        nonisolated func documentCameraViewController(_ controller: VNDocumentCameraViewController,
                                                      didFailWithError error: any Error) {
            let message = error.localizedDescription
            MainActor.assumeIsolated {
                Log.repetition.error("Page scanner: \(message, privacy: .public)")
                onCancel()
            }
        }
    }
}
