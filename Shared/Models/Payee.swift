import Foundation
import SwiftData

/// A person you give money to or get money from. Used by the "I gave X to
/// someone" quick action and for informal lending balances.
@Model
final class Payee {
    var id: UUID = UUID()
    var name: String = ""
    var note: String = ""
    var colorHex: String = "30B0C7"
    var createdAt: Date = Date.now

    @Relationship(deleteRule: .nullify, inverse: \Expense.payee)
    var expenses: [Expense] = []

    init(name: String, note: String = "", colorHex: String = "30B0C7") {
        self.id = UUID()
        self.name = name
        self.note = note
        self.colorHex = colorHex
        self.createdAt = .now
    }

    /// Net balance with this person in minor units, looking only at lending
    /// entries. Positive ⇒ they owe you; negative ⇒ you owe them.
    var netBalanceMinor: Int {
        expenses.reduce(0) { running, expense in
            switch expense.direction {
            case .lent: return running + expense.amountMinor
            case .owedToMe: return running - expense.amountMinor
            case .paid: return running
            }
        }
    }
}
