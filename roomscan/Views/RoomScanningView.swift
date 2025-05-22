import SwiftUI
import RoomPlan

struct RoomScanningView: View {
    
    @Environment(\.dismiss) private var dismiss
    var scanDirectoryURL: URL?
    
    @State private var capturedRoom: CapturedRoom?
    @State private var scanURL: URL?

    @State private var showingExportSheet = false
    @State private var scanningViewRef: RoomCaptureRepresentableRef? = nil
    
    var onScanComplete: (CapturedRoom) -> Void
    
    var body: some View {
        ZStack {
            // Single view that handles both scanning and preview
            RoomCaptureRepresentable(
                reference: $scanningViewRef,
                onScanComplete: { capturedRoom in
                    print("RoomScanningView: RCRepresentable onScanComplete: capturedRoom received.") // Modified log
                    self.capturedRoom = capturedRoom
                    print("RoomScanningView: self.capturedRoom set. UI should show 'Close' button.") // Modified log
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
                                print("RoomScanningView: 'Done' button tapped.") // Added log
                                if let scanningViewRef = scanningViewRef {
                                    scanningViewRef.finishScanning()
                                } else {
                                    print("RoomScanningView: ERROR - scanningViewRef is nil on 'Done' tap.") // Added log
                                }
                            }
                            .padding()
                            .buttonStyle(PlainButtonStyle())
                            .background(Color.clear)
                            .fontWeight(Font.Weight.bold)
                        } else {
                            Button("Close") {
                                print("RoomScanningView: 'Close' (export) button tapped.") // Added log
                                if let scanDirectoryURL = scanDirectoryURL {
                                    finishScan(scanDirectoryURL: scanDirectoryURL)
                                } else {
                                    print("RoomScanningView: ERROR - scanDirectoryURL is nil for export.") // Added log
                                }
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
        .onAppear { // Diagnostic print
            print("RoomScanningView: Appeared. scanDirectoryURL: \(scanDirectoryURL?.path ?? "nil")")
        }
    }
    
    private func finishScan(scanDirectoryURL: URL) {
        
        guard let capturedRoom = capturedRoom else { print("RoomScanningView: finishScan - ERROR: capturedRoom is nil."); return } // Modified log
        
        // Create a temporary file URL for the USDZ
        let scanURL = scanDirectoryURL.appendingPathComponent("room_scan_\(Date().timeIntervalSince1970).usdz")
        print("RoomScanningView: finishScan - Attempting to export to \(scanURL)") // Added log
        
        do {
            try capturedRoom.export(to: scanURL)
            print("RoomScanningView: finishScan - Export successful.") // Added log
            onScanComplete(capturedRoom) // This is the view's onScanComplete property
            print("RoomScanningView: finishScan - Called parent onScanComplete.") // Added log
        } catch {
            print("RoomScanningView: finishScan - Failed to export room: \(error)") // Modified log
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
