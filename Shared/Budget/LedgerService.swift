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
        commit(now: now)
        return expense
    }

    func delete(_ expense: Expense, now: Date = .now) {
        context.delete(expense)
        commit(now: now)
    }

    func save(now: Date = .now) {
        commit(now: now)
    }

    /// Persist, refresh the widget snapshot, and bump the cross-process change
    /// counter so other processes (and the foregrounding app) know to refresh.
    private func commit(now: Date) {
        try? context.save()
        refreshSnapshot(now: now)
        ExternalChange.bump()
    }

    // MARK: Recurring payments

    /// Active recurring payments due within `days` (includes overdue), soonest first.
    func upcomingDues(within days: Int = 5, now: Date = .now) -> [RecurringPayment] {
        let all = (try? context.fetch(FetchDescriptor<RecurringPayment>())) ?? []
        return all
            .filter { $0.isActive && RecurringEngine.isDueSoon($0.nextDueDate, now: now, within: days, calendar: calendar) }
            .sorted { $0.nextDueDate < $1.nextDueDate }
    }

    /// Record a payment for a recurring item, roll its due date forward, and
    /// reschedule notifications.
    func markRecurringPaid(_ payment: RecurringPayment, now: Date = .now) {
        let expense = Expense(
            amountMinor: payment.amountMinor,
            currencyCode: payment.currencyCode,
            note: payment.name,
            date: now,
            direction: .paid,
            source: .manual,
            category: payment.category
        )
        context.insert(expense)
        payment.lastPaidDate = now
        payment.nextDueDate = RecurringEngine.advance(
            payment.nextDueDate, cadence: payment.cadence, from: now, calendar: calendar
        )
        commit(now: now)
        rescheduleNotifications(now: now)
    }

    /// Rebuild all pending local notifications from the current recurring set.
    func rescheduleNotifications(now: Date = .now) {
        let all = (try? context.fetch(FetchDescriptor<RecurringPayment>())) ?? []
        NotificationScheduler.reschedule(all, now: now)
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
