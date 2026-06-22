import SwiftUI
import SwiftData

/// The budgeting hub: income, commitment blocks, expendable income, the spending
/// blocker, theme allocations, and a month-end pace projection.
struct BudgetView: View {
    @Environment(\.modelContext) private var context
    @Query private var expenses: [Expense]
    @Query(sort: \Commitment.createdAt) private var commitments: [Commitment]
    @Query(sort: \Category.sortIndex) private var categories: [Category]
    @Query private var settingsList: [BudgetSettings]

    @State private var showIncomeEditor = false
    @State private var showCeilingEditor = false
    @State private var editingCommitment: Commitment?
    @State private var showAddCommitment = false

    // Non-mutating: never insert during `body`. The persistent row is created
    // once in `.task` below (and at app launch). The transient default only backs
    // the brief first frame before seeding completes.
    private var settings: BudgetSettings {
        settingsList.first ?? BudgetSettings()
    }

    private var currencyCode: String { settings.currencyCode }
    private var committedMinor: Int { commitments.filter(\.isActive).reduce(0) { $0 + $1.amountMinor } }

    private var summary: BudgetSummary {
        let now = Date.now
        let monthOutflow = expenses
            .filter { BudgetEngine.isInCurrentMonth($0.date, now: now, calendar: .current) && $0.direction.isOutflow }
            .reduce(0) { $0 + $1.amountMinor }
        return BudgetEngine.summary(
            incomeMinor: settings.monthlyIncomeMinor,
            committedMinor: committedMinor,
            monthOutflowMinor: monthOutflow,
            ceilingOverrideMinor: settings.monthlyCeilingMinor,
            now: now
        )
    }

    var body: some View {
        NavigationStack {
            List {
                incomeSection
                commitmentsSection
                expendableSection
                blockerSection
                allocationsSection
                projectionSection
            }
            .navigationTitle("Budget")
            .task {
                SeedData.ensureSettings(context)
                try? context.save()
            }
            .sheet(isPresented: $showIncomeEditor) {
                MoneyInputSheet(title: "Monthly Income", currencyCode: currencyCode,
                                minor: settings.monthlyIncomeMinor) { newValue in
                    settings.monthlyIncomeMinor = newValue
                    saveAndRefresh()
                }
            }
            .sheet(isPresented: $showCeilingEditor) {
                MoneyInputSheet(title: "Monthly Limit", currencyCode: currencyCode,
                                minor: settings.monthlyCeilingMinor ?? summary.expendableMinor) { newValue in
                    settings.monthlyCeilingMinor = newValue
                    saveAndRefresh()
                }
            }
            .sheet(isPresented: $showAddCommitment) {
                EditCommitmentView(commitment: nil, currencyCode: currencyCode)
            }
            .sheet(item: $editingCommitment) { commitment in
                EditCommitmentView(commitment: commitment, currencyCode: currencyCode)
            }
        }
    }

    // MARK: Sections

    private var incomeSection: some View {
        Section("Income") {
            Button { showIncomeEditor = true } label: {
                HStack {
                    Label("Monthly income", systemImage: "arrow.down.circle.fill")
                        .foregroundStyle(.primary)
                    Spacer()
                    Text(Money(minorUnits: settings.monthlyIncomeMinor, currencyCode: currencyCode).formatted())
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private var commitmentsSection: some View {
        Section {
            ForEach(commitments) { commitment in
                Button { editingCommitment = commitment } label: {
                    HStack(spacing: DS.Spacing.md) {
                        GlyphBadge(symbolName: commitment.symbolName, colorHex: commitment.colorHex, size: 32)
                        VStack(alignment: .leading, spacing: 1) {
                            Text(commitment.name).foregroundStyle(.primary)
                            if commitment.kind == .family {
                                Text("Family set-aside")
                                    .font(.caption2.weight(.semibold))
                                    .foregroundStyle(Color(hex: "FF375F"))
                            } else {
                                Text(commitment.kind.label)
                                    .font(.caption2).foregroundStyle(.secondary)
                            }
                        }
                        Spacer()
                        Text(Money(minorUnits: commitment.amountMinor, currencyCode: currencyCode).formattedCompact())
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .onDelete(perform: deleteCommitment)

            Button { showAddCommitment = true } label: {
                Label("Add set-aside", systemImage: "plus.circle.fill")
            }
        } header: {
            Text("Set-asides")
        } footer: {
            Text("Fixed monthly set-asides (family, rent, EMI, savings). Subtracted from income before any spending.")
        }
    }

    private var expendableSection: some View {
        Section("Expendable") {
            LabeledContent("Income",
                value: Money(minorUnits: settings.monthlyIncomeMinor, currencyCode: currencyCode).formatted())
            LabeledContent("Set aside",
                value: "− " + Money(minorUnits: committedMinor, currencyCode: currencyCode).formatted())
            LabeledContent {
                Text(Money(minorUnits: summary.expendableMinor, currencyCode: currencyCode).formatted())
                    .font(.headline)
            } label: {
                Text("Expendable income").font(.headline)
            }
        }
    }

    private var blockerSection: some View {
        Section {
            Toggle(isOn: Binding(
                get: { settings.enforceBlocker },
                set: { settings.enforceBlocker = $0; saveAndRefresh() }
            )) {
                Label("Block overspending", systemImage: "hand.raised.fill")
            }
            Button { showCeilingEditor = true } label: {
                HStack {
                    Text("Monthly limit").foregroundStyle(.primary)
                    Spacer()
                    Text(Money(minorUnits: summary.ceilingMinor, currencyCode: currencyCode).formatted())
                        .foregroundStyle(.secondary)
                    if settings.monthlyCeilingMinor == nil {
                        Text("(auto)").font(.caption2).foregroundStyle(.tertiary)
                    }
                }
            }
            if settings.monthlyCeilingMinor != nil {
                Button("Reset to expendable income", role: .destructive) {
                    settings.monthlyCeilingMinor = nil
                    saveAndRefresh()
                }
                .font(.subheadline)
            }
        } header: {
            Text("Spending blocker")
        } footer: {
            Text("When on, recording an expense beyond your limit needs a deliberate confirmation. iOS can't stop a real purchase — this is a guardrail.")
        }
    }

    @ViewBuilder
    private var allocationsSection: some View {
        let allocated = categories.filter { $0.allocationPercent != nil }
        if !allocated.isEmpty {
            Section {
                ForEach(allocated) { category in
                    let budget = BudgetEngine.themeBudgetMinor(
                        allocationPercent: category.allocationPercent,
                        expendableMinor: summary.expendableMinor
                    ) ?? 0
                    HStack(spacing: DS.Spacing.md) {
                        GlyphBadge(symbolName: category.symbolName, colorHex: category.colorHex, size: 30)
                        Text(category.name)
                        Spacer()
                        Text("\(Int(category.allocationPercent ?? 0))%")
                            .foregroundStyle(.secondary)
                        Text(Money(minorUnits: budget, currencyCode: currencyCode).formattedCompact())
                            .font(.subheadline.weight(.semibold))
                    }
                }
            } header: {
                Text("Theme allocations")
            } footer: {
                let totalPct = allocated.reduce(0.0) { $0 + ($1.allocationPercent ?? 0) }
                Text("Allocated \(Int(totalPct))% of expendable income. Edit allocations under Themes.")
            }
        }
    }

    private var projectionSection: some View {
        Section("This month") {
            LabeledContent("Spent",
                value: Money(minorUnits: summary.spentThisMonthMinor, currencyCode: currencyCode).formatted())
            LabeledContent("Safe to spend",
                value: Money(minorUnits: max(0, summary.safeToSpendMinor), currencyCode: currencyCode).formatted())
            LabeledContent {
                Text(Money(minorUnits: summary.projectedSpendMinor, currencyCode: currencyCode).formatted())
                    .foregroundStyle(summary.isPaceOver ? Color(hex: "FF375F") : .secondary)
            } label: {
                Text("Projected month-end")
            }
        }
    }

    // MARK: Actions

    private func deleteCommitment(_ offsets: IndexSet) {
        for index in offsets { context.delete(commitments[index]) }
        saveAndRefresh()
    }

    private func saveAndRefresh() {
        LedgerService(context: context).save()
    }
}
