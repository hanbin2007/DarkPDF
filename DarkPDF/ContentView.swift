import SwiftUI
import UniformTypeIdentifiers
#if os(macOS)
import AppKit
#else
import UIKit
#endif

/// Simple `FileDocument` wrapper so the processed PDF can be exported via SwiftUI's file exporter.
struct ProcessedPDF: FileDocument {
    static var readableContentTypes: [UTType] { [.pdf] }
    var data: Data

    init(data: Data = Data()) {
        self.data = data
    }

    init(configuration: ReadConfiguration) throws {
        self.data = configuration.file.regularFileContents ?? Data()
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: data)
    }
}

struct ContentView: View {
    @State private var pdfURLs: [URL] = []
    @State private var originalURLs: [URL] = []
    @State private var isImporting = false
    @State private var processing = false
    @State private var exportedDoc = ProcessedPDF()
    @State private var exportName = "inverted.pdf"
    @State private var isExporting = false
    @State private var includeAnnotations = true
    @State private var availableColors: [Color] = []
    @State private var showColorSheet = false

    var body: some View {
        VStack(spacing: 0) {
            ZStack {
                if let url = pdfURLs.first {
                    PDFPreviewView(url: url, includeAnnotations: includeAnnotations)
                } else {
                    Text("Drag or import PDF files to begin")
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .onDrop(of: [UTType.fileURL.identifier], isTargeted: nil) { providers in
                for provider in providers {
                    _ = provider.loadObject(ofClass: URL.self) { url, _ in
                        if let url = url, url.pathExtension.lowercased() == "pdf" {
                            DispatchQueue.main.async {
                                self.processFiles(urls: [url])
                            }
                        }
                    }
                }
                return true
            }

            controlBar
        }
        .fileImporter(isPresented: $isImporting, allowedContentTypes: [.pdf], allowsMultipleSelection: true) { result in
            switch result {
            case .success(let urls):
                processFiles(urls: urls)
            case .failure:
                break
            }
        }
        .fileExporter(isPresented: $isExporting, document: exportedDoc, contentType: .pdf, defaultFilename: exportName) { _ in
            isExporting = false
        }
        .onChange(of: includeAnnotations) { _ in
            guard !originalURLs.isEmpty else { return }
            processFiles(urls: originalURLs, replaceExisting: true)
        }
    }

    private var controlBar: some View {
        VStack {
            Divider()
            HStack {
                Button {
                    isImporting = true
                } label: {
                    Label("Add PDFs", systemImage: "plus")
                }

                Toggle("Include Annotations", isOn: $includeAnnotations)

                Spacer()

                Button {
                    detectColors()
                } label: {
                    Label("Replace Color", systemImage: "paintpalette")
                }
                .disabled(pdfURLs.isEmpty || processing)

                Button {
                    isExporting = true
                } label: {
                    Label("Export", systemImage: "square.and.arrow.up")
                }
                .disabled(exportedDoc.data.isEmpty || processing)
            }
            .padding()
        }
        .background(.thinMaterial)
        .sheet(isPresented: $showColorSheet) {
            ColorReplacementView(colors: availableColors) { original, replacement in
                replaceColor(original: original, newColor: replacement)
            }
        }
    }

    private func processFiles(urls: [URL], replaceExisting: Bool = false) {
        processing = true
        originalURLs = urls
        DispatchQueue.global(qos: .userInitiated).async {
            let processor = PDFProcessor()
            var outputURLs: [URL] = []
            var exportData: Data?
            var exportFilename = "inverted.pdf"

            for url in urls {
                // Access security-scoped resources so files selected from outside the sandbox can be read
                guard url.startAccessingSecurityScopedResource() else { continue }
                defer { url.stopAccessingSecurityScopedResource() }

                if let data = try? processor.convert(url: url, includeAnnotations: includeAnnotations) {
                    let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(url.deletingPathExtension().lastPathComponent + "_inverted.pdf")
                    try? data.write(to: tempURL)
                    outputURLs.append(tempURL)
                    exportData = data
                    exportFilename = tempURL.lastPathComponent
                }
            }

            DispatchQueue.main.async {
                self.processing = false
                if !outputURLs.isEmpty {
                    if replaceExisting {
                        self.pdfURLs = outputURLs
                    } else {
                        self.pdfURLs.insert(contentsOf: outputURLs, at: 0)
                    }
                    if let first = outputURLs.first {
                        self.availableColors = processor.annotationColors(url: first).map { Color($0) }
                    }
                }
                if let data = exportData {
                    self.exportedDoc = ProcessedPDF(data: data)
                    self.exportName = exportFilename
                }
            }
        }
    }

    private func detectColors() {
        guard let url = pdfURLs.first else { return }
        processing = true
        DispatchQueue.global(qos: .userInitiated).async {
            let processor = PDFProcessor()
            let colors = processor.annotationColors(url: url)
            DispatchQueue.main.async {
                self.availableColors = colors.map { Color($0) }
                self.processing = false
                self.showColorSheet = true
            }
        }
    }

    private func replaceColor(original: Color, newColor: Color) {
        guard let url = pdfURLs.first else { return }
        processing = true
        DispatchQueue.global(qos: .userInitiated).async {
            let processor = PDFProcessor()
#if os(macOS)
            let fromColor = NSColor(original)
            let toColor = NSColor(newColor)
#else
            let fromColor = UIColor(original)
            let toColor = UIColor(newColor)
#endif
            if let data = try? processor.replaceAnnotations(url: url, fromColor: fromColor, toColor: toColor) {
                let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".pdf")
                try? data.write(to: tempURL)
                DispatchQueue.main.async {
                    self.pdfURLs[0] = tempURL
                    self.availableColors = processor.annotationColors(url: tempURL).map { Color($0) }
                    self.exportedDoc = ProcessedPDF(data: data)
                    self.exportName = tempURL.lastPathComponent
                    self.processing = false
                }
            } else {
                DispatchQueue.main.async { self.processing = false }
            }
        }
    }
}

#Preview {
    ContentView()
}
