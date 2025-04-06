import SwiftUI
import RoomPlan

struct RoomScanningView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var capturedRoom: CapturedRoom?
    @State private var showingExportSheet = false
    @State private var exportURL: URL?
    @State private var scanningViewRef: RoomCaptureRepresentableRef? = nil
    
    var onScanComplete: (CapturedRoom) -> Void
    
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
                            Button("Done") {
                                if let scanningViewRef = scanningViewRef {
                                    scanningViewRef.finishScanning()
                                }
                            }
                            .padding()
                            .buttonStyle(PlainButtonStyle())
                            .background(Color.clear)
                            .fontWeight(Font.Weight.bold)
                        } else {
                            Button("Export") {
                                exportRoom()
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
        .sheet(isPresented: $showingExportSheet) {
            if let exportURL = exportURL {
                ShareSheet(items: [exportURL])
            }
        }
    }
    
    private func exportRoom() {
        guard let capturedRoom = capturedRoom else { return }
        
        // Create a temporary file URL for the USDZ
        let temporaryDirectoryURL = FileManager.default.temporaryDirectory
        let exportURL = temporaryDirectoryURL.appendingPathComponent("room_scan_\(Date().timeIntervalSince1970).usdz")
        
        do {
            // Export the room to USDZ
            try capturedRoom.export(to: exportURL)
            self.exportURL = exportURL
            self.showingExportSheet = true
            
            // Also call the completion handler
            onScanComplete(capturedRoom)
        } catch {
            print("Failed to export room: \(error)")
        }
    }
}

// A share sheet to export the USDZ file
struct ShareSheet: UIViewControllerRepresentable {
    var items: [Any]
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(activityItems: items, applicationActivities: nil)
        return controller
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {
        // Nothing to update
    }
}

// A reference class to control the RoomCaptureView from outside
class RoomCaptureRepresentableRef {
    var captureView: RoomCaptureView?
    
    func finishScanning() {
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
        self.reference = ref
        
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
                print("Error processing room: \(error.localizedDescription)")
                return
            }
            
            parent.onScanComplete(processedResult)
        }
    }
} 
