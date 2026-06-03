import Foundation
import Combine

/// Backing model for the menu bar UI. Aggregates Copilot usage across multiple
/// client stores — VS Code Copilot Chat and the Copilot CLI — scoped to the
/// current billing period, and live-watches both stores for changes.
@MainActor
final class MenuBarViewModel: ObservableObject {
    static let shared = MenuBarViewModel()

    enum LoadState: Equatable {
        case idle
        case loading
        case loaded
        case failed(String)
    }

    // Usage
    @Published private(set) var usedInPeriod: Double = 0
    @Published private(set) var usedAllTime: Double = 0
    @Published private(set) var recentChats: [ChatSummary] = []
    @Published private(set) var perModel: [String: Double] = [:]
    @Published private(set) var eventCountInPeriod: Int = 0

    // Billing period
    @Published private(set) var periodStart: Date = .distantPast
    @Published private(set) var resetDate: Date = .distantFuture
    @Published private(set) var daysUntilReset: Int = 0
    @Published private(set) var earliestInPeriod: Date?
    @Published private(set) var latestInPeriod: Date?

    // Meta
    @Published private(set) var lastUpdated: Date?
    @Published private(set) var scannedLogCount: Int = 0
    @Published private(set) var discoveredLogRoot: String = ""
    @Published private(set) var state: LoadState = .idle
    @Published private(set) var isLive: Bool = false

    init() {
        applyCachedSnapshot()
    }

    /// Sendable bundle returned by the off-main scan.
    private struct ScanOutcome: Sendable {
        let result: AggregationResult
        let rootPath: String
        let logCount: Int
        let period: BillingPeriod
        let daysUntilReset: Int
    }

    // Live watching
    private var watchers: [FileWatcher] = []
    private var watchedRoots: [String] = []
    private var boundSettings: SettingsStore?
    private var debounceTask: Task<Void, Never>?
    private var heartbeatTask: Task<Void, Never>?

    private static let debounceNanos: UInt64 = 600_000_000          // 0.6s
    private static let heartbeatNanos: UInt64 = 300_000_000_000     // 5 min

    // MARK: - Scanning

    /// Scan all sources, scoped to the current period. Heavy file I/O and
    /// parsing run off the main actor. `showLoading: false` keeps the current UI
    /// (no "Scanning…" flicker) for background live/heartbeat refreshes.
    func refresh(settings: SettingsStore, showLoading: Bool = true) {
        let rootOverride = settings.logRootOverride.isEmpty ? nil : settings.logRootOverride
        let recentLimit = settings.recentChatsLimit
        let now = Date()
        if showLoading { state = .loading }

        Task {
            let outcome = await Task.detached(priority: .userInitiated) { () -> ScanOutcome in
                let period = BillingPeriodCalculator.current(resetDay: BillingPeriodCalculator.monthlyResetDay, now: now)
                let days = BillingPeriodCalculator.daysUntil(period.reset, from: now)

                var events: [UsageEvent] = []
                var titles: [String: String] = [:]

                // Source A: VS Code Copilot Chat (main.jsonl + sibling title-*.jsonl)
                let discovery = LogDiscoveryService(rootOverride: rootOverride)
                let vscodeLogs = discovery.allMainLogs()
                for url in vscodeLogs {
                    guard let scan = LogScanner.scan(mainLogURL: url) else { continue }
                    events.append(contentsOf: scan.events)
                    if let sid = scan.sid, let title = scan.title, titles[sid] == nil {
                        titles[sid] = title
                    }
                }

                // Source B: Copilot CLI (~/.copilot/session-state/*/events.jsonl)
                let cliLogs = CopilotCLIScanner.sessionLogs(root: CopilotCLIScanner.defaultRoot)
                for url in cliLogs {
                    guard let scan = CopilotCLIScanner.scan(sessionLogURL: url) else { continue }
                    events.append(contentsOf: scan.events)
                    if let title = scan.title, titles[scan.sessionId] == nil {
                        titles[scan.sessionId] = title
                    }
                }

                let result = AggregationStore().aggregate(
                    events: events,
                    scannedLogCount: vscodeLogs.count + cliLogs.count,
                    recentLimit: recentLimit,
                    periodStart: period.start,
                    titles: titles
                )
                return ScanOutcome(
                    result: result,
                    rootPath: discovery.rootPath,
                    logCount: vscodeLogs.count + cliLogs.count,
                    period: period,
                    daysUntilReset: days
                )
            }.value

            usedInPeriod = outcome.result.totalCreditsInPeriod
            usedAllTime = outcome.result.totalCreditsAllTime
            recentChats = outcome.result.recentChats
            perModel = outcome.result.perModelInPeriod
            eventCountInPeriod = outcome.result.eventCountInPeriod
            scannedLogCount = outcome.result.scannedLogCount
            discoveredLogRoot = outcome.rootPath
            periodStart = outcome.period.start
            resetDate = outcome.period.reset
            daysUntilReset = outcome.daysUntilReset
            earliestInPeriod = outcome.result.earliestInPeriod
            latestInPeriod = outcome.result.latestInPeriod
            lastUpdated = Date()
            state = outcome.logCount == 0 ? .failed("No Copilot logs found") : .loaded
            if outcome.logCount > 0 { saveSnapshot() }
        }
    }

    // MARK: - Live watching

    /// Start (or re-point) FSEvents watchers on every source root, plus the
    /// periodic heartbeat. No-op if already watching the same roots.
    func startWatching(settings: SettingsStore) {
        boundSettings = settings
        let override = settings.logRootOverride.isEmpty ? nil : settings.logRootOverride
        let roots = [
            LogDiscoveryService(rootOverride: override).rootPath,
            CopilotCLIScanner.defaultRoot,
        ]

        if !watchers.isEmpty, watchedRoots == roots {
            startHeartbeat()
            return
        }

        watchers.forEach { $0.stop() }
        watchers.removeAll()
        watchedRoots = roots

        for root in roots where FileManager.default.fileExists(atPath: root) {
            let watcher = FileWatcher(
                path: root,
                matches: { $0.contains("GitHub.copilot-chat") || $0.contains("/.copilot/session-state") },
                onChange: { [weak self] in
                    Task { @MainActor in self?.scheduleLiveRefresh() }
                }
            )
            watcher.start()
            watchers.append(watcher)
        }

        isLive = !watchers.isEmpty
        startHeartbeat()
    }

    func stopWatching() {
        watchers.forEach { $0.stop() }
        watchers.removeAll()
        watchedRoots.removeAll()
        debounceTask?.cancel()
        heartbeatTask?.cancel()
        heartbeatTask = nil
        isLive = false
    }

    /// Debounced re-scan: collapses a burst of file events into one refresh.
    private func scheduleLiveRefresh() {
        guard let settings = boundSettings else { return }
        debounceTask?.cancel()
        debounceTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: MenuBarViewModel.debounceNanos)
            guard !Task.isCancelled else { return }
            self?.refresh(settings: settings, showLoading: false)
        }
    }

    /// Low-frequency safety refresh — catches any missed FS events and keeps the
    /// "resets in N days" countdown and "updated" timestamp fresh while idle.
    private func startHeartbeat() {
        guard heartbeatTask == nil else { return }
        heartbeatTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: MenuBarViewModel.heartbeatNanos)
                guard !Task.isCancelled, let self, let settings = self.boundSettings else { return }
                self.refresh(settings: settings, showLoading: false)
            }
        }
    }

    // MARK: - Snapshot cache

    private func applyCachedSnapshot() {
        guard let snapshot = SnapshotStore.load() else { return }
        usedInPeriod = snapshot.usedInPeriod
        usedAllTime = snapshot.usedAllTime
        recentChats = snapshot.recentChats
        perModel = snapshot.perModel
        eventCountInPeriod = snapshot.eventCountInPeriod
        periodStart = snapshot.periodStart
        resetDate = snapshot.resetDate
        daysUntilReset = snapshot.daysUntilReset
        earliestInPeriod = snapshot.earliestInPeriod
        latestInPeriod = snapshot.latestInPeriod
        scannedLogCount = snapshot.scannedLogCount
        discoveredLogRoot = snapshot.discoveredLogRoot
        lastUpdated = snapshot.savedAt
        state = .loaded
    }

    private func saveSnapshot() {
        SnapshotStore.save(UsageSnapshot(
            usedInPeriod: usedInPeriod,
            usedAllTime: usedAllTime,
            perModel: perModel,
            recentChats: recentChats,
            eventCountInPeriod: eventCountInPeriod,
            periodStart: periodStart,
            resetDate: resetDate,
            daysUntilReset: daysUntilReset,
            earliestInPeriod: earliestInPeriod,
            latestInPeriod: latestInPeriod,
            scannedLogCount: scannedLogCount,
            discoveredLogRoot: discoveredLogRoot,
            savedAt: lastUpdated ?? Date()
        ))
    }

    // MARK: - Derived values

    func remaining(allowance: Double) -> Double {
        max(allowance - usedInPeriod, 0)
    }

    /// Used fraction, clamped to 0...1 for the progress bar.
    func usedRatio(allowance: Double) -> Double {
        guard allowance > 0 else { return 0 }
        return min(max(usedInPeriod / allowance, 0), 1)
    }

    /// Unclamped percent for display (can exceed 100%).
    func usedPercent(allowance: Double) -> Double {
        guard allowance > 0 else { return 0 }
        return usedInPeriod / allowance * 100
    }
}
