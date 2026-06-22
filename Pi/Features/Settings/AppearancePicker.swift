import SwiftUI

/// A nicer appearance selector — three tappable icon cards (System / Light /
/// Dark) instead of a plain segmented control.
struct AppearancePicker: View {
    @Binding var rawValue: String

    private let options: [(appearance: AppAppearance, icon: String)] = [
        (.system, "circle.lefthalf.filled"),
        (.light, "sun.max.fill"),
        (.dark, "moon.stars.fill"),
    ]

    var body: some View {
        HStack(spacing: DS.Spacing.sm) {
            ForEach(options, id: \.appearance) { option in
                let selected = rawValue == option.appearance.rawValue
                Button {
                    Haptics.select()
                    withAnimation(DS.spring) { rawValue = option.appearance.rawValue }
                } label: {
                    VStack(spacing: 7) {
                        Image(systemName: option.icon)
                            .font(.title2)
                            .symbolRenderingMode(.hierarchical)
                        Text(option.appearance.label)
                            .font(.caption.weight(.semibold))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, DS.Spacing.md)
                    .foregroundStyle(selected ? DS.onAccent : Color.primary)
                    .background(
                        RoundedRectangle(cornerRadius: DS.Radius.md, style: .continuous)
                            .fill(selected ? AnyShapeStyle(DS.accent) : AnyShapeStyle(Color(.tertiarySystemFill)))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: DS.Radius.md, style: .continuous)
                            .strokeBorder(Color.primary.opacity(selected ? 0 : 0.06), lineWidth: 0.5)
                    )
                }
                .buttonStyle(PressableButtonStyle())
                .accessibilityLabel(option.appearance.label)
                .accessibilityAddTraits(selected ? [.isButton, .isSelected] : .isButton)
            }
        }
    }
}
