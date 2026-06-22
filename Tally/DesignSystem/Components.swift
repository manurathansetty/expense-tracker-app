import SwiftUI

/// Subtle scale + dim press feedback for tappable cards and chips. Respects
/// Reduce Motion (skips the scale, keeps a gentle dim).
struct PressableButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        PressableBody(configuration: configuration)
    }

    struct PressableBody: View {
        let configuration: ButtonStyle.Configuration
        @Environment(\.accessibilityReduceMotion) private var reduceMotion

        var body: some View {
            configuration.label
                .scaleEffect(configuration.isPressed && !reduceMotion ? 0.97 : 1)
                .opacity(configuration.isPressed ? 0.85 : 1)
                .animation(DS.spring, value: configuration.isPressed)
        }
    }
}

/// A rounded square badge holding an SF Symbol in a tinted color — used for
/// categories and people throughout the app.
struct GlyphBadge: View {
    let symbolName: String
    let colorHex: String
    var size: CGFloat = 36

    var body: some View {
        let color = Color(hex: colorHex)
        RoundedRectangle(cornerRadius: size * 0.28, style: .continuous)
            .fill(color.opacity(0.18))
            .frame(width: size, height: size)
            .overlay(
                Image(systemName: symbolName)
                    .font(.system(size: size * 0.46, weight: .semibold))
                    .foregroundStyle(color)
            )
    }
}

/// A circular monogram for a person.
struct Monogram: View {
    let name: String
    let colorHex: String
    var size: CGFloat = 36

    private var initials: String {
        let parts = name.split(separator: " ").prefix(2)
        let letters = parts.compactMap { $0.first }.map(String.init)
        return letters.joined().uppercased()
    }

    var body: some View {
        let color = Color(hex: colorHex)
        Circle()
            .fill(color.opacity(0.18))
            .frame(width: size, height: size)
            .overlay(
                Text(initials.isEmpty ? "?" : initials)
                    .font(.system(size: size * 0.38, weight: .bold))
                    .foregroundStyle(color)
            )
    }
}

/// A selectable pill used in quick-add and filters.
struct Chip: View {
    let title: String
    var systemImage: String?
    var colorHex: String?
    var isSelected: Bool

    var body: some View {
        let tint = colorHex.map { Color(hex: $0) } ?? DS.accent
        HStack(spacing: DS.Spacing.xs) {
            if let systemImage {
                Image(systemName: systemImage)
                    .font(.footnote.weight(.semibold))
            }
            Text(title)
                .font(.subheadline.weight(.medium))
        }
        .padding(.horizontal, DS.Spacing.md)
        .padding(.vertical, DS.Spacing.sm)
        .foregroundStyle(isSelected ? DS.onAccent : Color.primary)
        .background(
            Capsule().fill(isSelected ? tint : Color(.secondarySystemFill))
        )
    }
}

/// A titled container card on a grouped background.
struct CardSection<Content: View>: View {
    var title: String?
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.md) {
            if let title {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
            content
        }
        .padding(DS.Spacing.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: DS.Radius.md, style: .continuous)
                .fill(Color(.secondarySystemGroupedBackground))
        )
    }
}

/// A horizontal progress bar with a tint.
struct ProgressBar: View {
    var fraction: Double
    var tint: Color

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(Color(.tertiarySystemFill))
                Capsule()
                    .fill(tint)
                    .frame(width: max(0, min(1, fraction)) * geo.size.width)
            }
        }
        .frame(height: 8)
    }
}
