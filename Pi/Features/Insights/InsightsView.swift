import SwiftUI
import SwiftData

/// Per-theme spend total used by the insights list.
struct ThemeStat: Identifiable {
    let category: Category?
    let amountMinor: Int
    var id: UUID { category?.id ?? Self.uncategorizedID }
    static let uncategorizedID = UUID()
}

/// Spending breakdown by theme and by person, for this month or all time, with
/// each theme shown as a percentage of expendable income.
struct InsightsView: View {
    @Query private var expenses: [Expense]
    @Query(sort: \Category.sortIndex) private var categories: [Category]
    @Query private var commitments: [Commitment]
    @Query private var settingsList: [BudgetSettings]
    @Query(sort: \Payee.createdAt, order: .reverse) private var payees: [Payee]

    enum Mode: String, CaseIterable, Identifiable {
        case spending = "Spending"
        case savings = "Savings"
        var id: String { rawValue }
    }
    @State private var mode: Mode =
        ProcessInfo.processInfo.environment["TALLY_INSIGHTS"] == "savings" ? .savings : .spending

    enum Period: String, CaseIterable, Identifiable {
        case month = "This Month"
        case all = "All Time"
        var id: String { rawValue }
    }
    @State private var period: Period = .month

    private var currencyCode: String { settingsList.first?.currencyCode ?? "INR" }

    private var expendableMinor: Int {
        let income = settingsList.first?.monthlyIncomeMinor ?? 0
        let committed = commitments.filter(\.isActive).reduce(0) { $0 + $1.amountMinor }
        return max(0, income - committed)
    }

    private var periodExpenses: [Expense] {
        let now = Date.now
        return expenses.filter { expense in
            guard expense.direction.isOutflow else { return false }
            switch period {
            case .all: return true
            case .month: return BudgetEngine.isInCurrentMonth(expense.date, now: now, calendar: .current)
            }
        }
    }

    private var totalMinor: Int { periodExpenses.reduce(0) { $0 + $1.amountMinor } }

    private var themeStats: [ThemeStat] {
        var buckets: [UUID: Int] = [:]
        var uncategorized = 0
        for expense in periodExpenses {
            if let id = expense.category?.id {
                buckets[id, default: 0] += expense.amountMinor
            } else {
                uncategorized += expense.amountMinor
            }
        }
        var stats = categories.compactMap { category -> ThemeStat? in
            guard let amount = buckets[category.id], amount > 0 else { return nil }
            return ThemeStat(category: category, amountMinor: amount)
        }
        if uncategorized > 0 {
            stats.append(ThemeStat(category: nil, amountMinor: uncategorized))
        }
        return stats.sorted { $0.amountMinor > $1.amountMinor }
    }

    private var peopleWithBalance: [Payee] {
        payees.filter { $0.netBalanceMinor != 0 }
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Picker("Mode", selection: $mode) {
                        ForEach(Mode.allCases) { Text($0.rawValue).tag($0) }
                    }
                    .pickerStyle(.segmented)
                    .listRowBackground(Color.clear)
                }

                if mode == .spending {
                    Section {
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text("Spent")
                                    .font(.subheadline).foregroundStyle(.secondary)
                                Spacer()
                                Picker("Period", selection: $period) {
                                    ForEach(Period.allCases) { Text($0.rawValue).tag($0) }
                                }
                                .labelsHidden()
                                .pickerStyle(.menu)
                                .tint(.secondary)
                            }
                            Text(Money(minorUnits: totalMinor, currencyCode: currencyCode).formatted())
                                .font(.system(size: 36, weight: .bold, design: .rounded))
                                .monospacedDigit()
                                .contentTransition(.numericText())
                                .animation(DS.spring, value: totalMinor)
                        }
                    }

                    Section("By theme") {
                        if themeStats.isEmpty {
                            Text("No spending in this period.").foregroundStyle(.secondary)
                        }
                        ForEach(themeStats) { stat in
                            ThemeStatRow(
                                stat: stat,
                                totalMinor: totalMinor,
                                expendableMinor: period == .month ? expendableMinor : 0,
                                currencyCode: currencyCode
                            )
                        }
                    }

                    if !peopleWithBalance.isEmpty {
                        Section("People") {
                            ForEach(peopleWithBalance) { payee in
                                HStack {
                                    Monogram(name: payee.name, colorHex: payee.colorHex, size: 28)
                                    Text(payee.name)
                                    Spacer()
                                    Text(Money(minorUnits: payee.netBalanceMinor, currencyCode: currencyCode).formatted())
                                        .foregroundStyle(payee.netBalanceMinor >= 0 ? DS.positive : DS.negative)
                                }
                            }
                        }
                    }
                } else {
                    SavingsView()
                }
            }
            .listSectionSpacing(14)
            .navigationTitle("Insights")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

private struct ThemeStatRow: View {
    let stat: ThemeStat
    let totalMinor: Int
    let expendableMinor: Int
    let currencyCode: String

    private var shareOfTotal: Double {
        totalMinor > 0 ? Double(stat.amountMinor) / Double(totalMinor) : 0
    }
    private var shareOfExpendable: Double {
        expendableMinor > 0 ? Double(stat.amountMinor) / Double(expendableMinor) : 0
    }
    private var tint: Color { Color(hex: stat.category?.colorHex ?? "8E8E93") }

    var body: some View {
        VStack(spacing: DS.Spacing.sm) {
            HStack(spacing: DS.Spacing.md) {
                GlyphBadge(
                    symbolName: stat.category?.symbolName ?? "questionmark",
                    colorHex: stat.category?.colorHex ?? "8E8E93",
                    size: 30
                )
                Text(stat.category?.name ?? "Uncategorized")
                Spacer()
                Text(Money(minorUnits: stat.amountMinor, currencyCode: currencyCode).formattedCompact())
                    .font(.subheadline.weight(.semibold))
                    .monospacedDigit()
            }
            ProgressBar(fraction: shareOfTotal, tint: tint)
            HStack {
                Text("\(Int(shareOfTotal * 100))% of spend")
                Spacer()
                if expendableMinor > 0 {
                    Text("\(Int(shareOfExpendable * 100))% of income")
                }
            }
            .font(.caption2)
            .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
    }
}
