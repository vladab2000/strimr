import Foundation
import Observation

enum SearchFilter: String, CaseIterable, Identifiable {
    case movies
    case shows
    case programs

    var id: String {
        rawValue
    }

    var title: String {
        switch self {
        case .movies:
            String(localized: "search.filter.movies")
        case .shows:
            String(localized: "search.filter.shows")
        case .programs:
            String(localized: "search.filter.programs")
        }
    }

    var systemImageName: String {
        switch self {
        case .movies:
            "film.fill"
        case .shows:
            "tv.fill"
        case .programs:
            "play.tv.fill"
        }
    }

    func matches(_ type: SCItemType) -> Bool {
        switch self {
        case .movies:
            type == .movie
        case .shows:
            type == .tvshow || type == .season || type == .episode
        case .programs:
            type == .program || type == .channel
        }
    }

    var apiType: String {
        switch self {
        case .movies:
            "movie"
        case .shows:
            "series"
        case .programs:
            "program"
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
    var activeFilter: SearchFilter?

    @ObservationIgnored private let settingsManager: SettingsManager
    @ObservationIgnored private var searchTask: Task<Void, Never>?

    init(settingsManager: SettingsManager) {
        self.settingsManager = settingsManager
    }

    deinit {
        searchTask?.cancel()
    }

    var filteredItems: [Media] {
        items
    }

    var hasQuery: Bool {
        query.trimmingCharacters(in: .whitespacesAndNewlines).count >= 3
    }

    func queryDidChange() {
        // Only re-search if filter is already selected
        guard activeFilter != nil else { return }
        scheduleSearch(immediate: false)
    }

    func selectFilter(_ filter: SearchFilter) {
        activeFilter = filter
        guard hasQuery else { return }
        scheduleSearch(immediate: true)
    }

    func submitSearch() {
        guard activeFilter != nil else { return }
        scheduleSearch(immediate: true)
    }

    private func scheduleSearch(immediate: Bool) {
        searchTask?.cancel()

        guard hasQuery, activeFilter != nil else {
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
            guard let filter = activeFilter else { return }
            let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)

            let result: [Media]
            if filter == .programs {
                result = try await ApiClient.fetchProgramSearch(
                    text: trimmedQuery,
                    providerType: settingsManager.tvProvider
                )
            } else {
                result = try await ApiClient.fetchSearch(text: trimmedQuery, type: filter.apiType)
            }

            guard !Task.isCancelled else { return }
            items = result
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
