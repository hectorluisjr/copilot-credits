import XCTest
@testable import CopilotCreditsMenuBar

final class BillingPeriodTests: XCTestCase {
    private func cal() -> Calendar {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "America/New_York")!
        return c
    }
    private func date(_ s: String, _ c: Calendar) -> Date {
        let f = DateFormatter(); f.dateFormat = "yyyy-MM-dd"; f.timeZone = c.timeZone
        return f.date(from: s)!
    }
    private func ymd(_ d: Date, _ c: Calendar) -> String {
        let f = DateFormatter(); f.dateFormat = "yyyy-MM-dd"; f.timeZone = c.timeZone
        return f.string(from: d)
    }

    func testCurrentPeriodCases() {
        let c = cal()
        let cases: [(now: String, day: Int, start: String, reset: String)] = [
            ("2026-06-02", 1, "2026-06-01", "2026-07-01"),   // calendar month (the real config)
            ("2026-06-02", 30, "2026-05-30", "2026-06-30"),
            ("2026-06-30", 30, "2026-06-30", "2026-07-30"),  // on reset day -> new period
            ("2026-02-15", 31, "2026-01-31", "2026-02-28"),  // Feb clamp
            ("2026-03-01", 31, "2026-02-28", "2026-03-31"),  // out of short month
            ("2026-01-15", 30, "2025-12-30", "2026-01-30"),  // year rollover
        ]
        for k in cases {
            let p = BillingPeriodCalculator.current(resetDay: k.day, now: date(k.now, c), calendar: c)
            XCTAssertEqual(ymd(p.start, c), k.start, "start for now=\(k.now) day=\(k.day)")
            XCTAssertEqual(ymd(p.reset, c), k.reset, "reset for now=\(k.now) day=\(k.day)")
        }
    }

    func testDaysUntil() {
        let c = cal()
        XCTAssertEqual(BillingPeriodCalculator.daysUntil(date("2026-07-01", c), from: date("2026-06-02", c), calendar: c), 29)
        // past date clamps to 0
        XCTAssertEqual(BillingPeriodCalculator.daysUntil(date("2026-06-02", c), from: date("2026-06-30", c), calendar: c), 0)
    }

    func testMonthlyResetDayIsFirst() {
        XCTAssertEqual(BillingPeriodCalculator.monthlyResetDay, 1)
    }
}
