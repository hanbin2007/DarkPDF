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

    var body: some View {
        Representable(url: url)
            .background(Color.black)
    }
}

#if os(macOS)
struct Representable: NSViewRepresentable {
    let url: URL

    func makeNSView(context: Context) -> PDFView {
        let view = PDFView()
        view.autoScales = true
        view.displayMode = .singlePageContinuous
        view.backgroundColor = .black
        view.document = PDFDocument(url: url)
        return view
    }

    func updateNSView(_ nsView: PDFView, context: Context) {
        if nsView.document?.documentURL != url {
            nsView.document = PDFDocument(url: url)
        }
        nsView.backgroundColor = .black
    }
}
#else
struct Representable: UIViewRepresentable {
    let url: URL

    func makeUIView(context: Context) -> PDFView {
        let view = PDFView()
        view.autoScales = true
        view.displayMode = .singlePageContinuous
        view.backgroundColor = .black
        view.document = PDFDocument(url: url)
        return view
    }

    func updateUIView(_ uiView: PDFView, context: Context) {
        if uiView.document?.documentURL != url {
            uiView.document = PDFDocument(url: url)
        }
        uiView.backgroundColor = .black
    }
}
#endif

