import AppKit

/// Makes the process a menu-bar-only accessory app and kicks off the initial
/// scan as soon as the app finishes launching.
final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        Task { @MainActor in
            MenuBarViewModel.shared.refresh(settings: SettingsStore.shared)
            MenuBarViewModel.shared.startWatching(settings: SettingsStore.shared)
        }
    }
}
