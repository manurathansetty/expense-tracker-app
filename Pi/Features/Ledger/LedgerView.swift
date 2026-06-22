import SwiftUI
import SwiftData

/// The home screen: a "safe to spend" banner over a day-grouped ledger.
struct LedgerView: View {
    @Environment(\.modelContext) private var context
    @Environment(AppRouter.self) private var router

    @Query(sort: \Expense.date, order: .reverse) private var expenses: [Expense]
    @Query private var commitments: [Commitment]
    @Query private var settingsList: [BudgetSettings]
    @Query private var recurringPayments: [RecurringPayment]

    @State private var searchText = ""

    private var upcomingDues: [RecurringPayment] {
        let now = Date.now
        return recurringPayments
            .filter { $0.isActive && RecurringEngine.isDueSoon($0.nextDueDate, now: now, within: 5) }
            .sorted { $0.nextDueDate < $1.nextDueDate }
    }

    private var settings: BudgetSettings? { settingsList.first }

    private var summary: BudgetSummary {
        let committed = commitments.filter(\.isActive).reduce(0) { $0 + $1.amountMinor }
        let now = Date.now
        let monthOutflow = expenses
            .filter { BudgetEngine.isInCurrentMonth($0.date, now: now, calendar: .current) && $0.direction.isOutflow }
            .reduce(0) { $0 + $1.amountMinor }
        return BudgetEngine.summary(
            incomeMinor: settings?.monthlyIncomeMinor ?? 0,
            committedMinor: committed,
            monthOutflowMinor: monthOutflow,
            ceilingOverrideMinor: settings?.monthlyCeilingMinor,
            now: now
        )
    }

    private var filteredExpenses: [Expense] {
        guard !searchText.isEmpty else { return expenses }
        let needle = searchText.lowercased()
        return expenses.filter {
            $0.note.lowercased().contains(needle)
            || ($0.category?.name.lowercased().contains(needle) ?? false)
            || ($0.payee?.name.lowercased().contains(needle) ?? false)
        }
    }

    private var daySections: [DaySection] {
        let calendar = Calendar.current
        let grouped = Dictionary(grouping: filteredExpenses) { calendar.startOfDay(for: $0.date) }
        return grouped.keys.sorted(by: >).map { day in
            let items = grouped[day]!.sorted { $0.date > $1.date }
            let total = items.filter { $0.direction.isOutflow }.reduce(0) { $0 + $1.amountMinor }
            return DaySection(day: day, expenses: items, outflowMinor: total)
        }
    }

    var body: some View {
        NavigationStack {
            List {
                if settings?.monthlyIncomeMinor ?? 0 > 0 || summary.spentThisMonthMinor > 0 {
                    Section {
                        SafeToSpendBanner(summary: summary, currencyCode: settings?.currencyCode ?? "INR")
                            .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                            .listRowBackground(Color.clear)
                    }
                }

                if !upcomingDues.isEmpty {
                    Section {
                        UpcomingDuesCard(payments: upcomingDues)
                            .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                            .listRowBackground(Color.clear)
                    }
                }

                if expenses.isEmpty {
                    ContentUnavailableView {
                        Label("No expenses yet", systemImage: "indianrupeesign.circle")
                    } description: {
                        Text("Tap + to add your first one.")
                    }
                }

                ForEach(daySections) { section in
                    Section {
                        ForEach(section.expenses) { expense in
                            NavigationLink {
                                EditExpenseView(expense: expense)
                            } label: {
                                ExpenseRow(expense: expense)
                            }
                        }
                        .onDelete { offsets in delete(in: section, offsets: offsets) }
                    } header: {
                        DayHeader(day: section.day, outflowMinor: section.outflowMinor,
                                  currencyCode: settings?.currencyCode ?? "INR")
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("π")
            .searchable(text: $searchText, prompt: "Search notes, themes, people")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    NavigationLink {
                        RecurringView()
                    } label: {
                        Image(systemName: "calendar.badge.clock")
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    NavigationLink {
                        PeopleView()
                    } label: {
                        Image(systemName: "person.2.fill")
                    }
                }
            }
        }
    }

    private func delete(in section: DaySection, offsets: IndexSet) {
        let service = LedgerService(context: context)
        for index in offsets {
            service.delete(section.expenses[index])
        }
    }
}

struct DaySection: Identifiable {
    let day: Date
    let expenses: [Expense]
    let outflowMinor: Int
    var id: Date { day }
}

private struct DayHeader: View {
    let day: Date
    let outflowMinor: Int
    let currencyCode: String

    var body: some View {
        HStack {
            Text(dayLabel.uppercased())
                .tracking(0.6)
            Spacer()
            Text(Money(minorUnits: outflowMinor, currencyCode: currencyCode).formattedCompact())
                .monospacedDigit()
        }
        .font(.caption.weight(.semibold))
        .foregroundStyle(.secondary)
        .textCase(nil)
    }

    private var dayLabel: String {
        let calendar = Calendar.current
        if calendar.isDateInToday(day) { return "Today" }
        if calendar.isDateInYesterday(day) { return "Yesterday" }
        return day.formatted(.dateTime.weekday(.wide).month().day())
    }
}

/// The "safe to spend" hero card on top of the ledger.
struct SafeToSpendBanner: View {
    let summary: BudgetSummary
    let currencyCode: String

    private var tint: Color { DS.health(forFraction: summary.fractionUsed) }
    private var safeMoney: Money { Money(minorUnits: max(0, summary.safeToSpendMinor), currencyCode: currencyCode) }

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.lg) {
            HStack(alignment: .firstTextBaseline) {
                Text("SAFE TO SPEND")
                    .font(.caption2.weight(.semibold))
                    .tracking(0.8)
                    .foregroundStyle(.secondary)
                Spacer()
                HStack(spacing: 4) {
                    Image(systemName: "calendar")
                    Text("\(Money(minorUnits: max(0, summary.dailyAllowanceMinor), currencyCode: currencyCode).formattedCompact())/day")
                        .monospacedDigit()
                }
                .font(.caption.weight(.semibold))
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(Capsule().fill(tint.opacity(0.16)))
                .foregroundStyle(tint)
            }

            Text(safeMoney.formatted())
                .font(.system(size: 40, weight: .bold, design: .rounded))
                .monospacedDigit()
                .contentTransition(.numericText())
                .animation(DS.spring, value: summary.safeToSpendMinor)
                .foregroundStyle(summary.safeToSpendMinor < 0 ? Color(hex: "FF375F") : .primary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)

            VStack(spacing: DS.Spacing.sm) {
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule().fill(Color(.tertiarySystemFill))
                        Capsule()
                            .fill(LinearGradient(
                                colors: [tint, tint.opacity(0.65)],
                                startPoint: .leading, endPoint: .trailing))
                            .frame(width: max(6, min(1, summary.fractionUsed) * geo.size.width))
                            .animation(DS.spring, value: summary.fractionUsed)
                    }
                }
                .frame(height: 10)

                HStack {
                    Text("\(Money(minorUnits: summary.spentThisMonthMinor, currencyCode: currencyCode).formattedCompact()) of \(Money(minorUnits: summary.ceilingMinor, currencyCode: currencyCode).formattedCompact())")
                        .monospacedDigit()
                    Spacer()
                    if summary.isPaceOver {
                        Label("Over pace", systemImage: "exclamationmark.triangle.fill")
                            .foregroundStyle(Color(hex: "FF9F0A"))
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
        }
        .padding(DS.Spacing.xl)
        .background(
            ZStack {
                RoundedRectangle(cornerRadius: 26, style: .continuous)
                    .fill(Color(.secondarySystemGroupedBackground))
                RoundedRectangle(cornerRadius: 26, style: .continuous)
                    .fill(LinearGradient(
                        colors: [tint.opacity(0.12), .clear],
                        startPoint: .topTrailing, endPoint: .bottomLeading))
            }
        )
        .overlay(
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.05), lineWidth: 0.5)
        )
        .shadow(color: DS.Shadow.color, radius: DS.Shadow.radius, x: 0, y: DS.Shadow.y)
    }
}
