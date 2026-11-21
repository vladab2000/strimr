import Foundation

/// Stav aplikace, který se obnoví po novém spuštění (poslední záložka, vybraný kanál a pořad)
enum AppStateStore {
    private static let defaults = UserDefaults.standard
    private static let lastTabKey = "strimr.state.lastTab"
    private static let lastChannelKey = "strimr.state.lastChannelId"
    private static let lastProgramStartKey = "strimr.state.lastProgramStart"

    static var lastTab: String? {
        get { defaults.string(forKey: lastTabKey) }
        set { defaults.set(newValue, forKey: lastTabKey) }
    }

    /// Kanál naposledy vybraný v Živém vysílání (fokus v EPG na tvOS, výběr na iOS / macOS)
    static var lastChannelId: String? {
        get { defaults.string(forKey: lastChannelKey) }
        set { defaults.set(newValue, forKey: lastChannelKey) }
    }

    /// Začátek pořadu s fokusem v EPG (tvOS) — spolu s lastChannelId určuje pořad, na který se fokus vrátí
    static var lastProgramStart: Date? {
        get { defaults.object(forKey: lastProgramStartKey) as? Date }
        set { defaults.set(newValue, forKey: lastProgramStartKey) }
    }
}
