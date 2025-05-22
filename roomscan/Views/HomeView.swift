//
//  HomeView.swift
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

struct HomeView: View {
    
    // Use a single @State variable for sheet presentation and data
    @State private var scanInfoForSheet: ScanInfo?
    @State private var capturedRooms: [CapturedRoom] = [] // Keep this for storing results
    
    var body: some View {
        DocumentBrowserView(onStartScan: { directoryURL in
            print("HomeView: onStartScan called with URL: \(directoryURL.path)")
            // Set scanInfoForSheet to trigger the sheet
            self.scanInfoForSheet = ScanInfo(directoryURL: directoryURL)
            print("HomeView: scanInfoForSheet set. Sheet should present.")
        })
        .ignoresSafeArea(edges: .bottom)
        .sheet(item: $scanInfoForSheet) { info in // Use .sheet(item:)
            RoomScanningView(scanDirectoryURL: info.directoryURL, onScanComplete: { capturedRoom in
                self.capturedRooms.append(capturedRoom)
                print("HomeView: RoomScanningView onScanComplete. Dismissing sheet.")
                self.scanInfoForSheet = nil // Dismiss the sheet
            })
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
