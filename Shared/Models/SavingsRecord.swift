import Foundation
import SwiftData

/// A finalized record of how much was left over (saved) in a past month —
/// expendable income minus what was actually spent. Snapshotted when a month
/// closes so later income changes don't rewrite history.
@Model
final class SavingsRecord {
    var id: UUID = UUID()
    var monthStart: Date = Date.now
    var year: Int = 0
    var month: Int = 0
    var expendableMinor: Int = 0
    var spentMinor: Int = 0
    var savedMinor: Int = 0
    var currencyCode: String = Money.defaultCurrencyCode
    var createdAt: Date = Date.now

    init(
        monthStart: Date,
        year: Int,
        month: Int,
        expendableMinor: Int,
        spentMinor: Int,
        savedMinor: Int,
        currencyCode: String = Money.defaultCurrencyCode
    ) {
        self.id = UUID()
        self.monthStart = monthStart
        self.year = year
        self.month = month
        self.expendableMinor = expendableMinor
        self.spentMinor = spentMinor
        self.savedMinor = savedMinor
        self.currencyCode = currencyCode
        self.createdAt = .now
    }

    var savedMoney: Money { Money(minorUnits: savedMinor, currencyCode: currencyCode) }

    var monthLabel: String {
        monthStart.formatted(.dateTime.month(.wide).year())
    }
}
