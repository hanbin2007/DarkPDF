import Foundation
import PDFKit
import CoreGraphics

#if os(macOS)
import AppKit
typealias PlatformColor = NSColor
#else
import UIKit
typealias PlatformColor = UIColor
#endif

/// Simple RGBA container so colors can be compared across platforms.
private struct RGBA: Hashable {
    let r: CGFloat
    let g: CGFloat
    let b: CGFloat
    let a: CGFloat
}

private extension PlatformColor {
    /// Normalised RGBA components for comparison and hashing.
    var rgba: RGBA {
#if os(macOS)
        let rgb = usingColorSpace(.deviceRGB) ?? self
        return RGBA(r: rgb.redComponent, g: rgb.greenComponent, b: rgb.blueComponent, a: rgb.alphaComponent)
#else
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        getRed(&r, green: &g, blue: &b, alpha: &a)
        return RGBA(r: r, g: g, b: b, a: a)
#endif
    }
}

/// Performs black and white inversion on PDF content while preserving vector data.
final class PDFProcessor {
    /// Detects unique annotation colors in the provided PDF.
    /// - Parameter url: Location of the source PDF
    /// - Returns: Array of distinct colors used by annotations
    func annotationColors(url: URL) -> [PlatformColor] {
        guard let document = PDFDocument(url: url) else { return [] }
        var set = Set<RGBA>()
        var colors: [PlatformColor] = []

        for index in 0..<document.pageCount {
            guard let page = document.page(at: index) else { continue }
            for annotation in page.annotations {
                guard let color = annotation.color else { continue }
                let rgba = color.rgba
                if !set.contains(rgba) {
                    set.insert(rgba)
                    colors.append(color)
                }
            }
        }
        return colors
    }

    /// Replaces all annotation colors matching `fromColor` with `toColor` and returns new PDF data.
    /// - Parameters:
    ///   - url: Location of the source PDF
    ///   - fromColor: Color to search for
    ///   - toColor: Replacement color
    func replaceAnnotations(url: URL, fromColor: PlatformColor, toColor: PlatformColor) throws -> Data {
        guard let document = PDFDocument(url: url) else {
            throw NSError(domain: "PDFProcessor", code: -1, userInfo: [NSLocalizedDescriptionKey: "Unable to open PDF"])
        }
        let fromRGBA = fromColor.rgba

        for index in 0..<document.pageCount {
            guard let page = document.page(at: index) else { continue }
            for annotation in page.annotations {
                guard let color = annotation.color else { continue }
                if color.rgba == fromRGBA {
                    annotation.color = toColor
                }
            }
        }

        guard let data = document.dataRepresentation() else {
            throw NSError(domain: "PDFProcessor", code: -3, userInfo: [NSLocalizedDescriptionKey: "Unable to serialize PDF"])
        }
        return data
    }
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
