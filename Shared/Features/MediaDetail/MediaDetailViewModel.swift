import Foundation
import Observation

@MainActor
@Observable
final class MediaDetailViewModel {
    var media: Media
    var isLoading = false
    var errorMessage: String?
    var seasons: [Media] = []
    var episodes: [Media] = []
    var selectedSeasonId: String?
    var isLoadingSeasons = false
    var isLoadingEpisodes = false

    /// Seriál: kde pokračovat podle historie sledování a odpovídající epizoda
    var continuePoint: SeriesNavigator.ContinuePoint?
    var continueEpisode: Media?

    init(media: Media) {
        self.media = media
    }

    var heroImageURL: URL? {
        media.artURL("banner", width: Media.ArtSize.hero.width, height: Media.ArtSize.hero.height)
    }

    var runtimeText: String? {
        media.durationText
    }
    
    var yearText: String? {
        media.year.map(String.init)
    }

    var ratingText: String? {
        media.rating.map { String(format: "%.1f", $0) }
    }

    var genresText: String? {
        guard let genres = media.genres, !genres.isEmpty else { return nil }
        return genres.joined(separator: ", ")
    }

    var selectedSeason: Media? {
        guard let selectedSeasonId else { return nil }
        return seasons.first(where: { $0.id == selectedSeasonId })
    }

    /// Hlavička detailu seriálu pro sezónu nebo díl: název (a logo) seriálu, pod ním sezóna / "S01E02 - Název dílu",
    /// popis dílu či sezóny, jinak seriálu; rok, hodnocení a žánry ze seriálu, pokud je položka nemá
    func heroMedia(for item: Media) -> Media {
        guard media.itemType == .tvshow, item.itemType == .season || item.itemType == .episode else { return item }

        // Název dílu — u některých zdrojů je jen v name (jinak name = název seriálu nebo "S01E02")
        let episodeTitle = item.episodeTitle.flatMap { $0.isEmpty ? nil : $0 }
            ?? (item.itemType == .episode && item.name != media.name && item.name != item.episodeIdentifier ? item.name : nil)

        var art = media.art ?? [:]
        for (key, value) in item.art ?? [:] where key != "clearlogo" {
            art[key] = value
        }

        let details = PlayableMediaDetails(
            year: item.year ?? media.year,
            rating: item.rating ?? media.rating,
            duration: item.duration,
            langs: item.langs ?? media.langs,
            genres: item.genres.flatMap { $0.isEmpty ? nil : $0 } ?? media.genres,
            country: item.country ?? media.country,
            season: item.season,
            seasonTitle: item.seasonTitle ?? (item.itemType == .season ? item.name : nil),
            episode: item.episode,
            episodeTitle: episodeTitle,
            streams: nil,
        )

        var hero = Media(
            kind: item.kind,
            id: item.id,
            name: media.name,
            description: item.description.flatMap { $0.isEmpty ? nil : $0 } ?? media.description,
            url: item.url,
            art: art.isEmpty ? nil : art,
            details: .playable(details),
            watchPosition: item.watchPosition,
            watchCompleted: item.watchCompleted,
            isFavorite: item.isFavorite,
            updatedUtc: item.updatedUtc,
        )
        hero.parentId = item.parentId
        return hero
    }

    var selectedSeasonTitle: String {
        selectedSeason?.title ?? String(localized: "media.detail.season")
    }

    func loadDetails() async {
        guard media.itemType == .tvshow else { return }
        async let history = try? ApiClient.fetchSeriesWatch(seriesId: media.id)
        continuePoint = SeriesNavigator.continuePoint(from: await history ?? [])
        await fetchSeasons()
        await resolveContinueEpisode()
    }

    /// "Pokračovat S02E05" (rozkoukaná) / "Další díl S02E06"
    var continueTitle: String? {
        guard let continuePoint, let continueEpisode,
              let identifier = continueEpisode.episodeIdentifier else { return nil }
        return String(format: String(localized: continuePoint.isResume ? "media.detail.continue" : "media.detail.nextEpisode"), identifier)
    }

    /// "Zhlédnuto 3 z 10" pro vybranou sezónu
    var watchedEpisodesText: String? {
        guard !episodes.isEmpty else { return nil }
        let watched = episodes.filter { $0.watchCompleted == true }.count
        guard watched > 0 else { return nil }
        return String(format: String(localized: "media.detail.watchedEpisodes"), watched, episodes.count)
    }

    func selectSeason(id: String) async {
        guard selectedSeasonId != id else { return }
        selectedSeasonId = id
        episodes = []
        await fetchEpisodes(for: id)
    }
    
    func progressFraction(for item: Media) -> Double? {
        item.progressFraction
    }

    /// Epizoda, na kterou jde fokus: kde se pokračuje, jinak první nedokoukaná
    var firstUnwatchedEpisodeId: String? {
        if let continueEpisode, episodes.contains(where: { $0.id == continueEpisode.id }) {
            return continueEpisode.id
        }
        let episode = episodes.first { $0.watchCompleted != true }
        return episode?.id ?? episodes.last?.id
    }

    /// Najde epizodu pro pokračování; dokoukaný poslední díl sezóny → první díl další sezóny (ta se vybere)
    private func resolveContinueEpisode() async {
        continueEpisode = nil
        guard let point = continuePoint else { return }

        // Seriál bez sezón má jednu sezónu bez čísla
        let isPointSeason = selectedSeason?.season == point.season || (selectedSeason?.season == nil && seasons.count == 1)
        if isPointSeason, let episode = SeriesNavigator.episode(for: point, in: episodes) {
            continueEpisode = episode
            return
        }

        guard !point.isResume, let nextSeason = SeriesNavigator.season(after: point.season, in: seasons) else { return }
        selectedSeasonId = nextSeason.id
        episodes = []
        await fetchEpisodes(for: nextSeason.id)
        continueEpisode = episodes.min { ($0.episode ?? 0) < ($1.episode ?? 0) }
    }

    private func fetchSeasons() async {
        let urlPath = media.url

        isLoadingSeasons = true
        defer { isLoadingSeasons = false }

        do {
            let items = try await ApiClient.fetchMenu(urlPath: urlPath)

            // Server may return an enriched version of the series alongside seasons
            if let enriched = items.first(where: { $0.itemType == .tvshow }) {
                media = enriched
            }

            let fetchedSeasons = items.filter { $0.itemType == .season }

            if fetchedSeasons.isEmpty {
                let season = Media.createSeason(from: media)
                seasons = [season]

                let fetchedEpisodes = items.filter { $0.itemType == .episode }
                episodes = fetchedEpisodes.map { $0.withParent(media) }
            } else {
                seasons = fetchedSeasons
            }

            // Sezóna, ve které se pokračuje ve sledování, jinak první
            let firstSeasonId = (continuePoint.flatMap { point in seasons.first { $0.season == point.season } } ?? seasons.first)?.id
            selectedSeasonId = firstSeasonId

            if !fetchedSeasons.isEmpty {
                if let seasonId = firstSeasonId {
                    await fetchEpisodes(for: seasonId)
                }
            }

        } catch {
            seasons = []
            selectedSeasonId = nil
            episodes = []
            errorMessage = error.localizedDescription
        }
    }

    private func fetchEpisodes(for seasonId: String) async {
        guard let season = seasons.first(where: { $0.id == seasonId }) else { return }
        let urlPath = season.url

        isLoadingEpisodes = true
        defer { isLoadingEpisodes = false }

        do {
            let items = try await ApiClient.fetchMenu(urlPath: urlPath)
            let fetchedEpisodes = items.filter { $0.itemType.isSupported }

            guard selectedSeasonId == seasonId else { return }
            // Vazba na seriál: uloží se s historií sledování (pokračování, další díl)
            episodes = fetchedEpisodes.map { $0.withParent(media) }
        } catch {
            if selectedSeasonId == seasonId {
                episodes = []
            }
        }
    }
}
