import XCTest
@testable import CopilotCreditsMenuBar

final class AggregationStoreTests: XCTestCase {
    private func ev(_ ts: Double, _ model: String, _ nano: Double, sid: String? = nil) -> UsageEvent {
        UsageEvent(
            timestamp: Date(timeIntervalSince1970: ts),
            sessionId: sid,
            responseId: nil,
            model: model,
            nanoAiu: nano
        )
    }

    func testPeriodScopingTotalsAndPerModel() {
        let periodStart = Date(timeIntervalSince1970: 1000)
        let events = [
            ev(500, "a", 1_000_000_000, sid: "s1"),    // before period
            ev(1500, "a", 2_000_000_000, sid: "s1"),   // in period: 2
            ev(2000, "b", 3_000_000_000, sid: "s2"),   // in period: 3
        ]
        let r = AggregationStore().aggregate(events: events, scannedLogCount: 2, recentLimit: 10, periodStart: periodStart)
        XCTAssertEqual(r.totalCreditsAllTime, 6, accuracy: 0.0001)
        XCTAssertEqual(r.totalCreditsInPeriod, 5, accuracy: 0.0001)
        XCTAssertEqual(r.eventCountInPeriod, 2)
        XCTAssertEqual(r.eventCountAllTime, 3)
        XCTAssertEqual(r.perModelInPeriod["a"] ?? 0, 2, accuracy: 0.0001)
        XCTAssertEqual(r.perModelInPeriod["b"] ?? 0, 3, accuracy: 0.0001)
        XCTAssertEqual(r.recentChats.count, 2)
        XCTAssertEqual(r.earliestInPeriod, Date(timeIntervalSince1970: 1500))
        XCTAssertEqual(r.latestInPeriod, Date(timeIntervalSince1970: 2000))
    }

    func testTitlesFallbackAndSorting() {
        let r = AggregationStore().aggregate(
            events: [
                ev(100, "a", 1_000_000_000, sid: "s1"),
                ev(300, "a", 1_000_000_000, sid: "s2"),   // newer
            ],
            scannedLogCount: 1,
            recentLimit: 10,
            periodStart: Date(timeIntervalSince1970: 0),
            titles: ["s1": "First chat"]
        )
        XCTAssertEqual(r.recentChats.first?.id, "s2")          // sorted by lastTimestamp desc
        XCTAssertEqual(r.recentChats.first?.title, "Chat s2")  // fallback when no title supplied
        XCTAssertEqual(r.recentChats.last?.title, "First chat")
    }

    func testRecentLimitApplies() {
        let events = (0..<5).map { ev(Double($0 * 100), "a", 1_000_000_000, sid: "s\($0)") }
        let r = AggregationStore().aggregate(events: events, scannedLogCount: 1, recentLimit: 3, periodStart: Date(timeIntervalSince1970: 0))
        XCTAssertEqual(r.recentChats.count, 3)
    }

    func testChatTotalsSumWithinSession() {
        let r = AggregationStore().aggregate(
            events: [
                ev(100, "a", 1_000_000_000, sid: "s1"),
                ev(200, "a", 4_000_000_000, sid: "s1"),
            ],
            scannedLogCount: 1, recentLimit: 10, periodStart: Date(timeIntervalSince1970: 0)
        )
        XCTAssertEqual(r.recentChats.count, 1)
        XCTAssertEqual(r.recentChats.first?.eventCount, 2)
        XCTAssertEqual(r.recentChats.first?.totalCredits ?? 0, 5, accuracy: 0.0001)
    }
}
