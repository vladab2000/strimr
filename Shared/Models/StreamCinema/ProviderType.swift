import Foundation

enum ProviderType: Int, CaseIterable, Identifiable, Codable {
    case none = 0
    case antikTV = 1
    case antikWebTV = 2
    case onePlay = 3
    case sweetTV = 4
    /// Jen v klientovi: oblíbené kanály, každý od zvoleného poskytovatele (AppSettings.favoriteChannels).
    /// Serveru se posílá jako .none (viz api).
    case favorites = 100

    var id: Int { rawValue }

    var displayName: String {
        switch self {
        case .none: String(localized: "provider.none")
        case .antikTV: String(localized: "provider.antikTV")
        case .antikWebTV: String(localized: "provider.antikWebTV")
        case .onePlay: String(localized: "provider.onePlay")
        case .sweetTV: String(localized: "provider.sweetTV")
        case .favorites: String(localized: "provider.favorites")
        }
    }

    /// Providers available for user selection (excludes .none; AntikWebTV jen doplňuje program na serveru, nepřehrává)
    static var selectableCases: [ProviderType] {
        allCases.filter { $0 != .none && $0 != .antikWebTV }
    }

    /// Skuteční poskytovatelé serveru, od kterých jde přehrávat (bez .none, AntikWebTV a oblíbených)
    static var serverProviders: [ProviderType] {
        allCases.filter { $0 != .none && $0 != .antikWebTV && $0 != .favorites }
    }

    /// Hodnota pro server — oblíbené server nezná (.none = všichni poskytovatelé / podle priority)
    var api: ProviderType {
        self == .favorites ? .none : self
    }
}
