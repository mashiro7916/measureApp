//
//  FileManagerView.swift
//  measureApp
//
//  Created by jacky72503 on 2025/12/15.
//

import SwiftUI
import UniformTypeIdentifiers

struct FileManagerView: View {
    @State private var files: [URL] = []
    @State private var showingShareSheet = false
    @State private var fileToShare: URL?
    
    var body: some View {
        NavigationView {
            List {
                if files.isEmpty {
                    Text("No files found")
                        .foregroundColor(.gray)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding()
                } else {
                    ForEach(files, id: \.self) { fileURL in
                        FileRowView(fileURL: fileURL) {
                            fileToShare = fileURL
                            showingShareSheet = true
                        }
                    }
                }
            }
            .navigationTitle("Saved Files")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Refresh") {
                        loadFiles()
                    }
                }
            }
            .onAppear {
                loadFiles()
            }
            .sheet(isPresented: $showingShareSheet) {
                if let fileURL = fileToShare {
                    ShareSheet(activityItems: [fileURL])
                }
            }
        }
    }
    
    private func loadFiles() {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        
        do {
            let fileURLs = try FileManager.default.contentsOfDirectory(
                at: documentsPath,
                includingPropertiesForKeys: [.creationDateKey, .fileSizeKey],
                options: .skipsHiddenFiles
            )
            
            // Filter CSV files and sort by creation date (newest first)
            files = fileURLs
                .filter { $0.pathExtension == "csv" }
                .sorted { url1, url2 in
                    let date1 = (try? url1.resourceValues(forKeys: [.creationDateKey]))?.creationDate ?? Date.distantPast
                    let date2 = (try? url2.resourceValues(forKeys: [.creationDateKey]))?.creationDate ?? Date.distantPast
                    return date1 > date2
                }
        } catch {
            print("Error loading files: \(error)")
            files = []
        }
    }
}

struct FileRowView: View {
    let fileURL: URL
    let onShare: () -> Void
    
    @State private var fileSize: String = ""
    @State private var creationDate: String = ""
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(fileURL.lastPathComponent)
                    .font(.headline)
                    .lineLimit(1)
                
                HStack(spacing: 12) {
                    if !fileSize.isEmpty {
                        Label(fileSize, systemImage: "doc")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                    if !creationDate.isEmpty {
                        Label(creationDate, systemImage: "calendar")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                }
            }
            
            Spacer()
            
            Button(action: onShare) {
                Image(systemName: "square.and.arrow.up")
                    .foregroundColor(.blue)
            }
        }
        .padding(.vertical, 4)
        .onAppear {
            loadFileInfo()
        }
    }
    
    private func loadFileInfo() {
        do {
            let resourceValues = try fileURL.resourceValues(forKeys: [.fileSizeKey, .creationDateKey])
            
            if let size = resourceValues.fileSize {
                let formatter = ByteCountFormatter()
                formatter.allowedUnits = [.useKB, .useMB]
                formatter.countStyle = .file
                fileSize = formatter.string(fromByteCount: Int64(size))
            }
            
            if let date = resourceValues.creationDate {
                let formatter = DateFormatter()
                formatter.dateStyle = .short
                formatter.timeStyle = .short
                creationDate = formatter.string(from: date)
            }
        } catch {
            print("Error loading file info: \(error)")
        }
    }
}

struct ShareSheet: UIViewControllerRepresentable {
    let activityItems: [Any]
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(
            activityItems: activityItems,
            applicationActivities: nil
        )
        return controller
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {
        // No update needed
    }
}

