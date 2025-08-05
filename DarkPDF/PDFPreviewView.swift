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
    let theme: DarkTheme

    var body: some View {
        Representable(url: url, theme: theme)
            .background(theme.backgroundColor)
    }
}

#if os(macOS)
struct Representable: NSViewRepresentable {
    let url: URL
    let theme: DarkTheme

    func makeNSView(context: Context) -> PDFView {
        let view = PDFView()
        view.autoScales = true
        view.displayMode = .singlePageContinuous
        view.backgroundColor = NSColor(theme.backgroundColor)
        view.document = PDFDocument(url: url)
        return view
    }

    func updateNSView(_ nsView: PDFView, context: Context) {
        nsView.backgroundColor = NSColor(theme.backgroundColor)
        if nsView.document?.documentURL != url {
            nsView.document = PDFDocument(url: url)
        }
    }
}
#else
struct Representable: UIViewRepresentable {
    let url: URL
    let theme: DarkTheme

    func makeUIView(context: Context) -> PDFView {
        let view = PDFView()
        view.autoScales = true
        view.displayMode = .singlePageContinuous
        view.backgroundColor = UIColor(theme.backgroundColor)
        view.document = PDFDocument(url: url)
        return view
    }

    func updateUIView(_ uiView: PDFView, context: Context) {
        uiView.backgroundColor = UIColor(theme.backgroundColor)
        if uiView.document?.documentURL != url {
            uiView.document = PDFDocument(url: url)
        }
    }
}
#endif

#if os(macOS)
private extension NSColor {
    convenience init(_ color: Color) {
        self.init(cgColor: color.cgColor ?? NSColor.clear.cgColor)!
    }
}
#else
private extension UIColor {
    convenience init(_ color: Color) {
        self.init(cgColor: color.cgColor!)
    }
}
#endif
