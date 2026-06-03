import XCTest
@testable import CopilotCreditsMenuBar

final class ScannerTests: XCTestCase {
    private var tmp: URL!

    override func setUpWithError() throws {
        tmp = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("cctest-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tmp, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: tmp)
    }

    private func write(_ contents: String, to relPath: String) throws -> URL {
        let url = tmp.appendingPathComponent(relPath)
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try contents.write(to: url, atomically: true, encoding: .utf8)
        return url
    }

    // MARK: Format helpers

    func testPreviewCollapsesAndTruncates() {
        XCTAssertEqual(LogScanner.preview("hello   world"), "hello   world")
        XCTAssertEqual(LogScanner.preview("a\nb\nc"), "a b c")
        let long = String(repeating: "x", count: 100)
        let p = LogScanner.preview(long, limit: 10)
        XCTAssertEqual(p.count, 11)            // 10 chars + "…"
        XCTAssertTrue(p.hasSuffix("…"))
    }

    // MARK: VS Code source

    func testLogScannerEventsAndTitleFromSibling() throws {
        let main = """
        {"type":"session_start","sid":"sid-A","ts":1000,"attrs":{}}
        {"type":"user_message","sid":"sid-A","ts":1001,"attrs":{"content":"How do I do X?"}}
        {"type":"llm_request","sid":"sid-A","ts":1002,"attrs":{"model":"gpt-5.3-codex","copilotUsageNanoAiu":2000000000,"responseId":"r"}}
        """
        let mainURL = try write(main, to: "sessionA/main.jsonl")
        let title = #"{"type":"agent_response","attrs":{"response":"[{\"role\":\"assistant\",\"parts\":[{\"type\":\"text\",\"content\":\"Doing X\"}]}]"}}"#
        _ = try write(title, to: "sessionA/title-abc.jsonl")

        let scan = LogScanner.scan(mainLogURL: mainURL)
        XCTAssertEqual(scan?.sid, "sid-A")
        XCTAssertEqual(scan?.events.count, 1)
        XCTAssertEqual(scan?.events.first?.credits ?? 0, 2.0, accuracy: 0.0001)
        XCTAssertEqual(scan?.title, "Doing X")   // generated title preferred over prompt
    }

    func testLogScannerFallsBackToPromptPreview() throws {
        let main = """
        {"type":"user_message","sid":"sid-B","ts":2001,"attrs":{"content":"Line one\\nLine two"}}
        {"type":"llm_request","sid":"sid-B","ts":2002,"attrs":{"model":"x","copilotUsageNanoAiu":1000000000}}
        """
        let mainURL = try write(main, to: "sessionB/main.jsonl")
        let scan = LogScanner.scan(mainLogURL: mainURL)
        XCTAssertEqual(scan?.title, "Line one Line two")   // newline collapsed; no title file
    }

    // MARK: Copilot CLI source

    func testCLIScannerSumsShutdownSegments() throws {
        let events = """
        {"type":"session.start","timestamp":"2026-06-02T10:00:00.000Z","data":{"context":{"cwd":"/Users/me/Repo"}}}
        {"type":"user.message","timestamp":"2026-06-02T10:01:00.000Z","data":{"content":"hello there"}}
        {"type":"session.shutdown","timestamp":"2026-06-02T10:05:00.000Z","data":{"modelMetrics":{"claude-opus-4.6":{"totalNanoAiu":2000000000}}}}
        {"type":"session.shutdown","timestamp":"2026-06-02T10:10:00.000Z","data":{"modelMetrics":{"claude-opus-4.6":{"totalNanoAiu":3000000000}}}}
        """
        let url = try write(events, to: "cliSession/events.jsonl")
        let scan = CopilotCLIScanner.scan(sessionLogURL: url)
        XCTAssertEqual(scan?.events.count, 2)                       // one per segment, summed downstream
        let total = (scan?.events.reduce(0) { $0 + $1.credits }) ?? 0
        XCTAssertEqual(total, 5.0, accuracy: 0.0001)               // 2 + 3
        XCTAssertEqual(scan?.events.first?.model, "claude-opus-4.6")
        XCTAssertEqual(scan?.title, "hello there")
        XCTAssertTrue(scan?.sessionId.hasPrefix("cli:") ?? false)
    }

    func testCLIScannerSkipsUnpricedOldFormat() throws {
        let events = """
        {"type":"session.shutdown","timestamp":"2026-05-28T10:05:00.000Z","data":{"modelMetrics":{"claude-opus-4.6":{"requests":{"count":21,"cost":3},"usage":{"inputTokens":100}}}}}
        """
        let url = try write(events, to: "cliOld/events.jsonl")
        let scan = CopilotCLIScanner.scan(sessionLogURL: url)
        XCTAssertEqual(scan?.events.count, 0)   // no totalNanoAiu -> unpriced -> skipped
    }
}
