import XCTest
@testable import Pi

final class TripEngineTests: XCTestCase {
    private let a = UUID()
    private let b = UUID()
    private let c = UUID()

    func testEqualSplitAmongAll() {
        // A pays ₹300 shared by A, B, C → each owes 100; A net +200.
        let net = TripEngine.netBalances(
            memberIDs: [a, b, c],
            charges: [.init(amountMinor: 30000, payerID: a, participantIDs: [a, b, c])]
        )
        XCTAssertEqual(net[a], 20000)
        XCTAssertEqual(net[b], -10000)
        XCTAssertEqual(net[c], -10000)
    }

    func testSubsetSplit() {
        // B pays ₹100 shared by B and C only → C owes 50, B net +50, A unaffected.
        let net = TripEngine.netBalances(
            memberIDs: [a, b, c],
            charges: [.init(amountMinor: 10000, payerID: b, participantIDs: [b, c])]
        )
        XCTAssertEqual(net[a], 0)
        XCTAssertEqual(net[b], 5000)
        XCTAssertEqual(net[c], -5000)
    }

    func testRemainderDistribution() {
        // ₹100 split 3 ways = 33.34 + 33.33 + 33.33 (remainder to the first).
        let net = TripEngine.netBalances(
            memberIDs: [a, b, c],
            charges: [.init(amountMinor: 10000, payerID: a, participantIDs: [a, b, c])]
        )
        // Shares sum back to the full amount.
        let totalOwed = [a, b, c].reduce(0) { $0 + (($1 == a ? 10000 : 0) - (net[$1] ?? 0)) }
        XCTAssertEqual(totalOwed, 10000)
        XCTAssertEqual(net.values.reduce(0, +), 0) // balances always net to zero
    }

    func testSettlementsClearAllDebts() {
        let net = TripEngine.netBalances(
            memberIDs: [a, b, c],
            charges: [.init(amountMinor: 30000, payerID: a, participantIDs: [a, b, c])]
        )
        let settlements = TripEngine.settlements(net: net)
        // Apply settlements; everyone should end at zero.
        var balances = net
        for s in settlements {
            balances[s.fromID, default: 0] += s.amountMinor
            balances[s.toID, default: 0] -= s.amountMinor
        }
        XCTAssertTrue(balances.values.allSatisfy { $0 == 0 })
        XCTAssertEqual(settlements.count, 2) // B→A and C→A
    }

    func testAllSettledProducesNoTransfers() {
        XCTAssertTrue(TripEngine.settlements(net: [a: 0, b: 0, c: 0]).isEmpty)
    }
}
