import SwiftUI
import AppKit

/// The popover shown when the menu bar item is clicked. Mirrors Copilot's own
/// usage footer: "Included Credits", percent used, progress, reset countdown.
struct MenuContentView: View {
    @EnvironmentObject private var settings: SettingsStore
    @EnvironmentObject private var viewModel: MenuBarViewModel
    @State private var showingSettings = false

    private enum UsageLevel { case ok, warning, critical, over }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            Divider()
            if showingSettings {
                SettingsView(onDone: {
                    showingSettings = false
                    viewModel.startWatching(settings: settings)   // re-point if root changed
                    viewModel.refresh(settings: settings)
                })
            } else {
                usagePanel
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
            }
        }
        .frame(width: 320)
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: 8) {
            Image(systemName: "creditcard")
            Text("Copilot Usage").font(.headline)
            if viewModel.isLive {
                HStack(spacing: 3) {
                    Circle().fill(Color.green).frame(width: 6, height: 6)
                    Text("Live").font(.caption2).foregroundStyle(.secondary)
                }
                .help("Watching logs for changes")
            }
            Spacer()
            Button {
                showingSettings.toggle()
            } label: {
                Image(systemName: showingSettings ? "chevron.backward" : "slider.horizontal.3")
            }
            .buttonStyle(.borderless)
            .help(showingSettings ? "Back" : "Settings")
        }
        .padding(12)
    }

    // MARK: - Usage panel

    private var usagePanel: some View {
        VStack(alignment: .leading, spacing: 12) {
            creditsHeader
            ProgressView(value: viewModel.usedRatio(allowance: settings.allowanceCredits))
                .tint(usageColor)
            Text("Resets in \(viewModel.daysUntilReset) \(viewModel.daysUntilReset == 1 ? "day" : "days") on \(Format.date(viewModel.resetDate)).")
                .font(.caption)
                .foregroundStyle(.secondary)
            warningBanner
            Divider()
            detail
            Divider()
            recentChatsSection
            Divider()
            footerActions
        }
    }

    private var creditsHeader: some View {
        HStack(alignment: .firstTextBaseline) {
            Text("Included Credits").font(.title3).fontWeight(.semibold)
            Spacer()
            Text("\(Format.percentValue(viewModel.usedPercent(allowance: settings.allowanceCredits))) used")
                .font(.subheadline)
                .monospacedDigit()
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Warning

    private var rawRatio: Double {
        settings.allowanceCredits > 0 ? viewModel.usedInPeriod / settings.allowanceCredits : 0
    }

    private var usageLevel: UsageLevel {
        let ratio = rawRatio
        if ratio >= 1.0 { return .over }
        if ratio >= 0.9 { return .critical }
        if ratio >= 0.75 { return .warning }
        return .ok
    }

    @ViewBuilder
    private var warningBanner: some View {
        switch usageLevel {
        case .ok:
            EmptyView()
        case .warning:
            warningRow(
                icon: "exclamationmark.triangle",
                color: .orange,
                text: "Approaching limit — \(Format.percentValue(viewModel.usedPercent(allowance: settings.allowanceCredits))) used"
            )
        case .critical:
            warningRow(
                icon: "exclamationmark.triangle.fill",
                color: .red,
                text: "Almost out — \(Format.compact(viewModel.remaining(allowance: settings.allowanceCredits))) credits left"
            )
        case .over:
            warningRow(
                icon: "exclamationmark.octagon.fill",
                color: .red,
                text: "Over your limit by \(Format.compact(viewModel.usedInPeriod - settings.allowanceCredits)) credits"
            )
        }
    }

    private func warningRow(icon: String, color: Color, text: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon).foregroundStyle(color)
            Text(text).font(.caption).fontWeight(.medium).foregroundStyle(color)
            Spacer()
        }
        .padding(8)
        .background(color.opacity(0.12), in: RoundedRectangle(cornerRadius: 6))
    }

    // MARK: - Detail

    private var detail: some View {
        VStack(alignment: .leading, spacing: 3) {
            row("Used this period",
                "\(Format.compact(viewModel.usedInPeriod)) / \(Format.compact(settings.allowanceCredits))")
            if viewModel.usedAllTime > viewModel.usedInPeriod + 0.005 {
                row("All-time on disk", Format.compact(viewModel.usedAllTime), subtle: true)
            }
            HStack(alignment: .top) {
                Text(coverageText)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                Spacer()
                statusText
            }
        }
    }

    private func row(_ label: String, _ value: String, subtle: Bool = false) -> some View {
        HStack {
            Text(label)
                .font(subtle ? .caption2 : .caption)
                .foregroundStyle(subtle ? .tertiary : .secondary)
            Spacer()
            Text(value)
                .font(subtle ? .caption2 : .caption)
                .monospacedDigit()
                .foregroundStyle(subtle ? .tertiary : .primary)
        }
    }

    @ViewBuilder
    private var statusText: some View {
        switch viewModel.state {
        case .loading:
            HStack(spacing: 4) {
                ProgressView().controlSize(.small)
                Text("Scanning…")
            }
            .font(.caption2)
            .foregroundStyle(.tertiary)
        case .failed(let message):
            Text(message).font(.caption2).foregroundStyle(.red)
        case .loaded:
            if let updated = viewModel.lastUpdated {
                Text("Updated \(Format.relative(updated))")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        case .idle:
            EmptyView()
        }
    }

    /// Signals the local-vs-admin gap: which days the on-disk logs cover, and
    /// when the billing period actually began.
    private var coverageText: String {
        let began = "period began \(Format.dayShort(viewModel.periodStart))"
        guard let earliest = viewModel.earliestInPeriod else { return began }
        let range: String
        if let latest = viewModel.latestInPeriod,
           !Calendar.current.isDate(latest, inSameDayAs: earliest) {
            range = "\(Format.dayShort(earliest))–\(Format.dayShort(latest))"
        } else {
            range = Format.dayShort(earliest)
        }
        return "logs \(range) · \(began)"
    }

    // MARK: - Recent chats

    private var recentChatsSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("Recent Chats").font(.caption).foregroundStyle(.secondary)
                Spacer()
                if viewModel.eventCountInPeriod > 0 {
                    Text("\(viewModel.eventCountInPeriod) reqs")
                        .font(.caption2).foregroundStyle(.tertiary)
                }
            }
            if viewModel.recentChats.isEmpty {
                Text("No chats this period").font(.caption).foregroundStyle(.tertiary)
            } else {
                ForEach(viewModel.recentChats) { chat in
                    HStack {
                        VStack(alignment: .leading, spacing: 1) {
                            Text(chat.title).font(.caption).lineLimit(1)
                            Text("\(chat.eventCount) req · \(Format.relative(chat.lastTimestamp))")
                                .font(.caption2).foregroundStyle(.tertiary)
                        }
                        Spacer()
                        Text(Format.compact(chat.totalCredits))
                            .font(.caption).monospacedDigit()
                    }
                }
            }
        }
    }

    // MARK: - Actions

    private var footerActions: some View {
        HStack {
            Button {
                viewModel.refresh(settings: settings)
            } label: {
                Label("Refresh", systemImage: "arrow.clockwise")
            }
            Spacer()
            Button { openLogsFolder() } label: {
                Image(systemName: "folder")
            }
            .help("Open Logs Folder")
            Button { NSApplication.shared.terminate(nil) } label: {
                Image(systemName: "power")
            }
            .help("Quit")
        }
        .buttonStyle(.borderless)
    }

    // MARK: - Helpers

    private var usageColor: Color {
        switch usageLevel {
        case .ok: return .accentColor
        case .warning: return .orange
        case .critical, .over: return .red
        }
    }

    private func openLogsFolder() {
        let override = settings.logRootOverride.isEmpty ? nil : settings.logRootOverride
        let path = viewModel.discoveredLogRoot.isEmpty
            ? LogDiscoveryService(rootOverride: override).rootPath
            : viewModel.discoveredLogRoot
        NSWorkspace.shared.open(URL(fileURLWithPath: path))
    }
}
