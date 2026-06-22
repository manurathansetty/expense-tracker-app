import Foundation
import SwiftData

/// Single-row configuration for the budgeting layer. Created on first launch and
/// thereafter edited in place.
@Model
final class BudgetSettings {
    var id: UUID = UUID()
    var monthlyIncomeMinor: Int = 0
    var currencyCode: String = Money.defaultCurrencyCode

    /// Explicit overall monthly spend cap. When `nil`, the ceiling defaults to
    /// expendable income (income − commitments).
    var monthlyCeilingMinor: Int?

    /// When true, recording an expense that breaches the ceiling requires an
    /// explicit "Spend anyway" confirmation.
    var enforceBlocker: Bool = true

    /// Day the budget month starts on. v1 keeps this at 1 (calendar month).
    var monthStartDay: Int = 1

    /// When true, last month's overspend is carried into this month (a "lag
    /// payment") and subtracted from what's available.
    var carryOverOverspend: Bool = true

    init(
        monthlyIncomeMinor: Int = 0,
        currencyCode: String = Money.defaultCurrencyCode,
        monthlyCeilingMinor: Int? = nil,
        enforceBlocker: Bool = true,
        monthStartDay: Int = 1,
        carryOverOverspend: Bool = true
    ) {
        self.id = UUID()
        self.monthlyIncomeMinor = monthlyIncomeMinor
        self.currencyCode = currencyCode
        self.monthlyCeilingMinor = monthlyCeilingMinor
        self.enforceBlocker = enforceBlocker
        self.monthStartDay = monthStartDay
        self.carryOverOverspend = carryOverOverspend
    }
}
