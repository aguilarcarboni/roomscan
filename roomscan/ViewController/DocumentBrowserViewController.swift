import UIKit
import SwiftUI
import RoomPlan
import QuickLook
import SceneKit

// Delegate protocol to notify about starting a scan
protocol DocumentBrowserDelegate: AnyObject {
    func didRequestStartScan(inDirectory directoryURL: URL)
}

class DocumentBrowserViewController: UIDocumentBrowserViewController, UIDocumentBrowserViewControllerDelegate, QLPreviewControllerDataSource {

    weak var scanningDelegate: DocumentBrowserDelegate?
    var onStartRoomScan: (() -> Void)?
    var documentsDirectoryURL: URL?
    var previewItemURL: URL?
    
    // Store the import handler and temporary URL
    private var importHandler: ((URL?, UIDocumentBrowserViewController.ImportMode) -> Void)?
    private var temporaryScanURL: URL?

    override func viewDidLoad() {
        super.viewDidLoad()
        delegate = self
        allowsDocumentCreation = true
        allowsPickingMultipleItems = false
        
        // The allowedContentTypes property is get-only and configured via Info.plist

        // Log the documents directory path
        if let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first {
            documentsDirectoryURL = documentsDirectory
            print("App Directory: \(documentsDirectory.path)")
        } else {
            print("Error: Could not access documents directory.")
        }

        browserUserInterfaceStyle = .light
        view.tintColor = .accent
    }

    // MARK: - UIDocumentBrowserViewControllerDelegate

    func documentBrowser(_ controller: UIDocumentBrowserViewController, didPickDocumentsAt urls: [URL]) {
        guard let sourceURL = urls.first else { return }
        print("Document picked: \(sourceURL)")
        previewItemURL = sourceURL

        // Show options for how to open the USDZ file
        showOpenOptionsForUSDZ(url: sourceURL)
    }

    func documentBrowser(_ controller: UIDocumentBrowserViewController, didRequestDocumentCreationWithHandler importHandler: @escaping (URL?, UIDocumentBrowserViewController.ImportMode) -> Void) {

        // Store the import handler
        self.importHandler = importHandler

        // Create a temporary directory for the scan
        let tempDirectoryURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        do {
            try FileManager.default.createDirectory(at: tempDirectoryURL, withIntermediateDirectories: true, attributes: nil)
            self.temporaryScanURL = tempDirectoryURL
        } catch {
            print("Error creating temporary directory: \(error)")
            // Call importHandler with nil to indicate failure, and .none as we are not importing anything
            importHandler(nil, .none)
            return
        }

        // Prepare and present the RoomScanningView
        guard let scanDirURL = self.temporaryScanURL else {
            print("Error: Temporary scan directory URL is nil.")
            importHandler(nil, .none)
            return
        }
        
        let roomScanningView = RoomScanningView(
            scanDirectoryURL: scanDirURL, // Pass the temporary directory
            onScanComplete: { [weak self] (capturedRoom, fileURL) in
                // Dismiss the RoomScanningView
                self?.presentedViewController?.dismiss(animated: true, completion: {
                    // Call the stored importHandler with the URL of the saved scan file
                    // Use .move as the file is in a temporary location
                    self?.importHandler?(fileURL, .move)
                    // Clear the handler and temp URL after use
                    self?.importHandler = nil
                    self?.temporaryScanURL = nil
                })
            }
        )

        let hostingController = UIHostingController(rootView: roomScanningView)
        hostingController.modalPresentationStyle = .fullScreen // Or your preferred style
        self.present(hostingController, animated: true, completion: nil)
    }

    func documentBrowser(_ controller: UIDocumentBrowserViewController, failedToImportDocumentAt documentURL: URL, error: Error?) {
        print("Failed to import document: \(documentURL), error: \(String(describing: error))")
        // Present an error message to the user if needed
    }
    
    func documentBrowser(_ controller: UIDocumentBrowserViewController, willPresent activityViewController: UIActivityViewController) {
        print("Activity View Controller will be presented.")
    }
    
    // MARK: - QLPreviewControllerDataSource
    
    func numberOfPreviewItems(in controller: QLPreviewController) -> Int {
        return previewItemURL == nil ? 0 : 1
    }

    func previewController(_ controller: QLPreviewController, previewItemAt index: Int) -> QLPreviewItem {
        return previewItemURL! as QLPreviewItem
    }
    
    // MARK: - 3D Editor Integration
    
    private func showOpenOptionsForUSDZ(url: URL) {
        let alert = UIAlertController(title: "Open 3D Model", message: "Choose how to view this 3D model", preferredStyle: .actionSheet)
        
        // SceneKit Editor option
        alert.addAction(UIAlertAction(title: "SceneKit Editor", style: .default) { _ in
            self.openWithSceneKitEditor(url: url)
        })

        // QuickLook Preview option
        alert.addAction(UIAlertAction(title: "Quick Preview", style: .default) { _ in
            self.openWithQuickLook(url: url)
        })
        
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        
        // For iPad support
        if let popover = alert.popoverPresentationController {
            popover.sourceView = view
            popover.sourceRect = CGRect(x: view.bounds.midX, y: view.bounds.midY, width: 0, height: 0)
            popover.permittedArrowDirections = []
        }
        
        present(alert, animated: true)
    }
    
    private func openWithSceneKitEditor(url: URL) {
        let sceneKitView = SceneKit3DEditorView(modelURL: url) {
            // Dismiss callback
            self.presentedViewController?.dismiss(animated: true)
        }
        
        let hostingController = UIHostingController(rootView: sceneKitView)
        hostingController.modalPresentationStyle = .fullScreen
        present(hostingController, animated: true)
    }
    
    private func openWithRealityKitEditor(url: URL) {
        let realityKitView = RealityKit3DEditorView(modelURL: url) {
            // Dismiss callback
            self.presentedViewController?.dismiss(animated: true)
        }
        
        let hostingController = UIHostingController(rootView: realityKitView)
        hostingController.modalPresentationStyle = .fullScreen
        present(hostingController, animated: true)
    }
    
    private func openWithQuickLook(url: URL) {
        let previewController = QLPreviewController()
        previewController.dataSource = self
        present(previewController, animated: true)
    }
}
