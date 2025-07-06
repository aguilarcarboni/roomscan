import SwiftUI
import RoomPlan

struct RoomScanningView: View {
    @Environment(\.dismiss) private var dismiss
    
    let scanDirectoryURL: URL
    let onScanComplete: (_ capturedRoom: CapturedRoom, _ usdzURL: URL, _ metadataURL: URL?) -> Void
    
    @State private var showingFolderNamePrompt = false
    @State private var folderNameInput = ""
    @State private var isScanning = true
    @State private var capturedRoom: CapturedRoom?
    @State private var captureViewRef: RoomCaptureView?
    
    var body: some View {
        ZStack {
            // Use RoomCaptureView directly as Apple recommends
             RoomCaptureViewRepresentable(
                 captureViewRef: $captureViewRef,
                 onScanComplete: { room in
                     capturedRoom = room
                     isScanning = false
                 },
                 onCancel: {
                     dismiss()
                 }
             )
            .ignoresSafeArea()
            
                         // Simple overlay with controls
             VStack {
                 HStack {
                     Button("Cancel") {
                         dismiss()
                     }
                     .padding()
                     .buttonStyle(.plain)
                     .foregroundColor(.white)
                     .background(Color.clear)
                     .cornerRadius(8)
                     
                     Spacer()
                     
                     if isScanning {
                         Button("Done") {
                             finishScanning()
                         }
                         .padding()
                         .buttonStyle(.plain)
                         .foregroundColor(.white)
                         .background(Color.clear)
                         .cornerRadius(8)
                     } else {
                         Button("Export") {
                             showingFolderNamePrompt = true
                         }
                         .padding()
                         .buttonStyle(.plain)
                         .foregroundColor(.white)
                         .background(Color.clear)
                         .cornerRadius(8)
                     }
                 }
                 .padding()
                 
                 Spacer()
             }
        }
        .navigationBarHidden(true)
        .alert("Export Scan", isPresented: $showingFolderNamePrompt) {
            TextField("Project Name", text: $folderNameInput)
            Button("Export") {
                exportScan()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Enter a project name for your scan.")
        }
    }
    
    private func finishScanning() {
        captureViewRef?.captureSession.stop()
    }
    
    private func exportScan() {
        guard let room = capturedRoom else {
            print("RoomScanningView: No captured room to export")
            return
        }
        
        let trimmedName = folderNameInput.trimmingCharacters(in: .whitespacesAndNewlines)
        let scanName = trimmedName.isEmpty ? "RoomScan" : trimmedName
        let scanURL = scanDirectoryURL.appendingPathComponent(scanName + ".usdz")
        let metadataURL = scanDirectoryURL.appendingPathComponent(scanName + ".plist")
        let jsonURL = scanDirectoryURL.appendingPathComponent(scanName + ".json")
        
        do {
            // Export USDZ and metadata files
            try room.export(to: scanURL, metadataURL: metadataURL)
            print("RoomScanningView: ✅ Exported scan to: \(scanURL.lastPathComponent)")
            
            // Export CapturedRoom as JSON
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            if let jsonData = try? encoder.encode(room) {
                try jsonData.write(to: jsonURL)
                print("RoomScanningView: ✅ Exported JSON to: \(jsonURL.lastPathComponent)")
            } else {
                print("RoomScanningView: ⚠️ Could not encode CapturedRoom to JSON (may not conform to Codable)")
            }
            
            let finalMetadataURL: URL?
            if FileManager.default.fileExists(atPath: metadataURL.path) {
                finalMetadataURL = metadataURL
            } else {
                finalMetadataURL = nil
            }
            
            onScanComplete(room, scanURL, finalMetadataURL)
        } catch {
            print("RoomScanningView: Failed to export scan: \(error)")
        }
    }
}

// MARK: - RoomCaptureView Wrapper
struct RoomCaptureViewRepresentable: UIViewRepresentable {
    @Binding var captureViewRef: RoomCaptureView?
    let onScanComplete: (CapturedRoom) -> Void
    let onCancel: () -> Void
    
    func makeUIView(context: Context) -> RoomCaptureView {
        let captureView = RoomCaptureView(frame: .zero)
        captureView.delegate = context.coordinator
        
        // Create configuration and start session as Apple recommends
        let config = RoomCaptureSession.Configuration()
        captureView.captureSession.run(configuration: config)
        
        // Store reference for later use
        DispatchQueue.main.async {
            self.captureViewRef = captureView
        }
        
        return captureView
    }
    
    func updateUIView(_ uiView: RoomCaptureView, context: Context) {
        // No updates needed
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }
    
    static func dismantleUIView(_ uiView: RoomCaptureView, coordinator: Coordinator) {
        uiView.captureSession.stop()
    }
    
    // MARK: - Coordinator
    @objc(RoomCaptureCoordinator) 
    class Coordinator: NSObject, RoomCaptureViewDelegate, NSCoding {
        let parent: RoomCaptureViewRepresentable
        
        init(parent: RoomCaptureViewRepresentable) {
            self.parent = parent
            super.init()
        }
        
        // MARK: - NSCoding
        required init?(coder: NSCoder) {
            fatalError("Coordinator doesn't support NSCoding")
        }
        
        func encode(with coder: NSCoder) {
            // Nothing to encode
        }
        
        // MARK: - RoomCaptureViewDelegate
        
        func captureView(shouldPresent roomDataForProcessing: CapturedRoomData, error: Error?) -> Bool {
            // Let RoomCaptureView handle the processing
            return true
        }
        
        func captureView(didPresent processedResult: CapturedRoom, error: Error?) {
            if let error = error {
                print("RoomCaptureView processing error: \(error)")
                return
            }
            
            print("RoomCaptureView: Successfully captured and processed room")
            parent.onScanComplete(processedResult)
        }
        
        func captureView(_ captureView: RoomCaptureView, didFailWithError error: Error) {
            print("RoomCaptureView failed with error: \(error)")
        }
    }
} 
