import Foundation
import Testing
@testable import Strimr_macOS

@MainActor
struct MediaDetailHeroTests {
    private let series = Media(
        kind: .tvshow, id: "bombuj:series:silo", name: "Silo", description: "Popis seriálu", url: "/bombuj/series/silo",
        art: ["clearlogo": "logo.png", "fanart": "fanart.jpg"],
        details: .playable(PlayableMediaDetails(
            year: 2023, rating: 8.1, duration: nil, langs: nil, genres: ["Sci-Fi"], country: nil,
            season: nil, seasonTitle: nil, episode: nil, episodeTitle: nil, streams: nil,
        )),
        watchPosition: nil, watchCompleted: nil, isFavorite: nil, updatedUtc: nil,
    )

    @Test func seasonShowsSeriesTitleAndDescription() {
        let hero = MediaDetailViewModel(media: series).heroMedia(for: Fixtures.season(2))
        #expect(hero.primaryLabel == "Silo")
        #expect(hero.summary == "Popis seriálu")
        #expect(hero.year == 2023)
        #expect(hero.genres == ["Sci-Fi"])
        #expect(hero.clearlogoURL?.absoluteString == "logo.png")
        #expect(hero.secondaryLabel == "Sezóna 2")
    }

    @Test func episodeKeepsOwnDescriptionAndShowsIdentifier() {
        var episode = Fixtures.episode("e1", season: 1, episode: 2)
        episode = Media(
            kind: .episode, id: episode.id, name: "S01E02", description: "Popis dílu", url: episode.url, art: nil,
            details: episode.details, watchPosition: nil, watchCompleted: nil, isFavorite: nil, updatedUtc: nil,
        )
        let hero = MediaDetailViewModel(media: series).heroMedia(for: episode)
        #expect(hero.primaryLabel == "Silo")
        #expect(hero.summary == "Popis dílu")
        // "S01E02" v name není název dílu
        #expect(hero.secondaryLabel == "S01E02")
    }
}
