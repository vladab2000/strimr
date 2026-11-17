import Foundation

/// Pořadí epizod seriálu napříč sezónami — další díl a místo, kde se ve sledování pokračuje
enum SeriesNavigator {
    /// Kde pokračovat podle historie sledování seriálu
    struct ContinuePoint: Equatable {
        let season: Int
        let episode: Int
        /// true = rozkoukaná epizoda; false = další díl po naposledy dokoukané (episode je ta dokoukaná)
        let isResume: Bool
    }

    /// Z historie seriálu (nejnovější záznam první): rozkoukaná epizoda, jinak díl po naposledy dokoukaném
    static func continuePoint(from history: [Media]) -> ContinuePoint? {
        guard let last = history.first(where: { $0.season != nil && $0.episode != nil }),
              let season = last.season, let episode = last.episode else { return nil }
        let isResume = last.watchCompleted != true && (last.watchPosition ?? 0) > 0
        return ContinuePoint(season: season, episode: episode, isResume: isResume)
    }

    /// Epizoda v seznamu sezóny: rozkoukaná, nebo první s vyšším číslem než dokoukaná
    static func episode(for point: ContinuePoint, in episodes: [Media]) -> Media? {
        if point.isResume {
            return episodes.first { $0.episode == point.episode }
        }
        return episodes
            .filter { ($0.episode ?? 0) > point.episode }
            .min { ($0.episode ?? 0) < ($1.episode ?? 0) }
    }

    /// Sezóna, která následuje po dané (nejbližší vyšší číslo)
    static func season(after number: Int, in seasons: [Media]) -> Media? {
        seasons
            .filter { ($0.season ?? 0) > number }
            .min { ($0.season ?? 0) < ($1.season ?? 0) }
    }

    /// Další díl po epizodě (stejná sezóna, jinak první díl další sezóny). Potřebuje vazbu na seriál
    /// (Media.parentUrl), kterou epizoda dostane v detailu seriálu.
    static func nextEpisode(after episode: Media) async -> Media? {
        guard let parentUrl = episode.parentUrl,
              let seasonNumber = episode.season,
              let episodeNumber = episode.episode,
              let items = try? await ApiClient.fetchMenu(urlPath: parentUrl) else { return nil }

        let point = ContinuePoint(season: seasonNumber, episode: episodeNumber, isResume: false)
        let parent = items.first { $0.itemType == .tvshow }
        let seasons = items.filter { $0.itemType == .season }

        func linked(_ next: Media?) -> Media? {
            guard let next else { return nil }
            var copy = next
            copy.parentId = episode.parentId ?? parent?.id
            copy.parentUrl = parentUrl
            return copy
        }

        // Seriál bez sezón — epizody přímo v seriálu
        if seasons.isEmpty {
            return linked(Self.episode(for: point, in: items.filter { $0.itemType == .episode }))
        }

        if let season = seasons.first(where: { $0.season == seasonNumber }),
           let next = Self.episode(for: point, in: await episodes(of: season)) {
            return linked(next)
        }

        guard let nextSeason = season(after: seasonNumber, in: seasons) else { return nil }
        return linked(await episodes(of: nextSeason).min { ($0.episode ?? 0) < ($1.episode ?? 0) })
    }

    private static func episodes(of season: Media) async -> [Media] {
        let items = (try? await ApiClient.fetchMenu(urlPath: season.url)) ?? []
        return items.filter { $0.itemType == .episode }
    }
}
