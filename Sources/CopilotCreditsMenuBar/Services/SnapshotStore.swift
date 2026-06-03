import Foundation

/// A small persisted snapshot of the last successful scan, so the menu bar can
/// show the last-known numbers instantly on launch (before the first scan
/// finishes) instead of flashing a placeholder.
struct UsageSnapshot: Codable {
    var usedInPeriod: Double
    var usedAllTime: Double
    var perModel: [String: Double]
    var recentChats: [ChatSummary]
    var eventCountInPeriod: Int
    var periodStart: Date
    var resetDate: Date
    var daysUntilReset: Int
    var earliestInPeriod: Date?
    var latestInPeriod: Date?
    var scannedLogCount: Int
    var discoveredLogRoot: String
    var savedAt: Date
}

/// Reads/writes the snapshot as JSON under `~/Library/Caches/CopilotCredits/`.
enum SnapshotStore {
    private static var fileURL: URL? {
        guard let base = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first else { return nil }
        let dir = base.appendingPathComponent("CopilotCredits", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("snapshot.json")
    }

    static func load() -> UsageSnapshot? {
        guard let url = fileURL, let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(UsageSnapshot.self, from: data)
    }

    static func save(_ snapshot: UsageSnapshot) {
        guard let url = fileURL, let data = try? JSONEncoder().encode(snapshot) else { return }
        try? data.write(to: url, options: .atomic)
    }
}
