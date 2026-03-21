import Foundation
import Observation

@MainActor
@Observable
final class HomeViewModel {
    var latestVideos: [MediaDisplayItem] = []
    var latestShows: [MediaDisplayItem] = []
    var isLoading = false
    var errorMessage: String?

    @ObservationIgnored private var loadTask: Task<Void, Never>?

    var hasContent: Bool {
        !latestVideos.isEmpty || !latestShows.isEmpty
    }

    func load() async {
        guard latestVideos.isEmpty, latestShows.isEmpty else { return }
        await reload()
    }

    func reload() async {
        loadTask?.cancel()

        let task = Task { [weak self] in
            guard let self else { return }
            await fetchContent()
        }
        loadTask = task
        await task.value
    }

    private func fetchContent() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            async let videosResponse = ApiClient.fetchMenu(urlPath: "/FMovies/latestd")
            async let showsResponse = ApiClient.fetchMenu(urlPath: "/FSeries/latestd")

            let (videos, shows) = try await (videosResponse, showsResponse)

            guard !Task.isCancelled else { return }

            latestVideos = videos.items.compactMap { MediaDisplayItem(from: $0) }
            latestShows = shows.items.compactMap { MediaDisplayItem(from: $0) }
        } catch {
            guard !Task.isCancelled else { return }
            latestVideos = []
            latestShows = []
            errorMessage = error.localizedDescription
        }
    }
}
