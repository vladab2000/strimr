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

    @ObservationIgnored private let settingsManager: SettingsManager
    @ObservationIgnored private var loadTask: Task<Void, Never>?

    init(settingsManager: SettingsManager) {
        self.settingsManager = settingsManager
    }

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
            let source = settingsManager.contentSource
            let (videos, shows) = try await fetchForSource(source)

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

    private func fetchForSource(_ source: ContentSource) async throws -> ([Media], [Media]) {
        switch source {
        case .streamCinema:
            async let videos = ApiClient.fetchMenu(urlPath: source.moviesPath)
            async let shows = ApiClient.fetchMenu(urlPath: source.showsPath)
            return try await (videos, shows)

        case .bombuj, .uzi:
            async let videos = ApiClient.fetchMenu(urlPath: source.moviesPath)
            async let shows = ApiClient.fetchMenu(urlPath: source.showsPath)
            return try await (videos, shows)

        case .all:
            async let scVideos = ApiClient.fetchMenu(urlPath: ContentSource.streamCinema.moviesPath)
            async let scShows = ApiClient.fetchMenu(urlPath: ContentSource.streamCinema.showsPath)
            async let bombujVideos = ApiClient.fetchMenu(urlPath: source.bombujMoviesPath)
            async let bombujShows = ApiClient.fetchMenu(urlPath: source.bombujShowsPath)
            async let uziVideos = ApiClient.fetchMenu(urlPath: source.uziMoviesPath)
            async let uziShows = ApiClient.fetchMenu(urlPath: source.uziShowsPath)
            let (v1, s1, v2, s2, v3, s3) = try await (scVideos, scShows, bombujVideos, bombujShows, uziVideos, uziShows)
            return (v1 + v2 + v3, s1 + s2 + s3)
        }
    }
}
