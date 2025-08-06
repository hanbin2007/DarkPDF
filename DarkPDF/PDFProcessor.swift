import Foundation
import PDFKit
import CoreGraphics

/// Performs black and white inversion on PDF content while preserving vector data.
final class PDFProcessor {
    /// Converts the PDF at the given URL by inverting all colors and returns the resulting PDF data.
    /// - Parameters:
    ///   - url: location of the source PDF
    ///   - includeAnnotations: whether to render PDF annotations such as handwriting
    /// - Returns: Data of the processed PDF
    func convert(url: URL, includeAnnotations: Bool = true) throws -> Data {
        guard let input = CGPDFDocument(url as CFURL),
              let pdfKitDoc = PDFDocument(url: url) else {
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

            // Fill the page background so transparent regions are handled consistently.
            context.saveGState()
            context.setFillColor(gray: 1, alpha: 1)
            context.fill(mediaBox)
            context.restoreGState()

            // Draw original page content to preserve vectors and text.
            context.drawPDFPage(page)

            // Invert all non-annotation content.
            context.saveGState()
            context.setBlendMode(.difference)
            context.setFillColor(gray: 1, alpha: 1)
            context.fill(mediaBox)
            context.restoreGState()

            // Draw annotations like handwriting so they remain visible and unaltered.
            if includeAnnotations, let kitPage = pdfKitDoc.page(at: index - 1) {
                for annotation in kitPage.annotations {
                    annotation.draw(with: .mediaBox, in: context)
                }
            }

            context.endPage()
        }

        context.closePDF()

        return outData as Data
    }
}
