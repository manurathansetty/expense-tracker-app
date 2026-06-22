import SwiftUI

/// Minimal design tokens shared across the app. One accent color, generous
/// spacing, soft corners, and system materials — deliberately restrained.
enum DS {
    static let accent = Color(hex: "5E5CE6") // indigo

    enum Spacing {
        static let xs: CGFloat = 4
        static let sm: CGFloat = 8
        static let md: CGFloat = 12
        static let lg: CGFloat = 16
        static let xl: CGFloat = 24
        static let xxl: CGFloat = 32
    }

    enum Radius {
        static let sm: CGFloat = 10
        static let md: CGFloat = 16
        static let lg: CGFloat = 22
        static let pill: CGFloat = 999
    }

    /// Semantic colors for budget health.
    static func health(forFraction fraction: Double) -> Color {
        switch fraction {
        case ..<0.75: return Color(hex: "34C759") // green
        case ..<1.0: return Color(hex: "FF9F0A")  // amber
        default: return Color(hex: "FF375F")       // red
        }
    }
}
