import Foundation

/// Pure math for trip cost-splitting and settle-up. No I/O — unit-testable.
/// All amounts are integer minor units.
enum TripEngine {
    /// One expense reduced to what the engine needs.
    struct Charge {
        let amountMinor: Int
        let payerID: UUID
        let participantIDs: [UUID]
    }

    /// Net position per member: what they paid minus their share of everything.
    /// Positive ⇒ they're owed money; negative ⇒ they owe.
    static func netBalances(memberIDs: [UUID], charges: [Charge]) -> [UUID: Int] {
        var paid: [UUID: Int] = [:]
        var owed: [UUID: Int] = [:]

        for charge in charges {
            paid[charge.payerID, default: 0] += charge.amountMinor
            let participants = charge.participantIDs
            guard !participants.isEmpty else { continue }
            // Split equally; distribute the rounding remainder across the first
            // participants so shares always sum back to the exact amount.
            let base = charge.amountMinor / participants.count
            let remainder = charge.amountMinor - base * participants.count
            for (index, id) in participants.enumerated() {
                owed[id, default: 0] += base + (index < remainder ? 1 : 0)
            }
        }

        var net: [UUID: Int] = [:]
        for id in memberIDs {
            net[id] = (paid[id] ?? 0) - (owed[id] ?? 0)
        }
        return net
    }

    /// Who pays whom to settle up, minimizing the number of transfers (greedy:
    /// largest debtor pays largest creditor).
    struct Settlement: Equatable {
        let fromID: UUID
        let toID: UUID
        let amountMinor: Int
    }

    static func settlements(net: [UUID: Int]) -> [Settlement] {
        var debtors = net.filter { $0.value < 0 }
            .map { (id: $0.key, amount: -$0.value) }
            .sorted { $0.amount > $1.amount }
        var creditors = net.filter { $0.value > 0 }
            .map { (id: $0.key, amount: $0.value) }
            .sorted { $0.amount > $1.amount }

        var result: [Settlement] = []
        var i = 0
        var j = 0
        while i < debtors.count && j < creditors.count {
            let pay = min(debtors[i].amount, creditors[j].amount)
            if pay > 0 {
                result.append(Settlement(fromID: debtors[i].id, toID: creditors[j].id, amountMinor: pay))
            }
            debtors[i].amount -= pay
            creditors[j].amount -= pay
            if debtors[i].amount == 0 { i += 1 }
            if creditors[j].amount == 0 { j += 1 }
        }
        return result
    }
}
