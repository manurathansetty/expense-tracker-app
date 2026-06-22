import Foundation

/// Pure date arithmetic for recurring payments. No I/O — unit-testable.
enum RecurringEngine {
    /// Whole days from the start of `now`'s day to the start of `due`'s day.
    /// Negative when overdue, 0 when due today.
    static func daysUntil(_ due: Date, now: Date, calendar: Calendar = .current) -> Int {
        let start = calendar.startOfDay(for: now)
        let dueStart = calendar.startOfDay(for: due)
        return calendar.dateComponents([.day], from: start, to: dueStart).day ?? 0
    }

    /// Whether a due date is within `days` of now (includes overdue).
    static func isDueSoon(_ due: Date, now: Date, within days: Int = 5, calendar: Calendar = .current) -> Bool {
        daysUntil(due, now: now, calendar: calendar) <= days
    }

    /// Roll a due date forward by its cadence until it lands strictly after
    /// `reference` — used after a payment is marked paid or when it's overdue.
    static func advance(
        _ due: Date,
        cadence: RecurrenceCadence,
        from reference: Date,
        calendar: Calendar = .current
    ) -> Date {
        var next = cadence.nextDate(after: due, calendar: calendar)
        var guardCount = 0
        while next <= reference && guardCount < 1000 {
            next = cadence.nextDate(after: next, calendar: calendar)
            guardCount += 1
        }
        return next
    }

    /// A short human label for how far away a due date is.
    static func dueLabel(_ due: Date, now: Date, calendar: Calendar = .current) -> String {
        let days = daysUntil(due, now: now, calendar: calendar)
        switch days {
        case ..<0: return days == -1 ? "Overdue by 1 day" : "Overdue by \(-days) days"
        case 0: return "Due today"
        case 1: return "Due tomorrow"
        default: return "Due in \(days) days"
        }
    }
}
