import Foundation
import SwiftData

/// Shared read/write operations over the ledger. Used by the app UI, the Siri /
/// Shortcuts intents, and the share extension so every entry point behaves
/// identically (same blocker logic, same snapshot refresh).
@MainActor
struct LedgerService {
    let context: ModelContext
    var calendar: Calendar = .current

    // MARK: Settings

    func settings() -> BudgetSettings {
        if let existing = try? context.fetch(FetchDescriptor<BudgetSettings>()).first {
            return existing
        }
        let created = BudgetSettings()
        context.insert(created)
        return created
    }

    // MARK: Aggregates

    func activeCommittedMinor() -> Int {
        let commitments = (try? context.fetch(FetchDescriptor<Commitment>())) ?? []
        return commitments.filter(\.isActive).reduce(0) { $0 + $1.amountMinor }
    }

    func monthOutflowMinor(now: Date = .now) -> Int {
        outflow(in: monthRange(now: now))
    }

    func todayTotalMinor(now: Date = .now) -> Int {
        let start = calendar.startOfDay(for: now)
        let end = calendar.date(byAdding: .day, value: 1, to: start) ?? now
        return outflow(in: start..<end)
    }

    private func outflow(in range: Range<Date>) -> Int {
        let lower = range.lowerBound
        let upper = range.upperBound
        let predicate = #Predicate<Expense> { $0.date >= lower && $0.date < upper }
        let expenses = (try? context.fetch(FetchDescriptor<Expense>(predicate: predicate))) ?? []
        return expenses.filter { $0.direction.isOutflow }.reduce(0) { $0 + $1.amountMinor }
    }

    private func monthRange(now: Date) -> Range<Date> {
        let interval = BudgetEngine.monthInterval(now: now, calendar: calendar)
        return interval.start..<interval.end
    }

    // MARK: Summary

    func currentSummary(now: Date = .now) -> BudgetSummary {
        let s = settings()
        return BudgetEngine.summary(
            incomeMinor: s.monthlyIncomeMinor,
            committedMinor: activeCommittedMinor(),
            monthOutflowMinor: monthOutflowMinor(now: now),
            ceilingOverrideMinor: s.monthlyCeilingMinor,
            now: now,
            calendar: calendar
        )
    }

    /// Whether adding an outflow of `amountMinor` now would push month spend past
    /// the ceiling. Inflows never breach.
    func wouldBreachCeiling(addingMinor amountMinor: Int, direction: Direction, now: Date = .now) -> Bool {
        guard direction.isOutflow else { return false }
        let summary = currentSummary(now: now)
        return summary.spentThisMonthMinor + amountMinor > summary.ceilingMinor
    }

    // MARK: Mutations

    @discardableResult
    func insert(_ expense: Expense, now: Date = .now) -> Expense {
        context.insert(expense)
        try? context.save()
        refreshSnapshot(now: now)
        return expense
    }

    func delete(_ expense: Expense, now: Date = .now) {
        context.delete(expense)
        try? context.save()
        refreshSnapshot(now: now)
    }

    func save(now: Date = .now) {
        try? context.save()
        refreshSnapshot(now: now)
    }

    // MARK: Widget snapshot

    func refreshSnapshot(now: Date = .now) {
        let s = settings()
        let summary = currentSummary(now: now)
        let snapshot = SharedSnapshot(
            todayTotalMinor: todayTotalMinor(now: now),
            spentThisMonthMinor: summary.spentThisMonthMinor,
            safeToSpendMinor: summary.safeToSpendMinor,
            dailyAllowanceMinor: summary.dailyAllowanceMinor,
            ceilingMinor: summary.ceilingMinor,
            currencyCode: s.currencyCode,
            updatedAt: now
        )
        SnapshotStore.write(snapshot)
    }
}
