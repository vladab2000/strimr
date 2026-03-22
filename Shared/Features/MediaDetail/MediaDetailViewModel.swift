import Foundation
import Observation

@MainActor
@Observable
final class MediaDetailViewModel {
    var media: MediaDisplayItem
    var isLoading = false
    var errorMessage: String?
    var seasons: [MediaDisplayItem] = []
    var episodes: [MediaDisplayItem] = []
    var selectedSeasonId: String?
    var isLoadingSeasons = false
    var isLoadingEpisodes = false

    init(media: MediaDisplayItem) {
        self.media = media
    }

    var heroImageURL: URL? {
        media.bannerURL
    }

    var runtimeText: String? {
        guard let duration = media.duration else { return nil }
        return duration.mediaDurationText()
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

    var selectedSeasonTitle: String {
        guard let selectedSeasonId else {
            return String(localized: "media.detail.season")
        }
        return seasons.first(where: { $0.id == selectedSeasonId })?.title
            ?? String(localized: "media.detail.season")
    }

    func loadDetails() async {
        guard media.type == .tvshow else { return }
        await fetchSeasons()
    }

    func selectSeason(id: String) async {
        guard selectedSeasonId != id else { return }
        selectedSeasonId = id
        episodes = []
        await fetchEpisodes(for: id)
    }
    
    func progressFraction(for item: MediaDisplayItem) -> Double? {
/*        guard let percentage = item.viewProgressPercentage else { return nil }
        return min(1, max(0, percentage / 100))*/
        return nil
    }

    private func fetchSeasons() async {
        guard let urlPath = media.url else { return }

        isLoadingSeasons = true
        defer { isLoadingSeasons = false }

        do {
            let response = try await ApiClient.fetchMenu(urlPath: urlPath)
            let fetchedSeasons = response.items
                .compactMap { MediaDisplayItem(from: $0) }
                .filter { $0.type == .season }
            
            if fetchedSeasons.isEmpty {
                let season = Season.create(from: media.tvShow)
                seasons = [.season(season)]

                let fetchedEpisodes = response.items
                    .compactMap { MediaDisplayItem(from: $0) }
                    .filter { $0.type == .episode }
                
                episodes = fetchedEpisodes
            }

            let firstSeasonId = seasons.first?.id
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
        guard let season = seasons.first(where: { $0.id == seasonId }),
              let urlPath = season.url
        else { return }

        isLoadingEpisodes = true
        defer { isLoadingEpisodes = false }

        do {
            let response = try await ApiClient.fetchMenu(urlPath: urlPath)
            let fetchedEpisodes = response.items.compactMap { MediaDisplayItem(from: $0) }

            guard selectedSeasonId == seasonId else { return }
            episodes = fetchedEpisodes
        } catch {
            if selectedSeasonId == seasonId {
                episodes = []
            }
        }
    }
}
