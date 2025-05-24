import UIKit
import SwiftUI
import RoomPlan
import QuickLook

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

        let previewController = QLPreviewController()
        previewController.dataSource = self
        present(previewController, animated: true, completion: nil)
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
}
