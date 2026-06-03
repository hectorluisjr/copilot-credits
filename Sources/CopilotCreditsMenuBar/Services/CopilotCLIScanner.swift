import Foundation

/// Reads the Copilot CLI / agentic store: `~/.copilot/session-state/<uuid>/events.jsonl`.
///
/// Credits live on `session.shutdown` events as
/// `data.modelMetrics.<model>.totalNanoAiu`, reported PER SEGMENT — a resumed
/// session emits several shutdowns, each with its own segment total — so they
/// are summed (never max'd). Older CLI builds omit `totalNanoAiu` (token counts
/// only) and are simply left unpriced. Each priced (shutdown, model) pair
/// becomes a synthetic `UsageEvent` so it flows through the same `AggregationStore`.
enum CopilotCLIScanner {
    /// `~/.copilot/session-state`
    static var defaultRoot: String {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".copilot/session-state").path
    }

    struct SessionScan {
        let sessionId: String
        let events: [UsageEvent]
        let title: String?
    }

    /// All per-session `events.jsonl` files under the store root.
    static func sessionLogs(root: String) -> [URL] {
        guard let entries = try? FileManager.default.contentsOfDirectory(atPath: root) else { return [] }
        let base = URL(fileURLWithPath: root)
        return entries
            .map { base.appendingPathComponent($0).appendingPathComponent("events.jsonl") }
            .filter { FileManager.default.fileExists(atPath: $0.path) }
    }

    static func scan(sessionLogURL: URL) -> SessionScan? {
        guard let contents = try? String(contentsOf: sessionLogURL, encoding: .utf8) else { return nil }
        let sessionId = "cli:" + sessionLogURL.deletingLastPathComponent().lastPathComponent

        // Local (per-call) formatters — ISO8601DateFormatter isn't guaranteed
        // thread-safe to share across concurrent scans.
        let isoFractional = ISO8601DateFormatter()
        isoFractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let isoPlain = ISO8601DateFormatter()
        isoPlain.formatOptions = [.withInternetDateTime]
        func parseDate(_ string: String?) -> Date? {
            guard let string else { return nil }
            return isoFractional.date(from: string) ?? isoPlain.date(from: string)
        }

        var events: [UsageEvent] = []
        var firstUserContent: String?
        var firstUserDate = Date.distantFuture
        var cwd: String?

        contents.enumerateLines { line, _ in
            guard let data = line.data(using: .utf8),
                  let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
            else {
                return
            }
            let payload = obj["data"] as? [String: Any] ?? [:]

            switch obj["type"] as? String {
            case "session.shutdown":
                guard let modelMetrics = payload["modelMetrics"] as? [String: Any] else { return }
                let timestamp = parseDate(obj["timestamp"] as? String) ?? .distantPast
                for (model, raw) in modelMetrics {
                    guard let metrics = raw as? [String: Any],
                          let nano = (metrics["totalNanoAiu"] as? NSNumber)?.doubleValue,
                          nano > 0 else { continue }
                    events.append(UsageEvent(
                        timestamp: timestamp,
                        sessionId: sessionId,
                        responseId: nil,
                        model: model,
                        nanoAiu: nano
                    ))
                }
            case "user.message":
                if let content = payload["content"] as? String,
                   let date = parseDate(obj["timestamp"] as? String),
                   date < firstUserDate {
                    firstUserDate = date
                    firstUserContent = content
                }
            case "session.start":
                if cwd == nil,
                   let context = payload["context"] as? [String: Any],
                   let value = context["cwd"] as? String {
                    cwd = value
                }
            default:
                break
            }
        }

        var title: String?
        if let prompt = firstUserContent { title = LogScanner.preview(prompt) }
        if title == nil, let cwd { title = "CLI · " + (cwd as NSString).lastPathComponent }

        return SessionScan(sessionId: sessionId, events: events, title: title)
    }
}
