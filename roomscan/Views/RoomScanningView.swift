import SwiftUI
import RoomPlan

struct RoomScanningView: View {
    
    @Environment(\.dismiss) private var dismiss
    var scanDirectoryURL: URL
    
    @State private var capturedRoom: CapturedRoom?
    @State private var scanningViewRef: RoomCaptureRepresentableRef? = nil
    @State private var showingFolderNamePrompt = false
    @State private var folderNameInput = ""
    
    var onScanComplete: (_ capturedRoom: CapturedRoom, _ usdzURL: URL, _ metadataURL: URL?) -> Void
    
    var body: some View {
        ZStack {
            // Single view that handles both scanning and preview
            RoomCaptureRepresentable(
                reference: $scanningViewRef,
                onScanComplete: { capturedRoom in
                    self.capturedRoom = capturedRoom
                },
                onCancel: {
                    dismiss()
                }
            )
            .ignoresSafeArea()
            .overlay(
                VStack {
                    HStack {
                        Button("Cancel") {
                            dismiss()
                        }
                        .padding()
                        .buttonStyle(PlainButtonStyle())
                        .foregroundColor(.white)
                        .background(Color.clear)
                        
                        Spacer()
                        
                        // Show Done or Export button based on state
                        if capturedRoom == nil {
                            Button("Preview") {
                                if let scanningViewRef = scanningViewRef {
                                    scanningViewRef.finishScanning()
                                } else {
                                    print("RoomScanningView: ERROR - scanningViewRef is nil on 'Preview' tap.")
                                }
                            }
                            .padding()
                            .buttonStyle(PlainButtonStyle())
                            .background(Color.clear)
                            .fontWeight(Font.Weight.bold)
                        } else {
                            Button("Done") {
                                showingFolderNamePrompt = true
                            }
                            .padding()
                            .buttonStyle(PlainButtonStyle())
                            .background(Color.clear)
                            .fontWeight(Font.Weight.bold)
                        }
                    }
                    .padding(.top)
                    
                    Spacer()
                }
            )
        }
        .navigationBarHidden(true)
        .alert("Export Scan", isPresented: $showingFolderNamePrompt, actions: {
            TextField("Project Name", text: $folderNameInput)
            Button("Export") {
                finishScan(scanDirectoryURL: scanDirectoryURL)
            }
            Button("Cancel", role: .cancel) {}
        }, message: {
            Text("Enter a project name for your scan.")
        })
    }
    
    private func finishScan(scanDirectoryURL: URL) {

        guard let capturedRoom = capturedRoom else { print("RoomScanningView: finishScan - ERROR: capturedRoom is nil."); return } // Modified log
        
        let trimmedName = folderNameInput.trimmingCharacters(in: .whitespacesAndNewlines)
        let scanName = trimmedName.isEmpty ? "NewScan" : trimmedName
        let scanURL = scanDirectoryURL.appendingPathComponent(scanName + ".usdz")
        let metadataURL = scanDirectoryURL.appendingPathComponent(scanName + ".json")

        do {
            // Export with metadata - using .mesh option which is more commonly supported
            try capturedRoom.export(to: scanURL, metadataURL: metadataURL, modelProvider: nil, exportOptions: .mesh)
            print("RoomScanningView: ✅ Exported USDZ to temp: \(scanURL.lastPathComponent)")
            print("RoomScanningView: ✅ Exported metadata to temp: \(metadataURL.lastPathComponent)")
            
            // Verify the files were actually created
            let finalMetadataURL: URL?
            if FileManager.default.fileExists(atPath: metadataURL.path) {
                print("RoomScanningView: ✅ Both files ready for import to RoomScan app space")
                finalMetadataURL = metadataURL
            } else {
                print("RoomScanningView: ⚠️ Metadata file missing, importing USDZ only")
                finalMetadataURL = nil
            }
            
            onScanComplete(capturedRoom, scanURL, finalMetadataURL)
        } catch {
            print("RoomScanningView: finishScan - Failed to export room: \(error)")
        }
    }
}

// A reference class to control the RoomCaptureView from outside
class RoomCaptureRepresentableRef {
    var captureView: RoomCaptureView?
    
    func finishScanning() {
        print("RoomCaptureRepresentableRef: finishScanning() called, calling captureSession.stop().") // Modified log
        captureView?.captureSession.stop()
    }
}

// A UIViewRepresentable for RoomCaptureView
struct RoomCaptureRepresentable: UIViewRepresentable {
    @Binding var reference: RoomCaptureRepresentableRef?
    var onScanComplete: (CapturedRoom) -> Void
    var onCancel: () -> Void
    
    func makeUIView(context: Context) -> RoomCaptureView {
        let roomCaptureView = RoomCaptureView(frame: .zero)
        roomCaptureView.delegate = context.coordinator
        
        // Create and assign the reference
        let ref = RoomCaptureRepresentableRef()
        ref.captureView = roomCaptureView
        // Update reference binding. DispatchQueue.main.async can be safer for @Binding updates from makeUIView.
        DispatchQueue.main.async {
            self.reference = ref
        }
        
        // Create a mutable configuration
        var configuration = RoomCaptureSession.Configuration()
        configuration.isCoachingEnabled = true
        
        // Start the session when the view is created
        roomCaptureView.captureSession.run(configuration: configuration)
        
        return roomCaptureView
    }
    
    func updateUIView(_ uiView: RoomCaptureView, context: Context) {
        // No updates needed
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }
    
    // This is important for cleanup
    static func dismantleUIView(_ uiView: RoomCaptureView, coordinator: Coordinator) {
        uiView.captureSession.stop()
    }
    
    // Implement NSCoding for Coordinator
    @objc(RoomCaptureCoordinator) class Coordinator: NSObject, RoomCaptureViewDelegate, NSCoding {
        var parent: RoomCaptureRepresentable
        
        init(parent: RoomCaptureRepresentable) {
            self.parent = parent
            super.init()
        }
        
        // NSCoding implementation
        required init?(coder: NSCoder) {
            fatalError("Coordinator doesn't support NSCoding")
        }
        
        func encode(with coder: NSCoder) {
            // Nothing to encode
        }
        
        // Process the room data and handle results
        func captureView(shouldPresent roomDataForProcessing: CapturedRoomData, error: Error?) -> Bool {
            // Return true to let RoomCaptureView process the data
            return true
        }
        
        // Handle the processed result
        func captureView(didPresent processedResult: CapturedRoom, error: Error?) {
            if let error = error {
                print("Coordinator: captureView(didPresent:) ERROR - \(error.localizedDescription)") // Modified log
                return
            }
            print("Coordinator: captureView(didPresent:) successfully processed room. Calling parent.onScanComplete.") // Added log
            parent.onScanComplete(processedResult)
        }
        
        // Add didFailWithError to catch other errors
        func captureView(_ captureView: RoomCaptureView, didFailWithError error: Error) {
            print("Coordinator: captureView(didFailWithError:) called with error: \(error.localizedDescription)")
            // Optionally, inform the parent/user about the failure
            // parent.onCancel() or a specific error handler
        }
    }
} 
