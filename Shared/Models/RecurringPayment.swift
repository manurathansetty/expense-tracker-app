import Foundation
import SwiftData

/// An upcoming repeating payment — phone recharge, gym membership, rent, a
/// subscription. Tracks when it's next due so the app can surface it and notify.
@Model
final class RecurringPayment {
    var id: UUID = UUID()
    var name: String = ""
    var amountMinor: Int = 0
    var currencyCode: String = Money.defaultCurrencyCode
    var cadenceRaw: String = RecurrenceCadence.monthly.rawValue
    var nextDueDate: Date = Date.now
    var isActive: Bool = true
    var notify: Bool = true
    var createdAt: Date = Date.now
    var lastPaidDate: Date?

    @Relationship var category: Category?

    init(
        name: String,
        amountMinor: Int,
        currencyCode: String = Money.defaultCurrencyCode,
        cadence: RecurrenceCadence = .monthly,
        nextDueDate: Date,
        isActive: Bool = true,
        notify: Bool = true,
        category: Category? = nil
    ) {
        self.id = UUID()
        self.name = name
        self.amountMinor = amountMinor
        self.currencyCode = currencyCode
        self.cadenceRaw = cadence.rawValue
        self.nextDueDate = nextDueDate
        self.isActive = isActive
        self.notify = notify
        self.createdAt = .now
        self.category = category
    }

    var cadence: RecurrenceCadence {
        get { RecurrenceCadence(rawValue: cadenceRaw) ?? .monthly }
        set { cadenceRaw = newValue.rawValue }
    }

    var money: Money { Money(minorUnits: amountMinor, currencyCode: currencyCode) }

    /// Glyph/color fall back to a calendar icon when no theme is linked.
    var symbolName: String { category?.symbolName ?? "calendar" }
    var colorHex: String { category?.colorHex ?? "8E8E93" }
}
