import XCTest
@testable import SadhanaCore

final class DayKeyTests: XCTestCase {
    func testRoundTripAndWeekday() {
        let key = DayKey(raw: "2026-10-03")!
        XCTAssertEqual(key.raw, "2026-10-03")
        XCTAssertEqual(key.weekday, 7) // Saturday
        XCTAssertEqual(DayKey(raw: "2000-01-01")!.weekday, 7)
        XCTAssertEqual(DayKey(raw: "2026-10-05")!.weekday, 2) // Monday
    }

    func testArithmeticAcrossMonthsAndLeapYears() {
        XCTAssertEqual(DayKey(raw: "2024-02-28")!.adding(1).raw, "2024-02-29")
        XCTAssertEqual(DayKey(raw: "2024-02-29")!.adding(1).raw, "2024-03-01")
        XCTAssertEqual(DayKey(raw: "2026-12-31")!.adding(1).raw, "2027-01-01")
        XCTAssertEqual(DayKey(raw: "2026-03-01")!.adding(-1).raw, "2026-02-28")
    }

    func testRejectsInvalidDays() {
        XCTAssertNil(DayKey(raw: "2026-02-30"))
        XCTAssertNil(DayKey(raw: "2026-13-01"))
        XCTAssertNil(DayKey(raw: "26-1-1"))
    }

    func testWeekStartIsMonday() {
        XCTAssertEqual(DayKey(raw: "2026-10-03")!.weekStart.raw, "2026-09-28")
        XCTAssertEqual(DayKey(raw: "2026-10-04")!.weekStart.raw, "2026-09-28") // Sunday
        XCTAssertEqual(DayKey(raw: "2026-10-05")!.weekStart.raw, "2026-10-05")
    }

    func testTimeOfDayCodingAndOrder() throws {
        let data = try JSONEncoder().encode([TimeOfDay(6, 5)])
        XCTAssertEqual(String(data: data, encoding: .utf8), "[\"06:05\"]")
        let late = TimeOfDay(1, 0), dawn = TimeOfDay(4, 0)
        XCTAssertGreaterThan(late.dayOrder, dawn.dayOrder)
        XCTAssertEqual(TimeOfDay(23, 50).adding(minutes: 20), TimeOfDay(0, 10))
    }
}
