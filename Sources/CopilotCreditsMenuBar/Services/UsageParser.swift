import Foundation

/// Parses raw Copilot debug-log JSON into `UsageEvent`s.
///
/// Mirrors the verified logic in `scripts/copilot-credits-watcher.swift`:
/// filter to `type == "llm_request"` and read `copilotUsageNanoAiu` under `attrs`.
enum UsageParser {
    /// Internal helper calls GitHub does not bill (auto-title generation, tool
    /// summarization). Excluding them makes the local total match the billed
    /// total shown in the GitHub admin panel.
    static let nonBillableDebugNames: Set<String> = ["title", "summarizeVirtualTools"]

    /// Build a `UsageEvent` from an already-decoded log object. Returns `nil`
    /// unless it is a usable, billable `llm_request` (has model, usage, timestamp).
    static func event(from obj: [String: Any]) -> UsageEvent? {
        guard obj["type"] as? String == "llm_request",
              let attrs = obj["attrs"] as? [String: Any],
              let model = attrs["model"] as? String,
              let nano = attrs["copilotUsageNanoAiu"] as? NSNumber,
              let ts = obj["ts"] as? NSNumber
        else {
            return nil
        }

        if let debugName = attrs["debugName"] as? String,
           nonBillableDebugNames.contains(debugName) {
            return nil
        }

        return UsageEvent(
            timestamp: Date(timeIntervalSince1970: ts.doubleValue / 1000.0),
            sessionId: obj["sid"] as? String,
            responseId: attrs["responseId"] as? String,
            model: model,
            nanoAiu: nano.doubleValue
        )
    }

    /// Parse one JSONL line into a `UsageEvent`, or `nil` for non-usage / malformed lines.
    static func parse(line: String) -> UsageEvent? {
        guard let data = line.data(using: .utf8),
              let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else {
            return nil
        }
        return event(from: obj)
    }

    /// Parse every usable event from a file's full text contents.
    static func parseEvents(fromContents contents: String) -> [UsageEvent] {
        var events: [UsageEvent] = []
        contents.enumerateLines { line, _ in
            if !line.isEmpty, let event = parse(line: line) {
                events.append(event)
            }
        }
        return events
    }
}
