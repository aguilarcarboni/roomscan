//
//  ContentView.swift
//  roomplan
//
//  Created by Andrés on 5/4/2025.
//

import SwiftUI
import RoomPlan
import ARKit

struct ContentView: View {
    @State private var showingScanner = false
    @State private var capturedRoom: CapturedRoom?
    @State private var showingAlert = false
    @State private var alertMessage = ""
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 30) {
                
                Spacer()
                
                if !isDeviceSupported() {
                    // Warning for non-LiDAR devices
                    VStack(spacing: 10) {
                        Image(systemName: "exclamationmark.triangle")
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 50, height: 50)
                            .foregroundColor(.red)
                        
                        Text("This device does not support RoomPlan.\nA LiDAR sensor is required.")
                            .multilineTextAlignment(.center)
                            .foregroundColor(.red)
                            .padding()
                    }
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.red.opacity(0.1))
                    )
                    .padding()
                } else  {
                    VStack {
                        Image(systemName: "cube.transparent")
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 100, height: 100)
                            .foregroundColor(Color("AccentColor"))
                        
                        Text("RoomScan")
                            .font(.largeTitle)
                            .fontWeight(.bold)
                            
                        Text("Scan a room to get started")
                            .font(.subheadline)
                            .foregroundColor(.gray)
                            
                    }
                }
                
                Spacer()
            }
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        checkCameraPermission { granted in
                            if granted {
                                showingScanner = true
                            } else {
                                alertMessage = "Camera access is required for scanning rooms."
                                showingAlert = true
                            }
                        }
                    }) {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingScanner) {
                NavigationStack {
                    RoomScanningView { room in
                        self.capturedRoom = room
                    }
                }
            }
            .alert("Notice", isPresented: $showingAlert) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(alertMessage)
            }
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

#Preview {
    ContentView()
}
