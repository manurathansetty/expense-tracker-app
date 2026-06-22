import XCTest
@testable import Pi

final class RecurringEngineTests: XCTestCase {
    private func calendar() -> Calendar {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "Asia/Kolkata")!
        return cal
    }

    private func date(_ y: Int, _ m: Int, _ d: Int) -> Date {
        calendar().date(from: DateComponents(year: y, month: m, day: d, hour: 12))!
    }

    func testDaysUntil() {
        let cal = calendar()
        XCTAssertEqual(RecurringEngine.daysUntil(date(2026, 6, 18), now: date(2026, 6, 15), calendar: cal), 3)
        XCTAssertEqual(RecurringEngine.daysUntil(date(2026, 6, 15), now: date(2026, 6, 15), calendar: cal), 0)
        XCTAssertEqual(RecurringEngine.daysUntil(date(2026, 6, 14), now: date(2026, 6, 15), calendar: cal), -1)
    }

    func testIsDueSoon() {
        let cal = calendar()
        let now = date(2026, 6, 15)
        XCTAssertTrue(RecurringEngine.isDueSoon(date(2026, 6, 20), now: now, within: 5, calendar: cal))
        XCTAssertFalse(RecurringEngine.isDueSoon(date(2026, 6, 21), now: now, within: 5, calendar: cal))
        XCTAssertTrue(RecurringEngine.isDueSoon(date(2026, 6, 10), now: now, within: 5, calendar: cal)) // overdue
    }

    func testAdvanceMonthlyRollsPastReference() {
        let cal = calendar()
        let next = RecurringEngine.advance(date(2026, 6, 1), cadence: .monthly, from: date(2026, 6, 15), calendar: cal)
        XCTAssertEqual(cal.dateComponents([.year, .month, .day], from: next), DateComponents(year: 2026, month: 7, day: 1))
    }

    func testAdvanceRollsMultipleMissedPeriods() {
        let cal = calendar()
        let next = RecurringEngine.advance(date(2026, 1, 1), cadence: .monthly, from: date(2026, 6, 15), calendar: cal)
        XCTAssertEqual(cal.dateComponents([.year, .month, .day], from: next), DateComponents(year: 2026, month: 7, day: 1))
    }

    func testWeeklyCadence() {
        let cal = calendar()
        let next = RecurrenceCadence.weekly.nextDate(after: date(2026, 6, 1), calendar: cal)
        XCTAssertEqual(RecurringEngine.daysUntil(next, now: date(2026, 6, 1), calendar: cal), 7)
    }
}
