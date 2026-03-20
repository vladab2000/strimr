import Foundation
import Observation

@MainActor
@Observable
final class StreamCinemaSearchViewModel {
    var query: String = ""
    var items: [any MediaItem] = []
    var isLoading = false
    var errorMessage: String?

    @ObservationIgnored private var searchTask: Task<Void, Never>?

    deinit {
        searchTask?.cancel()
    }

    var hasQuery: Bool {
        !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    func queryDidChange() {
        scheduleSearch(immediate: false)
    }

    func submitSearch() {
        scheduleSearch(immediate: true)
    }

    private func scheduleSearch(immediate: Bool) {
        searchTask?.cancel()

        guard hasQuery else {
            resetState()
            return
        }

        searchTask = Task { [weak self] in
            if !immediate {
                try? await Task.sleep(nanoseconds: 350_000_000)
            }

            guard !Task.isCancelled else { return }
            await self?.performSearch()
        }
    }

    private func performSearch() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        let searchPath = "/FSearch/\(trimmed)"

        do {
            let response = try await ApiClient.fetchMenu(urlPath: searchPath)
            guard !Task.isCancelled else { return }
            items = response.items
        } catch {
            guard !Task.isCancelled else { return }
            items = []
            errorMessage = error.localizedDescription
        }
    }

    private func resetState(error: String? = nil) {
        items = []
        errorMessage = error
        isLoading = false
    }
}
