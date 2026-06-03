import Foundation

/// The aggregated outcome of scanning one or more logs, scoped to a billing
/// period. "InPeriod" figures count only events at/after the period start;
/// "AllTime" figures count everything still on disk (for reference).
struct AggregationResult: Equatable, Sendable {
    var totalCreditsAllTime: Double = 0
    var totalCreditsInPeriod: Double = 0
    var eventCountAllTime: Int = 0
    var eventCountInPeriod: Int = 0
    var perModelInPeriod: [String: Double] = [:]
    var recentChats: [ChatSummary] = []          // in-period
    var scannedLogCount: Int = 0
    var earliestInPeriod: Date?
    var latestInPeriod: Date?
}

/// Aggregates parsed usage events into period totals and per-chat summaries.
struct AggregationStore {
    /// Group key for a "chat": session id, else response id, else "unknown".
    private func chatKey(for event: UsageEvent) -> String {
        event.sessionId ?? event.responseId ?? "unknown"
    }

    /// - Parameter titles: best-known title per chat key (session id). Missing
    ///   keys fall back to "Chat <id-prefix>".
    func aggregate(
        events: [UsageEvent],
        scannedLogCount: Int,
        recentLimit: Int,
        periodStart: Date,
        titles: [String: String] = [:]
    ) -> AggregationResult {
        var result = AggregationResult()
        result.scannedLogCount = scannedLogCount

        var grouped: [String: [UsageEvent]] = [:]
        for event in events {
            result.totalCreditsAllTime += event.credits
            result.eventCountAllTime += 1

            guard event.timestamp >= periodStart else { continue }

            result.totalCreditsInPeriod += event.credits
            result.eventCountInPeriod += 1
            result.perModelInPeriod[event.model, default: 0] += event.credits
            grouped[chatKey(for: event), default: []].append(event)

            if let earliest = result.earliestInPeriod {
                result.earliestInPeriod = min(earliest, event.timestamp)
            } else {
                result.earliestInPeriod = event.timestamp
            }
            if let latest = result.latestInPeriod {
                result.latestInPeriod = max(latest, event.timestamp)
            } else {
                result.latestInPeriod = event.timestamp
            }
        }

        let summaries: [ChatSummary] = grouped.map { key, groupEvents in
            let total = groupEvents.reduce(0) { $0 + $1.credits }
            let last = groupEvents.map(\.timestamp).max() ?? .distantPast
            var perModel: [String: Double] = [:]
            for event in groupEvents { perModel[event.model, default: 0] += event.credits }
            return ChatSummary(
                id: key,
                title: titles[key] ?? "Chat \(key.prefix(8))",
                lastTimestamp: last,
                totalCredits: total,
                eventCount: groupEvents.count,
                modelBreakdown: perModel
            )
        }

        result.recentChats = Array(
            summaries
                .sorted { $0.lastTimestamp > $1.lastTimestamp }
                .prefix(max(0, recentLimit))
        )
        return result
    }
}
