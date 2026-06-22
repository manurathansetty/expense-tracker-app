import XCTest
@testable import Tally

final class MoneyTests: XCTestCase {
    func testWholeNumberInputTreatedAsMajorUnits() {
        XCTAssertEqual(Money.minorUnits(fromUserInput: "1250"), 125000)
    }

    func testDecimalInput() {
        XCTAssertEqual(Money.minorUnits(fromUserInput: "12.50"), 1250)
        XCTAssertEqual(Money.minorUnits(fromUserInput: "1250.5"), 125050)
    }

    func testGroupedThousands() {
        XCTAssertEqual(Money.minorUnits(fromUserInput: "1,250.50"), 125050)
    }

    func testIndianGroupingNoDecimal() {
        XCTAssertEqual(Money.minorUnits(fromUserInput: "1,00,000"), 10000000)
    }

    func testCurrencySymbolsStripped() {
        XCTAssertEqual(Money.minorUnits(fromUserInput: "₹99"), 9900)
        XCTAssertEqual(Money.minorUnits(fromUserInput: "Rs. 250"), 25000)
    }

    func testEmptyAndGarbage() {
        XCTAssertNil(Money.minorUnits(fromUserInput: ""))
        XCTAssertNil(Money.minorUnits(fromUserInput: "abc"))
    }

    func testFormattingINR() {
        let money = Money(minorUnits: 125000, currencyCode: "INR")
        XCTAssertTrue(money.formatted().contains("1,250"))
    }

    func testCompactDropsFractionWhenWhole() {
        let whole = Money(minorUnits: 100000, currencyCode: "INR")
        XCTAssertFalse(whole.formattedCompact().contains(".00"))
        let frac = Money(minorUnits: 100050, currencyCode: "INR")
        XCTAssertTrue(frac.formattedCompact().contains(".50"))
    }
}
