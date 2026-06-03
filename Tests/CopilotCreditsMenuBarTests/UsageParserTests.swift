import XCTest
@testable import CopilotCreditsMenuBar

final class UsageParserTests: XCTestCase {
    func testValidEvent() {
        let e = UsageParser.event(from: [
            "type": "llm_request",
            "ts": NSNumber(value: 1_700_000_000_000),
            "sid": "sess1",
            "attrs": [
                "model": "gpt-5.3-codex",
                "responseId": "r1",
                "copilotUsageNanoAiu": NSNumber(value: 2_350_000_000),
            ],
        ])
        XCTAssertEqual(e?.model, "gpt-5.3-codex")
        XCTAssertEqual(e?.sessionId, "sess1")
        XCTAssertEqual(e?.responseId, "r1")
        XCTAssertEqual(e?.credits ?? 0, 2.35, accuracy: 0.0001)
    }

    func testMissingUsageFieldIsNil() {
        XCTAssertNil(UsageParser.event(from: [
            "type": "llm_request",
            "ts": NSNumber(value: 1),
            "attrs": ["model": "claude-opus-4.6"],   // no copilotUsageNanoAiu
        ]))
    }

    func testNonBillableDebugNamesAreExcluded() {
        for dbg in ["summarizeVirtualTools", "title"] {
            XCTAssertNil(
                UsageParser.event(from: [
                    "type": "llm_request",
                    "ts": NSNumber(value: 1),
                    "attrs": [
                        "model": "gpt-4o-mini",
                        "debugName": dbg,
                        "copilotUsageNanoAiu": NSNumber(value: 430_000_000),
                    ],
                ]),
                "debugName \(dbg) should be excluded from billing"
            )
        }
    }

    func testWrongTypeIsNil() {
        XCTAssertNil(UsageParser.event(from: [
            "type": "user_message",
            "ts": NSNumber(value: 1),
            "attrs": ["content": "hi"],
        ]))
    }

    func testParseLineRoundTrip() {
        let line = #"{"type":"llm_request","ts":1700000000000,"sid":"s","attrs":{"model":"m","copilotUsageNanoAiu":1000000000}}"#
        XCTAssertEqual(UsageParser.parse(line: line)?.credits ?? 0, 1.0, accuracy: 0.0001)
        XCTAssertNil(UsageParser.parse(line: "not json"))
    }
}
