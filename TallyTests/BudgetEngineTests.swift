import XCTest
@testable import Tally

final class BudgetEngineTests: XCTestCase {
    private func fixedCalendar() -> Calendar {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "Asia/Kolkata")!
        return cal
    }

    private func date(_ y: Int, _ m: Int, _ d: Int) -> Date {
        let cal = fixedCalendar()
        return cal.date(from: DateComponents(year: y, month: m, day: d, hour: 12))!
    }

    func testExpendableAndCeilingDefault() {
        let summary = BudgetEngine.summary(
            incomeMinor: 10_000_000,
            committedMinor: 3_000_000,
            monthOutflowMinor: 1_000_000,
            ceilingOverrideMinor: nil,
            now: date(2026, 6, 15),
            calendar: fixedCalendar()
        )
        XCTAssertEqual(summary.expendableMinor, 7_000_000)
        XCTAssertEqual(summary.ceilingMinor, 7_000_000)
        XCTAssertEqual(summary.safeToSpendMinor, 6_000_000)
    }

    func testDaysAndDailyAllowanceMidJune() {
        let summary = BudgetEngine.summary(
            incomeMinor: 10_000_000,
            committedMinor: 3_000_000,
            monthOutflowMinor: 1_000_000,
            ceilingOverrideMinor: nil,
            now: date(2026, 6, 15),
            calendar: fixedCalendar()
        )
        // June has 30 days; on the 15th, 16 days remain (incl. today).
        XCTAssertEqual(summary.daysRemaining, 16)
        XCTAssertEqual(summary.dailyAllowanceMinor, 6_000_000 / 16)
    }

    func testProjectionScalesWithPace() {
        let summary = BudgetEngine.summary(
            incomeMinor: 10_000_000,
            committedMinor: 0,
            monthOutflowMinor: 1_000_000,
            ceilingOverrideMinor: nil,
            now: date(2026, 6, 15),
            calendar: fixedCalendar()
        )
        // 1,000,000 over 15 days → 2,000,000 over 30 days.
        XCTAssertEqual(summary.projectedSpendMinor, 2_000_000)
    }

    func testCeilingOverrideUsed() {
        let summary = BudgetEngine.summary(
            incomeMinor: 10_000_000,
            committedMinor: 0,
            monthOutflowMinor: 0,
            ceilingOverrideMinor: 500_000,
            now: date(2026, 6, 15),
            calendar: fixedCalendar()
        )
        XCTAssertEqual(summary.ceilingMinor, 500_000)
    }

    func testOverCeilingFlag() {
        let summary = BudgetEngine.summary(
            incomeMinor: 1_000_000,
            committedMinor: 0,
            monthOutflowMinor: 1_500_000,
            ceilingOverrideMinor: nil,
            now: date(2026, 6, 15),
            calendar: fixedCalendar()
        )
        XCTAssertTrue(summary.isOverCeiling)
        XCTAssertLessThan(summary.safeToSpendMinor, 0)
    }

    func testThemeHelpers() {
        XCTAssertEqual(BudgetEngine.themeFraction(themeOutflowMinor: 1_000_000, expendableMinor: 5_000_000), 0.2)
        XCTAssertEqual(BudgetEngine.themeBudgetMinor(allocationPercent: 20, expendableMinor: 5_000_000), 1_000_000)
        XCTAssertNil(BudgetEngine.themeBudgetMinor(allocationPercent: nil, expendableMinor: 5_000_000))
    }
}
