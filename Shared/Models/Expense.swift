import Foundation
import SwiftData

/// A single ledger entry. Money is stored as integer minor units in
/// `amountMinor`; never as a floating-point value.
@Model
final class Expense {
    var id: UUID = UUID()
    var amountMinor: Int = 0
    var currencyCode: String = Money.defaultCurrencyCode
    var note: String = ""

    /// When the money actually moved (editable by the user).
    var date: Date = Date.now
    /// Immutable audit stamp of when the row was created.
    var createdAt: Date = Date.now
    /// Identifier of the time zone the entry was made in, e.g. "Asia/Kolkata".
    var timeZoneId: String = TimeZone.current.identifier

    var directionRaw: String = Direction.paid.rawValue
    var sourceRaw: String = EntrySource.manual.rawValue

    /// Original message text when captured from a bank/UPI alert.
    var rawMessage: String?
    /// Set when the user knowingly recorded an expense over their budget ceiling.
    var didOverrideBlocker: Bool = false

    @Relationship var category: Category?
    @Relationship var payee: Payee?

    init(
        amountMinor: Int,
        currencyCode: String = Money.defaultCurrencyCode,
        note: String = "",
        date: Date = .now,
        direction: Direction = .paid,
        source: EntrySource = .manual,
        category: Category? = nil,
        payee: Payee? = nil,
        rawMessage: String? = nil,
        didOverrideBlocker: Bool = false
    ) {
        self.id = UUID()
        self.amountMinor = amountMinor
        self.currencyCode = currencyCode
        self.note = note
        self.date = date
        self.createdAt = .now
        self.timeZoneId = TimeZone.current.identifier
        self.directionRaw = direction.rawValue
        self.sourceRaw = source.rawValue
        self.category = category
        self.payee = payee
        self.rawMessage = rawMessage
        self.didOverrideBlocker = didOverrideBlocker
    }

    // MARK: Convenience

    var direction: Direction {
        get { Direction(rawValue: directionRaw) ?? .paid }
        set { directionRaw = newValue.rawValue }
    }

    var source: EntrySource {
        get { EntrySource(rawValue: sourceRaw) ?? .manual }
        set { sourceRaw = newValue.rawValue }
    }

    var money: Money {
        Money(minorUnits: amountMinor, currencyCode: currencyCode)
    }
}
