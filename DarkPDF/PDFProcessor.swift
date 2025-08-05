import Foundation
import PDFKit
import CoreImage
import SwiftUI
#if os(macOS)
import AppKit
typealias PlatformImage = NSImage
typealias PlatformColor = NSColor
#else
import UIKit
typealias PlatformImage = UIImage
typealias PlatformColor = UIColor
#endif

/// Handles PDF color conversion and exporting.
final class PDFProcessor {
    let theme: DarkTheme

    init(theme: DarkTheme) {
        self.theme = theme
    }

    /// Converts the given PDF to a themed variant by performing a basic
    /// black/white inversion on both text and images.
    func convert(url: URL) throws -> URL {
        guard let doc = PDFDocument(url: url) else {
            throw NSError(domain: "PDFProcessor", code: -1, userInfo: [NSLocalizedDescriptionKey: "Unable to open PDF"]) }

        let outputDoc = PDFDocument()
        let ciContext = CIContext(options: nil)

        // Extract theme background RGB components
        let cgColor = theme.backgroundColor.cgColor ?? PlatformColor.black.cgColor
        let comps = cgColor.components ?? [0, 0, 0, 1]
        let r = comps[0]
        let g = comps.count > 2 ? comps[1] : comps[0]
        let b = comps.count > 2 ? comps[2] : comps[0]

        for index in 0..<doc.pageCount {
            guard let page = doc.page(at: index) else { continue }
            let bounds = page.bounds(for: .mediaBox)

            // Render original page to CGImage
#if os(macOS)
            guard let rep = NSBitmapImageRep(bitmapDataPlanes: nil,
                                             pixelsWide: Int(bounds.width),
                                             pixelsHigh: Int(bounds.height),
                                             bitsPerSample: 8,
                                             samplesPerPixel: 4,
                                             hasAlpha: true,
                                             isPlanar: false,
                                             colorSpaceName: .deviceRGB,
                                             bytesPerRow: 0,
                                             bitsPerPixel: 0) else { continue }
            let context = NSGraphicsContext(bitmapImageRep: rep)!
            NSGraphicsContext.saveGraphicsState()
            NSGraphicsContext.current = context
            context.cgContext.translateBy(x: 0, y: bounds.height)
            context.cgContext.scaleBy(x: 1, y: -1)
            page.draw(with: .mediaBox, to: context.cgContext)
            NSGraphicsContext.restoreGraphicsState()
            guard let rendered = rep.cgImage else { continue }
#else
            UIGraphicsBeginImageContextWithOptions(bounds.size, true, 0)
            guard let ctx = UIGraphicsGetCurrentContext() else { UIGraphicsEndImageContext(); continue }
            ctx.translateBy(x: 0, y: bounds.size.height)
            ctx.scaleBy(x: 1, y: -1)
            page.draw(with: .mediaBox, to: ctx)
            guard let rendered = UIGraphicsGetImageFromCurrentImageContext()?.cgImage else {
                UIGraphicsEndImageContext();
                continue
            }
            UIGraphicsEndImageContext()
#endif

            // Apply grayscale and inversion
            var ciImage = CIImage(cgImage: rendered)
            ciImage = ciImage.applyingFilter("CIColorControls", parameters: [kCIInputSaturationKey: 0])
            ciImage = ciImage.applyingFilter("CIColorInvert")

            // Map black background to theme color and keep whites
            let rVector = CIVector(x: (1 - r) / 3, y: (1 - r) / 3, z: (1 - r) / 3, w: 0)
            let gVector = CIVector(x: (1 - g) / 3, y: (1 - g) / 3, z: (1 - g) / 3, w: 0)
            let bVector = CIVector(x: (1 - b) / 3, y: (1 - b) / 3, z: (1 - b) / 3, w: 0)
            let bias = CIVector(x: r, y: g, z: b, w: 0)
            ciImage = ciImage.applyingFilter("CIColorMatrix", parameters: [
                "inputRVector": rVector,
                "inputGVector": gVector,
                "inputBVector": bVector,
                "inputBiasVector": bias
            ])

            guard let outputCG = ciContext.createCGImage(ciImage, from: ciImage.extent) else { continue }
#if os(macOS)
            let image = PlatformImage(cgImage: outputCG, size: bounds.size)
#else
            let image = PlatformImage(cgImage: outputCG)
#endif
            if let newPage = PDFPage(image: image) {
                outputDoc.insert(newPage, at: index)
            }
        }

        // Compose output file URL
        let baseName = url.deletingPathExtension().lastPathComponent + "_dark"
        let outputURL = url.deletingLastPathComponent().appendingPathComponent(baseName).appendingPathExtension("pdf")
        outputDoc.write(to: outputURL)
        return outputURL
    }
}
