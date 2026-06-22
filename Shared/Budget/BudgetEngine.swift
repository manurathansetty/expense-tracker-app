import Foundation

/// A snapshot of the user's monthly budget position. All amounts are in minor
/// units of the configured currency.
struct BudgetSummary: Equatable, Sendable {
    var incomeMinor: Int
    var committedMinor: Int
    var expendableMinor: Int
    var ceilingMinor: Int
    var spentThisMonthMinor: Int
    var safeToSpendMinor: Int
    var dailyAllowanceMinor: Int
    var daysRemaining: Int
    var projectedSpendMinor: Int
    /// Last month's overspend carried into this month ("lag payment"), already
    /// subtracted from `ceilingMinor`.
    var carryoverDeficitMinor: Int = 0

    /// Fraction of the ceiling already spent (0…1+, can exceed 1 when over).
    var fractionUsed: Double {
        guard ceilingMinor > 0 else { return 0 }
        return Double(spentThisMonthMinor) / Double(ceilingMinor)
    }

    var isOverCeiling: Bool { spentThisMonthMinor > ceilingMinor }

    /// Projected spend exceeds the ceiling at the current pace.
    var isPaceOver: Bool { projectedSpendMinor > ceilingMinor }
}

/// Pure budget arithmetic. No I/O, no SwiftData — fully unit-testable. Callers
/// pre-aggregate amounts from the model layer and pass plain integers in.
enum BudgetEngine {
    /// The calendar-month interval containing `now`.
    static func monthInterval(now: Date, calendar: Calendar) -> DateInterval {
        calendar.dateInterval(of: .month, for: now)
            ?? DateInterval(start: now, duration: 0)
    }

    /// Whether `date` falls within the budget month containing `now`.
    static func isInCurrentMonth(_ date: Date, now: Date, calendar: Calendar) -> Bool {
        calendar.isDate(date, equalTo: now, toGranularity: .month)
    }

    /// The calendar-month interval immediately before the one containing `now`.
    static func previousMonthInterval(now: Date, calendar: Calendar) -> DateInterval {
        let thisStart = monthInterval(now: now, calendar: calendar).start
        let inPrev = calendar.date(byAdding: .day, value: -1, to: thisStart) ?? thisStart
        return monthInterval(now: inPrev, calendar: calendar)
    }

    /// Last month's overspend (outflow beyond expendable income), or 0 when
    /// carry-over is disabled or last month was within budget.
    static func carryoverDeficit(prevMonthOutflowMinor: Int, expendableMinor: Int, enabled: Bool) -> Int {
        guard enabled else { return 0 }
        return max(0, prevMonthOutflowMinor - expendableMinor)
    }

    static func summary(
        incomeMinor: Int,
        committedMinor: Int,
        monthOutflowMinor: Int,
        ceilingOverrideMinor: Int?,
        now: Date,
        calendar: Calendar = .current,
        carryoverDeficitMinor: Int = 0
    ) -> BudgetSummary {
        let expendable = max(0, incomeMinor - committedMinor)
        let baseCeiling = ceilingOverrideMinor ?? expendable
        let ceiling = max(0, baseCeiling - carryoverDeficitMinor)
        let safeToSpend = ceiling - monthOutflowMinor

        let daysInMonth = calendar.range(of: .day, in: .month, for: now)?.count ?? 30
        let dayOfMonth = calendar.component(.day, from: now)
        let daysElapsed = max(1, dayOfMonth)
        let daysRemaining = max(1, daysInMonth - dayOfMonth + 1)

        let dailyAllowance = safeToSpend > 0 ? safeToSpend / daysRemaining : 0
        let projected = Int(
            (Double(monthOutflowMinor) / Double(daysElapsed) * Double(daysInMonth)).rounded()
        )

        return BudgetSummary(
            incomeMinor: incomeMinor,
            committedMinor: committedMinor,
            expendableMinor: expendable,
            ceilingMinor: ceiling,
            spentThisMonthMinor: monthOutflowMinor,
            safeToSpendMinor: safeToSpend,
            dailyAllowanceMinor: dailyAllowance,
            daysRemaining: daysRemaining,
            projectedSpendMinor: projected,
            carryoverDeficitMinor: carryoverDeficitMinor
        )
    }

    /// A theme's spend expressed as a fraction of expendable income (0…1+).
    static func themeFraction(themeOutflowMinor: Int, expendableMinor: Int) -> Double {
        guard expendableMinor > 0 else { return 0 }
        return Double(themeOutflowMinor) / Double(expendableMinor)
    }

    /// The budgeted amount for a theme given its allocation percentage.
    static func themeBudgetMinor(allocationPercent: Double?, expendableMinor: Int) -> Int? {
        guard let pct = allocationPercent else { return nil }
        return Int((Double(expendableMinor) * pct / 100).rounded())
    }
}
