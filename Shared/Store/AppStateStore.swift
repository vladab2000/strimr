import Foundation

/// Stav aplikace, který se obnoví po novém spuštění (poslední záložka, vybraný kanál)
enum AppStateStore {
    private static let defaults = UserDefaults.standard
    private static let lastTabKey = "strimr.state.lastTab"
    private static let lastChannelKey = "strimr.state.lastChannelId"

    static var lastTab: String? {
        get { defaults.string(forKey: lastTabKey) }
        set { defaults.set(newValue, forKey: lastTabKey) }
    }

    /// Kanál naposledy vybraný v Živém vysílání (fokus v EPG na tvOS, výběr na iOS / macOS)
    static var lastChannelId: String? {
        get { defaults.string(forKey: lastChannelKey) }
        set { defaults.set(newValue, forKey: lastChannelKey) }
    }
}
