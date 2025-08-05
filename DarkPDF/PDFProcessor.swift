import Foundation
import PDFKit

/// Handles PDF color conversion and exporting.
final class PDFProcessor {
    let theme: DarkTheme

    init(theme: DarkTheme) {
        self.theme = theme
    }

    /// Converts the given PDF to a themed variant. Currently acts as a placeholder
    /// by duplicating the original file.
    func convert(url: URL) throws -> URL {
        let doc = PDFDocument(url: url)
        // TODO: Replace with real color transformation logic.
        let outputURL = url.deletingPathExtension().appendingPathExtension("_dark.pdf")
        doc?.write(to: outputURL)
        return outputURL
    }
}
