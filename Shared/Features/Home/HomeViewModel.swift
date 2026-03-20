import Foundation
import Observation

@MainActor
@Observable
final class HomeViewModel {
    var latestVideos: [any MediaItem] = []
    var latestSeries: [any MediaItem] = []
    var isLoading = false
    var errorMessage: String?

    @ObservationIgnored private var loadTask: Task<Void, Never>?

    var hasContent: Bool {
        !latestVideos.isEmpty || !latestSeries.isEmpty
    }

    func load() async {
        guard latestVideos.isEmpty, latestSeries.isEmpty else { return }
        await reload()
    }

    func reload() async {
        loadTask?.cancel()

        let task = Task { [weak self] in
            guard let self else { return }
            await fetchData()
        }
        loadTask = task
        await task.value
    }

    private func fetchData() async {
        isLoading = true
        errorMessage = nil
        defer {
            isLoading = false
        }

        do {
            async let videosResponse = ApiClient.fetchMenu(urlPath: "/FMovies/latestd")
            async let seriesResponse = ApiClient.fetchMenu(urlPath: "/FSeries/latestd")

            let videos = try await videosResponse
            let series = try await seriesResponse

            guard !Task.isCancelled else { return }

            latestVideos = videos.items
            latestSeries = series.items
        } catch {
            guard !Task.isCancelled else { return }
            errorMessage = error.localizedDescription
        }
    }
}
