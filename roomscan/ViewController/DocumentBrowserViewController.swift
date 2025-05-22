import UIKit

// Delegate protocol to notify about starting a scan
protocol DocumentBrowserDelegate: AnyObject {
    func didRequestStartScan(inDirectory directoryURL: URL)
}

class DocumentBrowserViewController: UIDocumentBrowserViewController, UIDocumentBrowserViewControllerDelegate {

    weak var scanningDelegate: DocumentBrowserDelegate?
    var onStartRoomScan: (() -> Void)?

    var documentsDirectoryURL: URL?

    override func viewDidLoad() {
        super.viewDidLoad()
        delegate = self
        allowsDocumentCreation = true
        allowsPickingMultipleItems = false
        
        // The allowedContentTypes property is get-only and configured via Info.plist

        // Log the documents directory path
        if let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first {
            documentsDirectoryURL = documentsDirectory
            print("Documents Directory: \(documentsDirectory.path)")
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
        // Here you would handle opening the selected USDZ document.
        // This could involve passing the URL to a QLPreviewController or a custom SCNView.
    }

    func documentBrowser(_ controller: UIDocumentBrowserViewController, didRequestDocumentCreationWithHandler importHandler: @escaping (URL?, UIDocumentBrowserViewController.ImportMode) -> Void) {

        guard let documentsDirectory = documentsDirectoryURL else {
            print("Error: Could not access documents directory.")
            importHandler(nil, .none)
            return
        }
        
        let newScanDirectory = documentsDirectory.appendingPathComponent("NewScan-\(UUID().uuidString)")

        do {
            try FileManager.default.createDirectory(at: newScanDirectory, withIntermediateDirectories: true, attributes: nil)
            print("Created scan directory at: \(newScanDirectory.path)")
            scanningDelegate?.didRequestStartScan(inDirectory: newScanDirectory)
        } catch {
            print("Error creating scan directory: \(error)")
        }
    }

    func documentBrowser(_ controller: UIDocumentBrowserViewController, failedToImportDocumentAt documentURL: URL, error: Error?) {
        print("Failed to import document: \(documentURL), error: \(String(describing: error))")
        // Present an error message to the user if needed
    }
    
    func documentBrowser(_ controller: UIDocumentBrowserViewController, willPresent activityViewController: UIActivityViewController) {
        print("Activity View Controller will be presented.")
    }
}
