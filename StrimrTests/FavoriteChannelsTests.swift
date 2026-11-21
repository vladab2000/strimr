import Foundation
import Testing
@testable import Strimr_macOS

struct FavoriteChannelsTests {
    private func favorite(_ id: String, _ provider: ProviderType) -> FavoriteChannel {
        FavoriteChannel(channelId: id, provider: provider, name: id)
    }

    @Test func favoritesKeepSettingsOrderAndSkipMissingChannels() {
        let channels = ["1", "2", "3", "4"].map { Fixtures.media(id: $0, kind: .channel) }
        let favorites = [favorite("3", .onePlay), favorite("9", .antikTV), favorite("1", .antikTV)]

        let ordered = ChannelManager.orderedFavorites(channels, favorites: favorites)

        #expect(ordered.map(\.id) == ["3", "1"])
    }

    @Test func favoritesAreSentToServerAsNone() {
        #expect(ProviderType.favorites.api == .none)
        #expect(ProviderType.onePlay.api == .onePlay)
        #expect(!ProviderType.serverProviders.contains(.favorites))
        #expect(ProviderType.selectableCases.contains(.favorites))
    }

    @Test func settingsWithoutFavoritesDecode() throws {
        let data = Data(#"{"tvProvider":3}"#.utf8)
        let settings = try JSONDecoder().decode(AppSettings.self, from: data)
        #expect(settings.tvProvider == .onePlay)
        #expect(settings.favoriteChannels.isEmpty)
    }
}

struct ArtURLTests {
    private func media(art: [String: String]) -> Media {
        Media(kind: .program, id: "p", name: "P", description: nil, url: "", art: art, details: nil,
              watchPosition: nil, watchCompleted: nil, isFavorite: nil, updatedUtc: nil)
    }

    @Test func sizeTemplateIsReplacedPerUsage() {
        let m = media(art: [
            "thumb": "https://cdn.example/r{WIDTH}x{HEIGHT}n/abc",
            "logo": "https://cdn.example/r{WIDTH}x{HEIGHT}n/logo",
        ])
        #expect(m.thumbURL?.absoluteString == "https://cdn.example/r960x540n/abc")
        #expect(m.heroImageURL?.absoluteString == "https://cdn.example/r1920x1080n/abc")
        #expect(m.logoURL?.absoluteString == "https://cdn.example/r0x240n/logo")
    }

    @Test func serverPathResolvesAgainstServer() {
        let m = media(art: ["logo": "/logos/abc.png"])
        #expect(m.logoURL?.host() == ApiClient.baseURL.host())
        #expect(m.logoURL?.path() == "/logos/abc.png")
    }
}
