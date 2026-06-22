import SwiftUI
import SwiftData

/// The persistent top header on every tab: the month's goal/intention (set in
/// Settings), the days left in the month, and a thin full-bleed progress bar
/// (green→red, hatched once over budget).
struct BudgetStripView: View {
    @Environment(\.modelContext) private var context
    @Environment(AppRouter.self) private var router
    // Queries re-render the header when data changes; figures come from
    // LedgerService so the lag/carryover logic stays in one place.
    @Query private var expenses: [Expense]
    @Query private var commitments: [Commitment]
    @Query private var settingsList: [BudgetSettings]

    private var summary: BudgetSummary { LedgerService(context: context).currentSummary() }
    private var goal: String {
        (settingsList.first?.monthlyGoal ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var body: some View {
        VStack(spacing: DS.Spacing.sm) {
            Button {
                Haptics.tap()
                router.selectedTab = .settings
            } label: {
                HStack(spacing: DS.Spacing.sm) {
                    Image(systemName: goal.isEmpty ? "sparkles" : "target")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(goal.isEmpty ? AnyShapeStyle(Color.secondary) : AnyShapeStyle(DS.accent))
                    Text(goal.isEmpty ? "What are you working toward this month?" : goal)
                        .font(.subheadline.weight(goal.isEmpty ? .regular : .semibold))
                        .foregroundStyle(goal.isEmpty ? .secondary : .primary)
                        .lineLimit(1)
                    Spacer(minLength: DS.Spacing.sm)
                    Text("\(summary.daysRemaining)d left")
                        .font(.caption2.weight(.semibold))
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .padding(.horizontal, DS.Spacing.lg)
            .padding(.top, DS.Spacing.xs)

            BudgetBar(
                fraction: summary.fractionUsed,
                tint: DS.health(forFraction: summary.fractionUsed),
                isOver: summary.isOverCeiling
            )
            .frame(height: 5)
            .frame(maxWidth: .infinity)
        }
        .background(.bar, ignoresSafeAreaEdges: .top)
    }
}

/// Full-width progress bar: a gradient fill normally, a hatched gray bar when over.
private struct BudgetBar: View {
    var fraction: Double
    var tint: Color
    var isOver: Bool

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Rectangle().fill(Color(.tertiarySystemFill))
                if isOver {
                    Rectangle()
                        .fill(Color(.systemGray3))
                        .overlay(HatchPattern())
                } else {
                    Rectangle()
                        .fill(LinearGradient(colors: [tint, tint.opacity(0.7)],
                                             startPoint: .leading, endPoint: .trailing))
                        .frame(width: max(2, min(1, fraction) * geo.size.width))
                        .animation(DS.spring, value: fraction)
                }
            }
        }
    }
}

/// Diagonal cross-hatch used for the "quota used" state.
private struct HatchPattern: View {
    var body: some View {
        Canvas { context, size in
            let spacing: CGFloat = 6
            let color = Color.secondary.opacity(0.5)
            var x = -size.height
            while x < size.width {
                var up = Path()
                up.move(to: CGPoint(x: x, y: size.height))
                up.addLine(to: CGPoint(x: x + size.height, y: 0))
                context.stroke(up, with: .color(color), lineWidth: 1.1)
                var down = Path()
                down.move(to: CGPoint(x: x, y: 0))
                down.addLine(to: CGPoint(x: x + size.height, y: size.height))
                context.stroke(down, with: .color(color), lineWidth: 1.1)
                x += spacing
            }
        }
    }
}
