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

    init(media: Media) {
        self.media = media
    }

    var heroImageURL: URL? {
        media.bannerURL
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

    var selectedSeasonTitle: String {
        guard let selectedSeasonId else {
            return String(localized: "media.detail.season")
        }
        return seasons.first(where: { $0.id == selectedSeasonId })?.title
            ?? String(localized: "media.detail.season")
    }

    func loadDetails() async {
        guard media.itemType == .tvshow else { return }
        await fetchSeasons()
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

    private func fetchSeasons() async {
        guard let urlPath = media.url else { return }

        isLoadingSeasons = true
        defer { isLoadingSeasons = false }

        do {
            let items = try await ApiClient.fetchMenu(urlPath: urlPath)
            let fetchedSeasons = items
                .filter { $0.itemType == .season }
            
            if fetchedSeasons.isEmpty {
                let season = Media.createSeason(from: media)
                seasons = [season]

                let fetchedEpisodes = items
                    .filter { $0.itemType == .episode }
                
                episodes = fetchedEpisodes
            } else {
                seasons = fetchedSeasons
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
            let items = try await ApiClient.fetchMenu(urlPath: urlPath)
            let fetchedEpisodes = items.filter { $0.itemType.isSupported }

            guard selectedSeasonId == seasonId else { return }
            episodes = fetchedEpisodes
        } catch {
            if selectedSeasonId == seasonId {
                episodes = []
            }
        }
    }
}
