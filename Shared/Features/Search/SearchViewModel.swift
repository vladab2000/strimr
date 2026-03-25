import Foundation
import Observation

enum SearchFilter: String, CaseIterable, Identifiable {
    case movies
    case shows

    var id: String {
        rawValue
    }

    var title: String {
        switch self {
        case .movies:
            String(localized: "search.filter.movies")
        case .shows:
            String(localized: "search.filter.shows")
        }
    }

    var systemImageName: String {
        switch self {
        case .movies:
            "film.fill"
        case .shows:
            "tv.fill"
        }
    }

    func matches(_ type: SCItemType) -> Bool {
        switch self {
        case .movies:
            type == .movie
        case .shows:
            type == .tvshow || type == .season || type == .episode
        }
    }

    var menuPath: String {
        switch self {
        case .movies:
            "/FMovies/search"
        case .shows:
            "/FSeries/search"
        }
    }
}

@MainActor
@Observable
final class SearchViewModel {
    var query: String = ""
    var items: [Media] = []
    var isLoading = false
    var errorMessage: String?
    var activeFilter: SearchFilter = .movies

    @ObservationIgnored private var searchTask: Task<Void, Never>?

    deinit {
        searchTask?.cancel()
    }

    var filteredItems: [Media] {
        items
    }

    var hasQuery: Bool {
        !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    func queryDidChange() {
        scheduleSearch(immediate: false)
    }

    func filterDidChange() {
        guard hasQuery else { return }
        scheduleSearch(immediate: true)
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

        do {
            let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
            let urlPath = activeFilter.menuPath + "?search=" + (trimmedQuery.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? trimmedQuery)
            let result = try await ApiClient.fetchMenu(urlPath: urlPath)
            guard !Task.isCancelled else { return }
            items = result.filter { $0.itemType.isSupported }
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
