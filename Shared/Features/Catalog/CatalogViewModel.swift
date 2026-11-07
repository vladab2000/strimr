import Foundation
import Observation

/// Stránka Filmy / Seriály: řada dlaždic pro každý zdroj (Bombuj, uzi.la) s filtrem kategorie a jazyka.
/// Filtr je společný pro obě stránky (uložený v nastavení).
@MainActor
@Observable
final class CatalogViewModel {
    enum Kind {
        case movies
        case shows

        var title: String {
            switch self {
            case .movies: "Filmy"
            case .shows: "Seriály"
            }
        }

        func path(for source: ContentSource) -> String {
            switch self {
            case .movies: source.moviesPath
            case .shows: source.showsPath
            }
        }
    }

    struct Row: Identifiable {
        let source: ContentSource
        var items: [Media]

        var id: String { source.rawValue }
        var title: String { source.displayName }
    }

    /// Zdroje v pořadí řad na stránce
    static let sources: [ContentSource] = [.bombuj, .uzi]

    let kind: Kind
    var rows: [Row] = []
    var genres: [CatalogGenre] = []
    var isLoading = false
    var errorMessage: String?

    var watchHistoryManager: WatchHistoryManager?

    @ObservationIgnored private let settingsManager: SettingsManager
    @ObservationIgnored private var loadTask: Task<Void, Never>?
    /// Filtr, se kterým jsou načtené řady (druhá stránka mohla filtr mezitím změnit)
    @ObservationIgnored private var loadedFilter: CatalogFilter?

    init(kind: Kind, settingsManager: SettingsManager) {
        self.kind = kind
        self.settingsManager = settingsManager
    }

    var catalogFilter: CatalogFilter {
        settingsManager.catalogFilter
    }

    var hasContent: Bool {
        rows.contains { !$0.items.isEmpty }
    }

    func load() async {
        await loadGenres()
        guard rows.isEmpty || loadedFilter != settingsManager.catalogFilter else { return }
        await reload()
    }

    func reload() async {
        loadTask?.cancel()
        let task = Task { [weak self] in
            guard let self else { return }
            await fetchRows()
        }
        loadTask = task
        await task.value
    }

    /// Změna kategorie / jazyka — uloží se do nastavení a řady se načtou znovu
    func setCatalogFilter(_ filter: CatalogFilter) {
        guard filter != settingsManager.catalogFilter else { return }
        settingsManager.setCatalogFilter(filter)
        Task { await reload() }
    }

    func refreshWatchStatus() {
        guard let manager = watchHistoryManager else { return }
        rows = rows.map { Row(source: $0.source, items: manager.applyWatchOverrides(to: $0.items)) }
    }

    /// Kategorie, které umí aspoň jeden ze zdrojů; neznámá uložená kategorie se zruší
    private func loadGenres() async {
        guard genres.isEmpty else { return }
        guard let loaded = try? await ApiClient.fetchCatalogGenres(source: .all) else { return }
        genres = loaded

        var filter = settingsManager.catalogFilter
        if let genre = filter.genre, !loaded.contains(where: { $0.id == genre }) {
            filter.genre = nil
            settingsManager.setCatalogFilter(filter)
        }
    }

    private func fetchRows() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        let filter = settingsManager.catalogFilter
        let kind = kind

        // Zdroje paralelně; výpadek jednoho nesmí shodit ostatní řady
        let results = await withTaskGroup(of: (Int, Result<[Media], Error>).self) { group in
            for (index, source) in Self.sources.enumerated() {
                group.addTask {
                    do {
                        let items = try await ApiClient.fetchMenu(urlPath: filter.apply(to: kind.path(for: source)))
                        return (index, .success(items))
                    } catch {
                        return (index, .failure(error))
                    }
                }
            }
            var results = [Int: Result<[Media], Error>]()
            for await (index, result) in group {
                results[index] = result
            }
            return results
        }

        guard !Task.isCancelled else { return }

        rows = Self.sources.enumerated().map { index, source in
            let items = (try? results[index]?.get()) ?? []
            return Row(source: source, items: items.filter { $0.itemType.isSupported })
        }
        loadedFilter = filter

        if results.values.allSatisfy({ if case .failure = $0 { true } else { false } }),
           case let .failure(error)? = results[0]
        {
            errorMessage = error.localizedDescription
        }
        refreshWatchStatus()
    }
}
