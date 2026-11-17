import Testing
@testable import Strimr_macOS

@MainActor
struct SeriesNavigatorTests {
    @Test func noHistoryNoContinuePoint() {
        #expect(SeriesNavigator.continuePoint(from: []) == nil)
    }

    @Test func startedEpisodeIsResumed() {
        let history = [Fixtures.episode("e5", season: 2, episode: 5, watched: false, position: 600)]
        #expect(SeriesNavigator.continuePoint(from: history) == .init(season: 2, episode: 5, isResume: true))
    }

    @Test func watchedEpisodeContinuesWithNext() {
        // Nejnovější záznam je první
        let history = [
            Fixtures.episode("e5", season: 2, episode: 5, watched: true, position: 2500),
            Fixtures.episode("e4", season: 2, episode: 4, watched: false, position: 300),
        ]
        #expect(SeriesNavigator.continuePoint(from: history) == .init(season: 2, episode: 5, isResume: false))
    }

    @Test func historyWithoutEpisodeNumbersIsIgnored() {
        let history = [
            Fixtures.episode("bez-cisla", season: nil, episode: nil, watched: true),
            Fixtures.episode("e3", season: 1, episode: 3, watched: true),
        ]
        #expect(SeriesNavigator.continuePoint(from: history)?.episode == 3)
    }

    @Test func episodeForResumeAndNext() {
        let episodes = [1, 2, 4, 3].map { (number: Int) in Fixtures.episode("e\(number)", season: 1, episode: number) }
        #expect(SeriesNavigator.episode(for: .init(season: 1, episode: 2, isResume: true), in: episodes)?.id == "e2")
        // Další díl = nejbližší vyšší číslo, i když seznam není seřazený
        #expect(SeriesNavigator.episode(for: .init(season: 1, episode: 2, isResume: false), in: episodes)?.id == "e3")
        #expect(SeriesNavigator.episode(for: .init(season: 1, episode: 4, isResume: false), in: episodes) == nil)
    }

    @Test func seasonAfterPicksNearestHigher() {
        let seasons = [Fixtures.season(3), Fixtures.season(1), Fixtures.season(2)]
        #expect(SeriesNavigator.season(after: 1, in: seasons)?.season == 2)
        #expect(SeriesNavigator.season(after: 3, in: seasons) == nil)
    }
}
