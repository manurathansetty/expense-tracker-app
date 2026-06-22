import XCTest
@testable import Tally

final class TransactionParserTests: XCTestCase {
    func testUPIDebitWithVPA() {
        let p = TransactionParser.parse(
            "Rs.500.00 debited from a/c XX1234 on 12-06-24 to VPA merchant@upi. Ref 123."
        )
        XCTAssertEqual(p.amountMinor, 50000)
        XCTAssertEqual(p.currencyCode, "INR")
        XCTAssertEqual(p.direction, .paid)
        XCTAssertEqual(p.merchant, "merchant@upi")
    }

    func testCardSpendAtMerchant() {
        let p = TransactionParser.parse(
            "INR 1,250.50 spent on your HDFC Bank Card at AMAZON on 2024-06-12."
        )
        XCTAssertEqual(p.amountMinor, 125050)
        XCTAssertEqual(p.direction, .paid)
        XCTAssertEqual(p.merchant, "AMAZON")
    }

    func testCreditIsInflow() {
        let p = TransactionParser.parse("Rs 300 credited to your account.")
        XCTAssertEqual(p.amountMinor, 30000)
        XCTAssertEqual(p.direction, .owedToMe)
    }

    func testSentToMerchant() {
        let p = TransactionParser.parse("₹99 sent to Swiggy via UPI")
        XCTAssertEqual(p.amountMinor, 9900)
        XCTAssertEqual(p.direction, .paid)
        XCTAssertEqual(p.merchant, "Swiggy")
    }

    func testPaidToMerchant() {
        let p = TransactionParser.parse("Paid Rs.150 to Zomato")
        XCTAssertEqual(p.amountMinor, 15000)
        XCTAssertEqual(p.direction, .paid)
        XCTAssertEqual(p.merchant, "Zomato")
    }

    func testNoAmount() {
        let p = TransactionParser.parse("Your OTP is 1234. Do not share it.")
        XCTAssertFalse(p.hasAmount)
    }

    func testDebitTakesPrecedenceOverCredit() {
        let p = TransactionParser.parse(
            "Rs 2000 debited from a/c X and credited to John."
        )
        XCTAssertEqual(p.amountMinor, 200000)
        XCTAssertEqual(p.direction, .paid)
    }
}
