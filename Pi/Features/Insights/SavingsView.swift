import SwiftUI
import SwiftData
import Charts

/// Savings tracker: a banked running total plus monthly savings over time
/// (a bar chart + per-month list). Returns Sections to embed in the Insights list.
struct SavingsView: View {
    @Query(sort: \SavingsRecord.monthStart) private var records: [SavingsRecord]
    @Query private var expenses: [Expense]
    @Query private var commitments: [Commitment]
    @Query private var settingsList: [BudgetSettings]

    private var currencyCode: String { settingsList.first?.currencyCode ?? "INR" }

    private var expendableMinor: Int {
        let income = settingsList.first?.monthlyIncomeMinor ?? 0
        let committed = commitments.filter(\.isActive).reduce(0) { $0 + $1.amountMinor }
        return max(0, income - committed)
    }

    private var thisMonthOutflowMinor: Int {
        let now = Date.now
        return expenses
            .filter { $0.direction.isOutflow && BudgetEngine.isInCurrentMonth($0.date, now: now, calendar: .current) }
            .reduce(0) { $0 + $1.amountMinor }
    }

    private var currentSavedMinor: Int { expendableMinor - thisMonthOutflowMinor }

    struct MonthSaving: Identifiable {
        let date: Date
        let minor: Int
        var id: Date { date }
    }

    /// Past records plus the live current month, oldest first.
    private var series: [MonthSaving] {
        let cal = Calendar.current
        let currentStart = BudgetEngine.monthInterval(now: .now, calendar: cal).start
        var items = records
            .filter { !cal.isDate($0.monthStart, equalTo: currentStart, toGranularity: .month) }
            .map { MonthSaving(date: $0.monthStart, minor: $0.savedMinor) }
        items.append(MonthSaving(date: currentStart, minor: currentSavedMinor))
        return items.sorted { $0.date < $1.date }
    }

    private var totalMinor: Int { series.reduce(0) { $0 + $1.minor } }

    var body: some View {
        Section {
            VStack(alignment: .leading, spacing: 4) {
                Text("Total saved")
                    .font(.subheadline).foregroundStyle(.secondary)
                Text(Money(minorUnits: totalMinor, currencyCode: currencyCode).formatted())
                    .font(.system(size: 36, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .contentTransition(.numericText())
                    .animation(DS.spring, value: totalMinor)
                    .foregroundStyle(totalMinor >= 0 ? DS.positive : DS.negative)
            }
        } footer: {
            Text("Each month's leftover (expendable income − spent) is banked here.")
        }

        Section("Over time") {
            Chart(series) { item in
                BarMark(
                    x: .value("Month", item.date, unit: .month),
                    y: .value("Saved", Double(item.minor) / 100)
                )
                .cornerRadius(5)
                .foregroundStyle(item.minor >= 0 ? DS.positive : DS.negative)
            }
            .chartXAxis {
                AxisMarks(values: .stride(by: .month)) { _ in
                    AxisValueLabel(format: .dateTime.month(.narrow))
                }
            }
            .frame(height: 170)
            .padding(.vertical, 4)
        }

        Section("By month") {
            ForEach(series.reversed()) { item in
                HStack {
                    Text(item.date.formatted(.dateTime.month(.wide).year()))
                    Spacer()
                    Text(Money(minorUnits: item.minor, currencyCode: currencyCode).formatted())
                        .monospacedDigit()
                        .foregroundStyle(item.minor >= 0 ? DS.positive : DS.negative)
                }
            }
        }
    }
}
