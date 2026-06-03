import Foundation

/// Parses one session's `main.jsonl` (each file is a single chat session) plus
/// its sibling `title-*.jsonl` into usage events and a best-effort chat title.
enum LogScanner {
    struct SessionScan {
        let sid: String?
        let events: [UsageEvent]
        /// Copilot's generated title, else a first-user-prompt preview.
        /// `nil` => caller should fall back to "Chat <id-prefix>".
        let title: String?
    }

    static func scan(mainLogURL: URL) -> SessionScan? {
        guard let contents = try? String(contentsOf: mainLogURL, encoding: .utf8) else { return nil }

        var events: [UsageEvent] = []
        var sid: String?
        var firstUserTimestamp = Double.greatestFiniteMagnitude
        var firstUserContent: String?

        contents.enumerateLines { line, _ in
            guard let data = line.data(using: .utf8),
                  let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
            else {
                return
            }

            if sid == nil, let value = obj["sid"] as? String { sid = value }

            switch obj["type"] as? String {
            case "llm_request":
                if let event = UsageParser.event(from: obj) { events.append(event) }
            case "user_message":
                if let attrs = obj["attrs"] as? [String: Any],
                   let content = attrs["content"] as? String,
                   let ts = (obj["ts"] as? NSNumber)?.doubleValue,
                   ts < firstUserTimestamp {
                    firstUserTimestamp = ts
                    firstUserContent = content
                }
            default:
                break
            }
        }

        let dir = mainLogURL.deletingLastPathComponent()
        var title = titleFromSibling(in: dir)
        if title == nil, let prompt = firstUserContent { title = preview(prompt) }

        return SessionScan(sid: sid, events: events, title: title)
    }

    /// Read Copilot's generated title from a sibling `title-*.jsonl`, if present.
    /// The title lives in an `agent_response` event whose `attrs.response` is a
    /// JSON *string* encoding `[{ parts: [{ type: "text", content: "<title>" }] }]`.
    static func titleFromSibling(in dir: URL) -> String? {
        guard let files = try? FileManager.default.contentsOfDirectory(atPath: dir.path),
              let titleFile = files.first(where: { $0.hasPrefix("title-") && $0.hasSuffix(".jsonl") }),
              let contents = try? String(contentsOf: dir.appendingPathComponent(titleFile), encoding: .utf8)
        else {
            return nil
        }

        var result: String?
        contents.enumerateLines { line, _ in
            guard result == nil,
                  let data = line.data(using: .utf8),
                  let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  obj["type"] as? String == "agent_response",
                  let attrs = obj["attrs"] as? [String: Any],
                  let responseString = attrs["response"] as? String,
                  let responseData = responseString.data(using: .utf8),
                  let array = try? JSONSerialization.jsonObject(with: responseData) as? [[String: Any]]
            else {
                return
            }
            for item in array {
                guard let parts = item["parts"] as? [[String: Any]] else { continue }
                for part in parts where part["type"] as? String == "text" {
                    if let content = part["content"] as? String, !content.isEmpty {
                        result = content
                        return
                    }
                }
            }
        }

        guard let title = result?.trimmingCharacters(in: .whitespacesAndNewlines), !title.isEmpty else {
            return nil
        }
        return preview(title, limit: 80)
    }

    /// One-line, length-capped preview of free text.
    static func preview(_ text: String, limit: Int = 60) -> String {
        let oneLine = text
            .replacingOccurrences(of: "\n", with: " ")
            .trimmingCharacters(in: .whitespaces)
        if oneLine.count <= limit { return oneLine }
        return String(oneLine.prefix(limit)).trimmingCharacters(in: .whitespaces) + "…"
    }
}
