import SwiftUI
import UniformTypeIdentifiers

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
    @State private var theme: DarkTheme = .darkGray
    @State private var isImporting = false
    @State private var processing = false
    @State private var exportedDoc = ProcessedPDF()
    @State private var exportName = "inverted.pdf"
    @State private var isExporting = false

    var body: some View {
        VStack(spacing: 0) {
            ZStack {
                if let url = pdfURLs.first {
                    PDFPreviewView(url: url, theme: theme)
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

                Picker("Theme", selection: $theme) {
                    ForEach(DarkTheme.allCases) { theme in
                        Text(theme.rawValue).tag(theme)
                    }
                }
                .pickerStyle(.menu)

                Spacer()

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
    }

    private func processFiles(urls: [URL]) {
        processing = true
        DispatchQueue.global(qos: .userInitiated).async {
            let processor = PDFProcessor()
            var outputURLs: [URL] = []
            var exportData: Data?
            var exportFilename = "inverted.pdf"

            for url in urls {
                // Access security-scoped resources so files selected from outside the sandbox can be read
                guard url.startAccessingSecurityScopedResource() else { continue }
                defer { url.stopAccessingSecurityScopedResource() }

                if let data = try? processor.convert(url: url) {
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
                    self.pdfURLs.insert(contentsOf: outputURLs, at: 0)
                }
                if let data = exportData {
                    self.exportedDoc = ProcessedPDF(data: data)
                    self.exportName = exportFilename
                }
            }
        }
    }
}

#Preview {
    ContentView()
}
