import SwiftUI
import SwiftData

/// A thin, full-bleed progress bar pinned to the very top of every tab
/// (green→red, hatched "/////" once over budget). The month's goal lives in the
/// page title; the π brand lives in the add button.
struct BudgetStripView: View {
    @Environment(\.modelContext) private var context
    // Queries re-render the bar when data changes; figures come from
    // LedgerService so the lag/carryover logic stays in one place.
    @Query private var expenses: [Expense]
    @Query private var commitments: [Commitment]
    @Query private var settingsList: [BudgetSettings]

    private var summary: BudgetSummary { LedgerService(context: context).currentSummary() }

    var body: some View {
        BudgetBar(
            fraction: summary.fractionUsed,
            tint: DS.health(forFraction: summary.fractionUsed),
            isOver: summary.isOverCeiling
        )
        .frame(height: 9)
        .frame(maxWidth: .infinity)
        .accessibilityElement()
        .accessibilityLabel("Budget used")
        .accessibilityValue("\(Int(min(1, summary.fractionUsed) * 100)) percent")
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

/// Single-direction diagonal stripes ("/////") used for the "quota used" state.
private struct HatchPattern: View {
    var body: some View {
        Canvas { context, size in
            let spacing: CGFloat = 8
            let color = Color.secondary.opacity(0.55)
            var x = -size.height
            while x < size.width {
                var stripe = Path()
                stripe.move(to: CGPoint(x: x, y: size.height))
                stripe.addLine(to: CGPoint(x: x + size.height, y: 0))
                context.stroke(stripe, with: .color(color), lineWidth: 2)
                x += spacing
            }
        }
    }
}
