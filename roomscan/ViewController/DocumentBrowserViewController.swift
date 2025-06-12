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

        // Setup dedicated RoomScans directory
        setupRoomScansDirectory()

        browserUserInterfaceStyle = .light
        view.tintColor = .accent
    }
    
    private func setupRoomScansDirectory() {
        guard let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            print("Error: Could not access documents directory.")
            return
        }
        
        documentsDirectoryURL = documentsDirectory
        print("RoomScan App Documents Directory: \(documentsDirectory.path)")
        print("This directory appears as 'RoomScan' in iOS Files app")
    }
    
    private func saveScanFilesLocally(usdzURL: URL, metadataURL: URL?) {
        guard let documentsDirectory = documentsDirectoryURL else {
            print("DocumentBrowserViewController: Documents directory not available for local save")
            return
        }
        
        // Extract project name from the USDZ filename (remove .usdz extension)
        let projectName = usdzURL.deletingPathExtension().lastPathComponent
        let projectDirectory = documentsDirectory.appendingPathComponent(projectName)
        
        // Find the JSON file in the same directory as the USDZ file
        let tempDirectory = usdzURL.deletingLastPathComponent()
        let jsonURL = tempDirectory.appendingPathComponent(projectName + ".json")
        
        do {
            // Create project directory if it doesn't exist
            if !FileManager.default.fileExists(atPath: projectDirectory.path) {
                try FileManager.default.createDirectory(at: projectDirectory, withIntermediateDirectories: true, attributes: nil)
                print("DocumentBrowserViewController: ✅ Created project directory: \(projectName)")
            }
            
            // Move the USDZ file directly from temp to project directory
            let targetUsdzLocation = projectDirectory.appendingPathComponent(usdzURL.lastPathComponent)
            if FileManager.default.fileExists(atPath: targetUsdzLocation.path) {
                try FileManager.default.removeItem(at: targetUsdzLocation)
            }
            try FileManager.default.moveItem(at: usdzURL, to: targetUsdzLocation)
            print("DocumentBrowserViewController: ✅ Saved USDZ locally to: \(projectName)/\(usdzURL.lastPathComponent)")
            
            // Move the metadata file to project directory if it exists
            if let metadataURL = metadataURL {
                let targetMetadataURL = projectDirectory.appendingPathComponent(metadataURL.lastPathComponent)
                if FileManager.default.fileExists(atPath: targetMetadataURL.path) {
                    try FileManager.default.removeItem(at: targetMetadataURL)
                }
                try FileManager.default.moveItem(at: metadataURL, to: targetMetadataURL)
                print("DocumentBrowserViewController: ✅ Saved PLIST locally to: \(projectName)/\(metadataURL.lastPathComponent)")
            }
            
            // Move the JSON file to project directory if it exists
            if FileManager.default.fileExists(atPath: jsonURL.path) {
                let targetJsonURL = projectDirectory.appendingPathComponent(jsonURL.lastPathComponent)
                if FileManager.default.fileExists(atPath: targetJsonURL.path) {
                    try FileManager.default.removeItem(at: targetJsonURL)
                }
                try FileManager.default.moveItem(at: jsonURL, to: targetJsonURL)
                print("DocumentBrowserViewController: ✅ Saved JSON locally to: \(projectName)/\(jsonURL.lastPathComponent)")
            }
            
            print("DocumentBrowserViewController: ✅ All files saved locally in project '\(projectName)' folder")
            
        } catch {
            print("DocumentBrowserViewController: ❌ Failed to save files locally: \(error)")
        }
    }

    // MARK: - UIDocumentBrowserViewControllerDelegate

    func documentBrowser(_ controller: UIDocumentBrowserViewController, didPickDocumentsAt urls: [URL]) {
        guard let sourceURL = urls.first else { return }
        print("Document picked: \(sourceURL)")
        previewItemURL = sourceURL

        // Show options for how to open the USDZ file
        openWithSceneKitEditor(url: sourceURL)
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
            scanDirectoryURL: scanDirURL,
            onScanComplete: { [weak self] (capturedRoom, usdzURL, metadataURL) in
                // Dismiss the RoomScanningView
                self?.presentedViewController?.dismiss(animated: true, completion: {
                    // Save USDZ, PLIST, and JSON files directly to local documents directory
                    self?.saveScanFilesLocally(usdzURL: usdzURL, metadataURL: metadataURL)
                    
                    // Complete the document creation process without importing anything through the system
                    self?.importHandler?(nil, .none)
                    
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
    
    private func openWithSceneKitEditor(url: URL) {
        let sceneKitView = SceneKit3DEditorView(modelURL: url) {
            // Dismiss callback
            self.presentedViewController?.dismiss(animated: true)
        }
        
        let hostingController = UIHostingController(rootView: sceneKitView)
        hostingController.modalPresentationStyle = .fullScreen
        present(hostingController, animated: true)
    }
    
    private func openWithQuickLook(url: URL) {
        let previewController = QLPreviewController()
        previewController.dataSource = self
        present(previewController, animated: true)
    }
}


extension SCNVector3: Equatable {
    public static func == (lhs: SCNVector3, rhs: SCNVector3) -> Bool {
        return lhs.x == rhs.x && lhs.y == rhs.y && lhs.z == rhs.z
    }
}
