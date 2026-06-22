import Foundation
import SwiftData

/// Development-only sample data, seeded once when the app is launched with the
/// `TALLY_DEMO=1` environment variable. Never runs in normal use.
enum DemoData {
    @MainActor
    static func seedIfRequested(_ context: ModelContext) {
        guard ProcessInfo.processInfo.environment["TALLY_DEMO"] == "1" else { return }

        // Only seed once.
        let existing = (try? context.fetchCount(FetchDescriptor<Expense>())) ?? 0
        guard existing == 0 else { return }

        SeedData.seedIfNeeded(context)
        let categories = (try? context.fetch(FetchDescriptor<Category>())) ?? []
        func category(_ name: String) -> Category? { categories.first { $0.name == name } }

        // Budget settings + commitments.
        let settings = (try? context.fetch(FetchDescriptor<BudgetSettings>()).first) ?? BudgetSettings()
        settings.monthlyIncomeMinor = 8_000_000   // ₹80,000
        settings.currencyCode = "INR"
        if (try? context.fetchCount(FetchDescriptor<BudgetSettings>())) == 0 {
            context.insert(settings)
        }

        let commitments = [
            Commitment(name: "Family support", amountMinor: 1_500_000, kind: .family, colorHex: "FF375F"),
            Commitment(name: "Rent", amountMinor: 2_000_000, kind: .housing, colorHex: "BF5AF2"),
            Commitment(name: "SIP", amountMinor: 1_000_000, kind: .savings, colorHex: "34C759"),
        ]
        commitments.forEach(context.insert)

        // People.
        let arjun = Payee(name: "Arjun", colorHex: "0A84FF")
        let priya = Payee(name: "Priya", colorHex: "FF2D55")
        context.insert(arjun)
        context.insert(priya)

        // A spread of recent expenses.
        let now = Date.now
        func daysAgo(_ d: Int, _ h: Int) -> Date {
            Calendar.current.date(byAdding: .day, value: -d, to: now)
                .flatMap { Calendar.current.date(bySettingHour: h, minute: 15, second: 0, of: $0) } ?? now
        }

        let samples: [(Int, Int, Int, String, String, Direction, Payee?)] = [
            (0, 9, 24000, "Cappuccino", "Food & Drink", .paid, nil),
            (0, 13, 38000, "Lunch with team", "Food & Drink", .paid, nil),
            (0, 19, 150000, "Groceries", "Groceries", .paid, nil),
            (1, 8, 6000, "Auto to office", "Transport", .paid, nil),
            (1, 21, 90000, "Movie night", "Fun", .paid, nil),
            (2, 12, 200000, "Lent for trip", "Travel", .lent, arjun),
            (2, 18, 45000, "Phone bill", "Bills", .paid, nil),
            (3, 11, 120000, "New shirt", "Shopping", .paid, nil),
            (4, 20, 50000, "Returned share", "Food & Drink", .owedToMe, priya),
            (5, 10, 30000, "Pharmacy", "Health", .paid, nil),
        ]

        for (d, h, amount, note, cat, dir, payee) in samples {
            let expense = Expense(
                amountMinor: amount,
                currencyCode: "INR",
                note: note,
                date: daysAgo(d, h),
                direction: dir,
                source: .manual,
                category: category(cat),
                payee: payee
            )
            context.insert(expense)
        }

        // Recurring payments — one overdue, one due soon, one later.
        let recurrings: [(String, Int, RecurrenceCadence, Int, String)] = [
            ("Phone recharge", 39900, .monthly, -1, "Bills"),
            ("Netflix", 64900, .monthly, 3, "Fun"),
            ("Gym membership", 150000, .monthly, 18, "Health"),
        ]
        for (name, amount, cadence, dueInDays, cat) in recurrings {
            let due = Calendar.current.date(byAdding: .day, value: dueInDays, to: now) ?? now
            let payment = RecurringPayment(
                name: name, amountMinor: amount, currencyCode: "INR",
                cadence: cadence, nextDueDate: due, category: category(cat)
            )
            context.insert(payment)
        }

        try? context.save()
    }
}
