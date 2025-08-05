import SwiftUI

/// Available color themes for dark rendering.
enum DarkTheme: String, CaseIterable, Identifiable {
    case darkGray = "Dark Gray"
    case pureBlack = "Pure Black"
    case nightBlue = "Night Blue"

    var id: String { rawValue }

    /// Background color associated with the theme.
    var backgroundColor: Color {
        switch self {
        case .darkGray:
            return Color(white: 0.1)
        case .pureBlack:
            return .black
        case .nightBlue:
            return Color(red: 0.0, green: 0.0, blue: 0.2)
        }
    }
}

