import Foundation

/// Oblíbený kanál a poskytovatel, od kterého se přehrává (kanály lze kombinovat z různých poskytovatelů)
struct FavoriteChannel: Codable, Hashable, Identifiable {
    let channelId: String
    var provider: ProviderType
    /// Název pro seznam v nastavení (bez načítání kanálů)
    var name: String

    var id: String { channelId }
}
