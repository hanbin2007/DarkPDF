import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
    @State private var pdfURLs: [URL] = []
    @State private var theme: DarkTheme = .darkGray
    @State private var isImporting = false
    @State private var processing = false

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
                                self.pdfURLs.append(url)
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
                pdfURLs.append(contentsOf: urls)
            case .failure:
                break
            }
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
                    processFiles()
                } label: {
                    Label("Convert", systemImage: "wand.and.stars")
                }
                .disabled(pdfURLs.isEmpty || processing)
            }
            .padding()
        }
        .background(.thinMaterial)
    }

    private func processFiles() {
        processing = true
        let processor = PDFProcessor(theme: theme)
        for url in pdfURLs {
            _ = try? processor.convert(url: url)
        }
        processing = false
    }
}

#Preview {
    ContentView()
}
