import XCTest
@testable import SadhanaCore

final class DayKeyTests: XCTestCase {
    func testRaw() {
        XCTAssertEqual(DayKey(raw: "2026-10-03").raw, "2026-10-03")
    }
}
