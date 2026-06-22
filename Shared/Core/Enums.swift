import Foundation

/// Which way the money moved relative to the user.
enum Direction: String, Codable, CaseIterable, Identifiable, Sendable {
    case paid       // I spent money (an ordinary expense)
    case lent       // I gave money to a person, expecting it back
    case owedToMe   // Money came back / is owed to me

    var id: String { rawValue }

    var label: String {
        switch self {
        case .paid: return "Spent"
        case .lent: return "Lent"
        case .owedToMe: return "Received"
        }
    }

    var symbolName: String {
        switch self {
        case .paid: return "arrow.up.right"
        case .lent: return "arrow.up.forward.circle"
        case .owedToMe: return "arrow.down.left.circle"
        }
    }

    /// Whether this entry reduces money available to spend this month.
    var isOutflow: Bool {
        switch self {
        case .paid, .lent: return true
        case .owedToMe: return false
        }
    }
}

/// How an entry got into the ledger — useful for trust and filtering.
enum EntrySource: String, Codable, CaseIterable, Sendable {
    case manual
    case quickAdd
    case message      // parsed from a bank/UPI text via the Shortcuts automation
    case shareSheet   // shared into the app from another app

    var label: String {
        switch self {
        case .manual: return "Manual"
        case .quickAdd: return "Quick add"
        case .message: return "From message"
        case .shareSheet: return "Shared"
        }
    }
}

/// Categories of fixed monthly commitments that are subtracted from income.
enum CommitmentKind: String, Codable, CaseIterable, Identifiable, Sendable {
    case family
    case housing
    case loan
    case savings
    case other

    var id: String { rawValue }

    var label: String {
        switch self {
        case .family: return "Family"
        case .housing: return "Housing"
        case .loan: return "Loan / EMI"
        case .savings: return "Savings"
        case .other: return "Other"
        }
    }

    var symbolName: String {
        switch self {
        case .family: return "house.and.flag.fill"
        case .housing: return "house.fill"
        case .loan: return "creditcard.fill"
        case .savings: return "banknote.fill"
        case .other: return "lock.fill"
        }
    }
}
