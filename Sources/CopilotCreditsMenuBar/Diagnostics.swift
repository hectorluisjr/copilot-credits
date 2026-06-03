import Foundation

/// Hidden CLI diagnostic: `CopilotCreditsMenuBar --print-total` runs the real
/// scan pipeline, prints the computed totals, and exits (no UI). Handy for
/// checking the numbers against the GitHub admin panel.
enum Diagnostics {
    static func runIfRequested() {
        guard CommandLine.arguments.contains("--print-total") else { return }

        let settings = SettingsStore.shared
        let override = settings.logRootOverride.isEmpty ? nil : settings.logRootOverride
        let period = BillingPeriodCalculator.current(resetDay: BillingPeriodCalculator.monthlyResetDay, now: Date())

        var events: [UsageEvent] = []
        var vscodeCount = 0
        var cliCount = 0

        let discovery = LogDiscoveryService(rootOverride: override)
        for url in discovery.allMainLogs() {
            vscodeCount += 1
            if let scan = LogScanner.scan(mainLogURL: url) { events.append(contentsOf: scan.events) }
        }
        for url in CopilotCLIScanner.sessionLogs(root: CopilotCLIScanner.defaultRoot) {
            cliCount += 1
            if let scan = CopilotCLIScanner.scan(sessionLogURL: url) { events.append(contentsOf: scan.events) }
        }

        let result = AggregationStore().aggregate(
            events: events,
            scannedLogCount: vscodeCount + cliCount,
            recentLimit: 1000,
            periodStart: period.start
        )

        let df = DateFormatter()
        df.dateFormat = "yyyy-MM-dd"
        print("Billing period:  \(df.string(from: period.start)) -> \(df.string(from: period.reset))")
        print(String(format: "In-period total: %.2f credits", result.totalCreditsInPeriod))
        print(String(format: "All-time total:  %.2f credits", result.totalCreditsAllTime))
        print("Sources: \(vscodeCount) VS Code logs, \(cliCount) CLI sessions")
        print("Per-model (in period):")
        for (model, credits) in result.perModelInPeriod.sorted(by: { $0.value > $1.value }) {
            print(String(format: "  %@: %.2f", model, credits))
        }
        exit(0)
    }
}
