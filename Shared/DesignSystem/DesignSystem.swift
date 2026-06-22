import SwiftUI
import UIKit

/// Minimal design tokens shared across the app. One accent color, generous
/// spacing, soft corners, and system materials — deliberately restrained.
enum DS {
    /// Monochrome graphite accent. Adapts per appearance so it stays legible:
    /// a dark gray in light mode, a light gray in dark mode.
    static let accent = Color(uiColor: UIColor { trait in
        trait.userInterfaceStyle == .dark
            ? UIColor(red: 0.85, green: 0.85, blue: 0.87, alpha: 1) // light gray (dark mode)
            : UIColor(red: 0.17, green: 0.17, blue: 0.19, alpha: 1) // graphite (light mode)
    })

    /// Contrasting color for content placed on top of `accent`.
    static let onAccent = Color(uiColor: UIColor { trait in
        trait.userInterfaceStyle == .dark
            ? UIColor(red: 0.11, green: 0.11, blue: 0.12, alpha: 1) // near-black on light accent
            : UIColor.white                                          // white on dark accent
    })

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

    /// Semantic status colors — single source of truth (reused by call sites and
    /// by `health(forFraction:)`).
    static let positive = Color(hex: "34C759") // green
    static let warning = Color(hex: "FF9F0A")  // amber
    static let negative = Color(hex: "FF375F") // red

    /// Semantic colors for budget health.
    static func health(forFraction fraction: Double) -> Color {
        switch fraction {
        case ..<0.75: return positive
        case ..<1.0: return warning
        default: return negative
        }
    }

    /// Soft elevation used consistently on cards.
    enum Shadow {
        static let color = Color.black.opacity(0.06)
        static let radius: CGFloat = 14
        static let y: CGFloat = 6
    }

    /// Standard spring for press / state transitions.
    static let spring = Animation.spring(response: 0.32, dampingFraction: 0.7)
}

extension View {
    /// Consistent elevated card surface: continuous rounded rect, grouped
    /// surface fill, hairline border, and a soft shadow.
    func cardSurface(cornerRadius: CGFloat = DS.Radius.md, elevated: Bool = true) -> some View {
        self
            .background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(Color(.secondarySystemGroupedBackground))
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(Color.primary.opacity(0.05), lineWidth: 0.5)
            )
            .shadow(
                color: elevated ? DS.Shadow.color : .clear,
                radius: DS.Shadow.radius, x: 0, y: DS.Shadow.y
            )
    }
}

extension View {
    /// Gives a sheet/popup a translucent "glass" finish — the content behind it
    /// shows through a blur. Apply to the root view inside a `.sheet`. Defined in
    /// Shared so the app and the share extension can both use it.
    func glassPopup(cornerRadius: CGFloat = 30) -> some View {
        self
            .presentationBackground(.ultraThinMaterial)
            .presentationCornerRadius(cornerRadius)
    }
}
