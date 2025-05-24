import RoomPlan
import UIKit
import SwiftUI

// Wrapper for UIDocumentBrowserViewController
struct DocumentBrowserView: UIViewControllerRepresentable {
    
    var onStartScan: (URL) -> Void // Closure to call when scanning should start

    func makeUIViewController(context: Context) -> DocumentBrowserViewController {
        let controller = DocumentBrowserViewController()
        controller.scanningDelegate = context.coordinator // Set the coordinator as the delegate
        return controller
    }

    func updateUIViewController(_ uiViewController: DocumentBrowserViewController, context: Context) {
        // Update the controller if needed
    }

    // Coordinator class to act as the delegate
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, DocumentBrowserDelegate {
        var parent: DocumentBrowserView

        init(_ parent: DocumentBrowserView) {
            self.parent = parent
        }

        func didRequestStartScan(inDirectory directoryURL: URL) {
            parent.onStartScan(directoryURL)
        }
    }
}
