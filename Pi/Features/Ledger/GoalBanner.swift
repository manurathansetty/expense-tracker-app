import SwiftUI

/// A stylish, motivational banner for the month's goal — a gradient card with a
/// soft sparkle flourish, meant to make saving feel aspirational.
struct GoalBanner: View {
    let goal: String

    var body: some View {
        ZStack(alignment: .topTrailing) {
            // Decorative sparkle flourish.
            Image(systemName: "sparkles")
                .font(.system(size: 66))
                .foregroundStyle(DS.onAccent.opacity(0.15))
                .offset(x: 6, y: -4)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 6) {
                    Image(systemName: "target")
                        .font(.caption.weight(.bold))
                    Text("THIS MONTH")
                        .font(.caption2.weight(.bold))
                        .tracking(1.4)
                }
                .foregroundStyle(DS.onAccent.opacity(0.75))

                Text(goal)
                    .font(.title3.weight(.bold))
                    .foregroundStyle(DS.onAccent)
                    .lineLimit(2)
                    .minimumScaleFactor(0.85)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(DS.Spacing.lg)
        }
        .background(
            ZStack {
                LinearGradient(
                    colors: [DS.accent, DS.accent.opacity(0.8)],
                    startPoint: .topLeading, endPoint: .bottomTrailing
                )
                // Soft highlight for a bit of depth.
                RadialGradient(
                    colors: [DS.onAccent.opacity(0.12), .clear],
                    center: .topTrailing, startRadius: 4, endRadius: 220
                )
            }
        )
        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.lg, style: .continuous))
        .shadow(color: DS.Shadow.color, radius: DS.Shadow.radius, x: 0, y: DS.Shadow.y)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("This month's goal: \(goal)")
    }
}
