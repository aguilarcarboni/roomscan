import SwiftUI
import UIKit

struct RealityKit3DEditorView: UIViewControllerRepresentable {
    let modelURL: URL
    let onDismiss: () -> Void
    
    func makeUIViewController(context: Context) -> RealityKit3DEditorViewController {
        let controller = RealityKit3DEditorViewController(modelURL: modelURL)
        return controller
    }
    
    func updateUIViewController(_ uiViewController: RealityKit3DEditorViewController, context: Context) {
        // Update if needed
    }
} 