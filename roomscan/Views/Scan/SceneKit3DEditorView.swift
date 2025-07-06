import SwiftUI
import UIKit
import SceneKit

struct SceneKit3DEditorView: UIViewControllerRepresentable {
    let modelURL: URL
    let onDismiss: () -> Void
    
    func makeUIViewController(context: Context) -> SceneKit3DEditorViewController {
        let controller = SceneKit3DEditorViewController(modelURL: modelURL)
        controller.onDismiss = onDismiss
        return controller
    }
    
    func updateUIViewController(_ uiViewController: SceneKit3DEditorViewController, context: Context) {
        // Update if needed
    }
} 
