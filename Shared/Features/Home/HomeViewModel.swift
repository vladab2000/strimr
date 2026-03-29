import Foundation
import Observation

@MainActor
@Observable
final class HomeViewModel {
    var latestVideos: [Media] = []
    var latestShows: [Media] = []
    var continueWatching: [Media] = []
    var isLoading = false
    var errorMessage: String?

    var watchHistoryManager: WatchHistoryManager?

    @ObservationIgnored private var loadTask: Task<Void, Never>?

    var hasContent: Bool {
        !latestVideos.isEmpty || !latestShows.isEmpty || !continueWatching.isEmpty
    }

    func load() async {
        await loadContinueWatching()
        guard latestVideos.isEmpty, latestShows.isEmpty else { return }
        await reload()
    }

    func reload() async {
        loadTask?.cancel()
        await loadContinueWatching()

        let task = Task { [weak self] in
            guard let self else { return }
            await fetchContent()
        }
        loadTask = task
        await task.value
    }

    func refreshWatchStatus() {
        continueWatching = watchHistoryManager?.continueWatching ?? []
        if let manager = watchHistoryManager {
            latestVideos = manager.applyWatchOverrides(to: latestVideos)
            latestShows = manager.applyWatchOverrides(to: latestShows)
        }
    }

    private func loadContinueWatching() async {
        await watchHistoryManager?.load()
        continueWatching = watchHistoryManager?.continueWatching ?? []
    }

    private func fetchContent() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            async let videosResult = ApiClient.fetchMenu(urlPath: "/FMovies/latestd")
            async let showsResult = ApiClient.fetchMenu(urlPath: "/FSeries/latestd")

            let (videos, shows) = try await (videosResult, showsResult)

            guard !Task.isCancelled else { return }

            latestVideos = videos.filter { $0.itemType.isSupported }
            latestShows = shows.filter { $0.itemType.isSupported }
        } catch {
            guard !Task.isCancelled else { return }
            latestVideos = []
            latestShows = []
            errorMessage = error.localizedDescription
        }
    }
}
