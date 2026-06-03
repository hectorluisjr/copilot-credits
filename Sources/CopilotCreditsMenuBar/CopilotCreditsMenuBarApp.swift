import SwiftUI

@main
struct CopilotCreditsMenuBarApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var settings = SettingsStore.shared
    @StateObject private var viewModel = MenuBarViewModel.shared

    init() {
        Diagnostics.runIfRequested()
    }

    var body: some Scene {
        MenuBarExtra {
            MenuContentView()
                .environmentObject(settings)
                .environmentObject(viewModel)
        } label: {
            Text(menuBarTitle)
        }
        .menuBarExtraStyle(.window)
    }

    /// Compact status shown in the menu bar, e.g. `Copilot 278 / 7500`.
    /// Prefixed with a warning sign once usage is near or over the allowance.
    private var menuBarTitle: String {
        guard viewModel.lastUpdated != nil else { return "Copilot …" }
        let ratio = settings.allowanceCredits > 0 ? viewModel.usedInPeriod / settings.allowanceCredits : 0
        let prefix = ratio >= 0.9 ? "⚠ " : ""
        return "\(prefix)Copilot \(Format.compact(viewModel.usedInPeriod)) / \(Format.compact(settings.allowanceCredits))"
    }
}
