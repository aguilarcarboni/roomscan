//
//  ContentView.swift
//  roomplan
//
//  Created by Andrés on 5/4/2025.
//

import SwiftUI
import RoomPlan
import ARKit

// Define an Identifiable struct to hold the scan directory URL
struct ScanInfo: Identifiable {
    let id = UUID()
    let directoryURL: URL
}

struct ContentView: View {
    
    @State private var scanInfoForSheet: ScanInfo?
    @State private var capturedRooms: [CapturedRoom] = []
    
    var body: some View {
        DocumentBrowserView(onStartScan: { directoryURL in
            self.scanInfoForSheet = ScanInfo(directoryURL: directoryURL)
        })
        .ignoresSafeArea(edges: .bottom)
        .sheet(item: $scanInfoForSheet) { info in
            RoomScanningView(
                scanDirectoryURL: info.directoryURL, 
                onScanComplete: { capturedRoom, _ in
                    print("ContentView: Scan complete, capturedRoom received.")
                    self.capturedRooms.append(capturedRoom)
                    self.scanInfoForSheet = nil
                }
            )
        }
    }
    
    private func isDeviceSupported() -> Bool {
        if ARWorldTrackingConfiguration.supportsSceneReconstruction(.mesh) {
            return true
        }
        return false
    }
    
    private func checkCameraPermission(completion: @escaping (Bool) -> Void) {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            completion(true)
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { granted in
                DispatchQueue.main.async {
                    completion(granted)
                }
            }
        default:
            completion(false)
        }
    }
}
