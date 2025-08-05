import Foundation
import PDFKit
import CoreGraphics

/// Performs black and white inversion on PDF content while preserving vector data.
final class PDFProcessor {
    /// Converts the PDF at the given URL by inverting all colors and writes the result next to the original.
    /// - Parameter url: location of the source PDF
    /// - Returns: URL of the processed PDF
    func convert(url: URL) throws -> URL {
        guard let input = CGPDFDocument(url as CFURL) else {
            throw NSError(domain: "PDFProcessor", code: -1, userInfo: [NSLocalizedDescriptionKey: "Unable to open PDF"])
        }

        let outData = NSMutableData()
        guard let consumer = CGDataConsumer(data: outData as CFMutableData),
              let context = CGContext(consumer: consumer, mediaBox: nil, nil) else {
            throw NSError(domain: "PDFProcessor", code: -2, userInfo: [NSLocalizedDescriptionKey: "Unable to create context"])
        }

        for index in 1...input.numberOfPages {
            guard let page = input.page(at: index) else { continue }
            var mediaBox = page.getBoxRect(.mediaBox)
            context.beginPage(mediaBox: &mediaBox)

            // Draw original page content to preserve vectors and text.
            context.drawPDFPage(page)

            // Overlay a white rectangle with difference blend mode to invert colors.
            context.saveGState()
            context.setBlendMode(.difference)
            context.setFillColor(gray: 1, alpha: 1)
            context.fill(mediaBox)
            context.restoreGState()

            context.endPage()
        }

        context.closePDF()

        let outputURL = url.deletingPathExtension().appendingPathExtension("inverted.pdf")
        try outData.write(to: outputURL, options: .atomic)
        return outputURL
    }
}
