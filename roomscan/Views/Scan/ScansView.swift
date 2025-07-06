import SwiftUI
import Foundation

struct ScansView: View {
    // List of found USDZ files
    @State private var scanFiles: [URL] = []

    // Sheet states
    @State private var isPresentingScanner = false
    @State private var currentScanDirectoryURL: URL?
    @State private var selectedScanURL: URL?

    var body: some View {
        VStack {
            if scanFiles.isEmpty {
                Spacer()
                VStack(spacing: 12) {
                    Image(systemName: "shippingbox")
                        .font(.system(size: 48))
                        .foregroundStyle(.secondary)
                    Text("No scans yet")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            } else {
                List(scanFiles, id: \.self) { url in
                    Button {
                        selectedScanURL = url
                    } label: {
                        HStack {
                            Image(systemName: "square.3.layers.3d.down.right")
                            Text(url.deletingPathExtension().lastPathComponent)
                        }
                    }
                }
            }
        }
        .navigationTitle("Scans")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: startNewScan) {
                    Image(systemName: "plus")
                }
            }
        }
        // Room scanning sheet
        .sheet(isPresented: $isPresentingScanner) {
            if let dirURL = currentScanDirectoryURL {
                RoomScanningView(
                    scanDirectoryURL: dirURL,
                    onScanComplete: { _, _, _ in
                        isPresentingScanner = false
                        loadScans() // refresh list with newly saved files
                    }
                )
            }
        }
        // Existing scan preview sheet
        .sheet(item: $selectedScanURL) { url in
            SceneKit3DEditorView(modelURL: url) {
                selectedScanURL = nil
            }
        }
        .onAppear {
            loadScans()
        }
    }

    // MARK: - Helpers

    private func startNewScan() {
        // Create new folder inside Documents, then present scanner
        guard let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else { return }
        let formatter = ISO8601DateFormatter()
        let folderName = "Scan-" + formatter.string(from: Date())
        let targetDir = documentsURL.appendingPathComponent(folderName, isDirectory: true)
        do {
            try FileManager.default.createDirectory(at: targetDir, withIntermediateDirectories: true)
            currentScanDirectoryURL = targetDir
            isPresentingScanner = true
        } catch {
            print("ScansView: ❌ Failed to create scan directory: \(error)")
        }
    }

    private func loadScans() {
        let fileManager = FileManager.default
        guard let documentsURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first else {
            return
        }

        var found: [URL] = []
        if let enumerator = fileManager.enumerator(at: documentsURL, includingPropertiesForKeys: [.contentModificationDateKey], options: [.skipsHiddenFiles]) {
            for case let fileURL as URL in enumerator {
                if fileURL.pathExtension.lowercased() == "usdz" {
                    found.append(fileURL)
                }
            }
        }

        // Sort by modification date, newest first
        scanFiles = found.sorted { lhs, rhs in
            let lhsDate = (try? lhs.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
            let rhsDate = (try? rhs.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
            return lhsDate > rhsDate
        }
    }
} 