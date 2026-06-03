import Foundation
import Combine

/// User-configurable settings, persisted to `UserDefaults`.
final class SettingsStore: ObservableObject {
    static let shared = SettingsStore()

    /// Default allowance shown until the user sets their own. A generic per-seat
    /// figure so the app is shareable; each person adjusts it in Settings.
    static let defaultAllowance: Double = 7500

    private enum Keys {
        static let allowance = "copilot.allowanceCredits"
        static let recentLimit = "copilot.recentChatsLimit"
        static let logRootOverride = "copilot.logRootOverride"
        static let settingsVersion = "copilot.settingsVersion"
    }

    /// Bump when default corrections must be force-applied to existing installs.
    private static let currentSettingsVersion = 3

    @Published var allowanceCredits: Double {
        didSet { defaults.set(allowanceCredits, forKey: Keys.allowance) }
    }

    @Published var recentChatsLimit: Int {
        didSet { defaults.set(recentChatsLimit, forKey: Keys.recentLimit) }
    }

    @Published var logRootOverride: String {
        didSet { defaults.set(logRootOverride, forKey: Keys.logRootOverride) }
    }

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.allowanceCredits = (defaults.object(forKey: Keys.allowance) as? Double) ?? SettingsStore.defaultAllowance
        self.recentChatsLimit = (defaults.object(forKey: Keys.recentLimit) as? Int) ?? 20
        self.logRootOverride = defaults.string(forKey: Keys.logRootOverride) ?? ""

        // One-time reset of the allowance to the current default, clearing any
        // value persisted by an earlier build. Bumping the version re-applies it.
        if defaults.integer(forKey: Keys.settingsVersion) < SettingsStore.currentSettingsVersion {
            self.allowanceCredits = SettingsStore.defaultAllowance
            defaults.set(SettingsStore.defaultAllowance, forKey: Keys.allowance)
            defaults.set(SettingsStore.currentSettingsVersion, forKey: Keys.settingsVersion)
        }
    }
}
