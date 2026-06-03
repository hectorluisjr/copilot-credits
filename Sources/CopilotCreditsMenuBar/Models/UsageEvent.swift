import Foundation

/// One parsed `llm_request` telemetry event from a Copilot debug log.
struct UsageEvent: Identifiable, Codable, Equatable, Sendable {
    let id: UUID
    let timestamp: Date
    let sessionId: String?
    let responseId: String?
    let model: String
    let nanoAiu: Double

    /// Visible credits for this single request.
    var credits: Double { creditsFromNanoAiu(nanoAiu) }

    init(
        id: UUID = UUID(),
        timestamp: Date,
        sessionId: String?,
        responseId: String?,
        model: String,
        nanoAiu: Double
    ) {
        self.id = id
        self.timestamp = timestamp
        self.sessionId = sessionId
        self.responseId = responseId
        self.model = model
        self.nanoAiu = nanoAiu
    }
}
