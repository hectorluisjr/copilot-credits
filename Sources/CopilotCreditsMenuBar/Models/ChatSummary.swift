import Foundation

/// A grouped set of usage events representing one chat/session.
///
/// Phase 1 uses a fallback `title` ("Chat <id prefix>"). Phase 3 will derive a
/// real title from a sibling `title-*.jsonl` or the first user prompt.
struct ChatSummary: Identifiable, Codable, Equatable, Sendable {
    let id: String                       // sessionId, else responseId, else "unknown"
    let title: String
    let lastTimestamp: Date
    let totalCredits: Double
    let eventCount: Int
    let modelBreakdown: [String: Double]
}
