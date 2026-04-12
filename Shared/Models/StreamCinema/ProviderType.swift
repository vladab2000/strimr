import Foundation

enum ProviderType: Int, CaseIterable, Identifiable, Codable {
    case none = 0
    case antikTV = 1
    case antikWebTV = 2
    case onePlay = 3
    case sweetTV = 4

    var id: Int { rawValue }

    var displayName: String {
        switch self {
        case .none: String(localized: "provider.none")
        case .antikTV: String(localized: "provider.antikTV")
        case .antikWebTV: String(localized: "provider.antikWebTV")
        case .onePlay: String(localized: "provider.onePlay")
        case .sweetTV: String(localized: "provider.sweetTV")
        }
    }

    /// Providers available for user selection (excludes .none)
    static var selectableCases: [ProviderType] {
        allCases.filter { $0 != .none }
    }
}
