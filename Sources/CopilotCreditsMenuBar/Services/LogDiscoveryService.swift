import Foundation

/// Finds Copilot chat debug logs under the VS Code workspace storage tree.
struct LogDiscoveryService {
    /// Optional override for the `workspaceStorage` root (from settings).
    var rootOverride: String?

    /// The root directory that will be scanned for logs.
    var rootPath: String {
        if let override = rootOverride, !override.isEmpty {
            return (override as NSString).expandingTildeInPath
        }
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        return "\(home)/Library/Application Support/Code/User/workspaceStorage"
    }

    /// All `main.jsonl` files under any `GitHub.copilot-chat/debug-logs/`
    /// directory, newest (most recently modified) first.
    func allMainLogs() -> [URL] {
        let root = rootPath
        guard let enumerator = FileManager.default.enumerator(atPath: root) else {
            return []
        }

        var found: [(url: URL, date: Date)] = []
        while let rel = enumerator.nextObject() as? String {
            guard rel.hasSuffix("/main.jsonl"),
                  rel.contains("/GitHub.copilot-chat/debug-logs/") else { continue }

            let fullPath = "\(root)/\(rel)"
            let attrs = try? FileManager.default.attributesOfItem(atPath: fullPath)
            let date = (attrs?[.modificationDate] as? Date) ?? .distantPast
            found.append((URL(fileURLWithPath: fullPath), date))
        }

        return found.sorted { $0.date > $1.date }.map(\.url)
    }

    /// Most recently modified `main.jsonl`, if any.
    func latestMainLog() -> URL? {
        allMainLogs().first
    }
}
