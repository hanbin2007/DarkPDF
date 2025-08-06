import SwiftUI
import PDFKit
#if os(macOS)
import AppKit
#else
import UIKit
#endif

/// SwiftUI wrapper around PDFKit's PDFView to provide cross-platform preview.
struct PDFPreviewView: View {
    let url: URL
    let includeAnnotations: Bool

    var body: some View {
        Representable(url: url, includeAnnotations: includeAnnotations)
            .background(Color.black)
    }
}

#if os(macOS)
struct Representable: NSViewRepresentable {
    let url: URL
    let includeAnnotations: Bool

    func makeNSView(context: Context) -> PDFView {
        let view = PDFView()
        view.autoScales = true
        view.displayMode = .singlePageContinuous
        view.backgroundColor = .black
        view.document = makeDocument()
        return view
    }

    func updateNSView(_ nsView: PDFView, context: Context) {
        nsView.document = makeDocument()
        nsView.backgroundColor = .black
    }

    private func makeDocument() -> PDFDocument? {
        guard let doc = PDFDocument(url: url) else { return nil }
        if !includeAnnotations {
            for index in 0..<doc.pageCount {
                if let page = doc.page(at: index) {
                    for annotation in page.annotations {
                        page.removeAnnotation(annotation)
                    }
                }
            }
        }
        return doc
    }
}
#else
struct Representable: UIViewRepresentable {
    let url: URL
    let includeAnnotations: Bool

    func makeUIView(context: Context) -> PDFView {
        let view = PDFView()
        view.autoScales = true
        view.displayMode = .singlePageContinuous
        view.backgroundColor = .black
        view.document = makeDocument()
        return view
    }

    func updateUIView(_ uiView: PDFView, context: Context) {
        uiView.document = makeDocument()
        uiView.backgroundColor = .black
    }

    private func makeDocument() -> PDFDocument? {
        guard let doc = PDFDocument(url: url) else { return nil }
        if !includeAnnotations {
            for index in 0..<doc.pageCount {
                if let page = doc.page(at: index) {
                    for annotation in page.annotations {
                        page.removeAnnotation(annotation)
                    }
                }
            }
        }
        return doc
    }
}
#endif

