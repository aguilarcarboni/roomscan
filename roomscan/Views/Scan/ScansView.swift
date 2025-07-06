import SwiftUI
import Foundation

struct ScansView: View {
    // List of found USDZ files
    @State private var scanFiles: [URL] = []

    // Sheet state – the sheet will present automatically when this becomes non-nil
    @State private var currentScanDirectoryURL: URL?

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
                    HStack {
                        Image(systemName: "square.3.layers.3d.down.right")
                        Text(url.deletingPathExtension().lastPathComponent)
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
        .sheet(item: $currentScanDirectoryURL) { dirURL in
            RoomScanningView(
                scanDirectoryURL: dirURL,
                onScanComplete: { _, _, _ in
                    // Dismiss the sheet and refresh the list
                    currentScanDirectoryURL = nil
                    loadScans()
                }
            )
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
            // Setting this URL will trigger the sheet to present
            currentScanDirectoryURL = targetDir
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