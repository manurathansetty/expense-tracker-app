import Foundation
import SwiftData

/// A group trip: a set of people sharing expenses, kept separate from the
/// personal ledger/budget. Deleting a trip cascades to its members & expenses.
@Model
final class Trip {
    var id: UUID = UUID()
    var name: String = ""
    var currencyCode: String = Money.defaultCurrencyCode
    var createdAt: Date = Date.now

    @Relationship(deleteRule: .cascade, inverse: \TripMember.trip)
    var members: [TripMember] = []

    @Relationship(deleteRule: .cascade, inverse: \TripExpense.trip)
    var expenses: [TripExpense] = []

    init(name: String, currencyCode: String = Money.defaultCurrencyCode) {
        self.id = UUID()
        self.name = name
        self.currencyCode = currencyCode
        self.createdAt = .now
    }

    var totalMinor: Int { expenses.reduce(0) { $0 + $1.amountMinor } }
    var sortedMembers: [TripMember] { members.sorted { $0.createdAt < $1.createdAt } }
}

/// A person on a trip.
@Model
final class TripMember {
    var id: UUID = UUID()
    var name: String = ""
    var colorHex: String = "30B0C7"
    var createdAt: Date = Date.now
    var trip: Trip?

    init(name: String, colorHex: String = "30B0C7") {
        self.id = UUID()
        self.name = name
        self.colorHex = colorHex
        self.createdAt = .now
    }
}

/// A shared expense on a trip. Members are referenced by id (payer / who shared)
/// to keep the SwiftData schema simple; the bill photo is stored externally.
@Model
final class TripExpense {
    var id: UUID = UUID()
    var title: String = ""
    var amountMinor: Int = 0
    var date: Date = Date.now
    var createdAt: Date = Date.now
    var payerID: UUID = UUID()
    var participantIDs: [UUID] = []

    @Attribute(.externalStorage) var photo: Data?

    var trip: Trip?

    init(
        title: String,
        amountMinor: Int,
        date: Date = .now,
        payerID: UUID,
        participantIDs: [UUID],
        photo: Data? = nil
    ) {
        self.id = UUID()
        self.title = title
        self.amountMinor = amountMinor
        self.date = date
        self.createdAt = .now
        self.payerID = payerID
        self.participantIDs = participantIDs
        self.photo = photo
    }
}
