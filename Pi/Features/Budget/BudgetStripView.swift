import SwiftUI
import SwiftData

/// A slim, persistent budget indicator shown at the top of every tab: how much
/// is left to spend this month, a per-day allowance, and a green→red bar that
/// flips to a hatched "quota used" state once you're over.
struct BudgetStripView: View {
    @Environment(\.modelContext) private var context
    // These queries exist to re-render the strip when data changes; the figures
    // are computed by LedgerService so the lag/carryover logic stays in one place.
    @Query private var expenses: [Expense]
    @Query private var commitments: [Commitment]
    @Query private var settingsList: [BudgetSettings]

    private var currencyCode: String { settingsList.first?.currencyCode ?? "INR" }
    private var summary: BudgetSummary { LedgerService(context: context).currentSummary() }
    private var tint: Color { DS.health(forFraction: summary.fractionUsed) }
    private var isOver: Bool { summary.isOverCeiling }

    var body: some View {
        VStack(spacing: 7) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 0) {
                    Text(isOver ? "OVER BUDGET" : "AVAILABLE")
                        .font(.caption2.weight(.semibold))
                        .tracking(0.6)
                        .foregroundStyle(.secondary)
                    Text(headlineAmount)
                        .font(.system(size: 21, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .contentTransition(.numericText())
                        .animation(DS.spring, value: summary.safeToSpendMinor)
                        .foregroundStyle(isOver ? Color(hex: "FF375F") : .primary)
                }
                Spacer()
                if isOver {
                    Label("Quota used", systemImage: "xmark.circle.fill")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                } else {
                    Text("\(Money(minorUnits: max(0, summary.dailyAllowanceMinor), currencyCode: currencyCode).formattedCompact())/day")
                        .font(.caption.weight(.semibold))
                        .monospacedDigit()
                        .foregroundStyle(tint)
                        .padding(.horizontal, 9)
                        .padding(.vertical, 4)
                        .background(Capsule().fill(tint.opacity(0.16)))
                }
            }
            BudgetBar(fraction: summary.fractionUsed, tint: tint, isOver: isOver)
        }
        .padding(.horizontal, DS.Spacing.lg)
        .padding(.top, DS.Spacing.sm)
        .padding(.bottom, DS.Spacing.md)
        .background(.bar)
    }

    private var headlineAmount: String {
        if isOver {
            let over = Money(minorUnits: -summary.safeToSpendMinor, currencyCode: currencyCode)
            return "Over by \(over.formatted())"
        }
        return Money(minorUnits: max(0, summary.safeToSpendMinor), currencyCode: currencyCode).formatted()
    }
}

/// The progress bar: a gradient fill normally, a hatched gray bar when over budget.
private struct BudgetBar: View {
    var fraction: Double
    var tint: Color
    var isOver: Bool

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(Color(.tertiarySystemFill))
                if isOver {
                    Capsule()
                        .fill(Color(.systemGray3))
                        .overlay(HatchPattern().clipShape(Capsule()))
                } else {
                    Capsule()
                        .fill(LinearGradient(colors: [tint, tint.opacity(0.65)],
                                             startPoint: .leading, endPoint: .trailing))
                        .frame(width: max(6, min(1, fraction) * geo.size.width))
                        .animation(DS.spring, value: fraction)
                }
            }
        }
        .frame(height: 9)
    }
}

/// Diagonal cross-hatch used for the "quota used" state.
private struct HatchPattern: View {
    var body: some View {
        Canvas { context, size in
            let spacing: CGFloat = 7
            let color = Color.secondary.opacity(0.45)
            var x = -size.height
            while x < size.width {
                var up = Path()
                up.move(to: CGPoint(x: x, y: size.height))
                up.addLine(to: CGPoint(x: x + size.height, y: 0))
                context.stroke(up, with: .color(color), lineWidth: 1.2)
                var down = Path()
                down.move(to: CGPoint(x: x, y: 0))
                down.addLine(to: CGPoint(x: x + size.height, y: size.height))
                context.stroke(down, with: .color(color), lineWidth: 1.2)
                x += spacing
            }
        }
    }
}
