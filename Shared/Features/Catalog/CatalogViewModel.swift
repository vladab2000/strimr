import Foundation
import Observation

/// Stránka Filmy / Seriály: řada dlaždic pro každý zdroj (Bombuj, uzi.la, OnePlay) s filtrem kategorie a jazyka.
/// Filtr je společný pro obě stránky (uložený v nastavení). Řada se načte po první stránce,
/// další stránky se dočítají při rolování (loadMore).
@MainActor
@Observable
final class CatalogViewModel {
    enum Kind {
        case movies
        case shows

        var title: String {
            switch self {
            case .movies: String(localized: "tabs.movies")
            case .shows: String(localized: "tabs.shows")
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
        /// Poslední načtená stránka seznamu
        var page = 1
        var hasMore = true
        var isLoadingMore = false
        /// Zdroj umí vybrané řazení; jinak výchozí pořadí s poznámkou u názvu řady
        var sortSupported = true

        var id: String { source.rawValue }
        var title: String {
            sortSupported ? source.displayName : "\(source.displayName) · \(String(localized: "catalog.sort.unsupported"))"
        }
    }

    /// Zdroje v pořadí řad na stránce (OnePlay jen s nastaveným poskytovatelem na serveru, jinak prázdná řada)
    static let sources: [ContentSource] = [.bombuj, .uzi, .oneplay]

    let kind: Kind
    var rows: [Row] = []
    var genres: [CatalogGenre] = []
    var isLoading = false
    var errorMessage: String?
    /// Zvyšuje se po každém novém načtení řad (změna filtru, obnovení) — řady se vytvoří znovu a začnou první
    /// položkou; dočítání dalších stránek ho nemění
    private(set) var rowsVersion = 0

    var watchHistoryManager: WatchHistoryManager?

    @ObservationIgnored private let settingsManager: SettingsManager
    @ObservationIgnored private var loadTask: Task<Void, Never>?
    /// Filtr, se kterým jsou načtené řady (druhá stránka mohla filtr mezitím změnit)
    @ObservationIgnored private var loadedFilter: CatalogFilter?
    @ObservationIgnored private var loadMoreTasks: [ContentSource: Task<Void, Never>] = [:]
    /// Zvyšuje se při každém novém načtení řad — dočtená stránka ze starého seznamu se zahodí
    @ObservationIgnored private var generation = 0

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

    /// Řazení v menu: jen ta, která umí aspoň jeden zdroj stránky
    var sortOptions: [CatalogSort] {
        let supported = Self.sources.reduce(into: Set<CatalogSort>()) { $0.formUnion($1.supportedSorts(series: kind == .shows)) }
        return CatalogSort.allCases.filter(supported.contains)
    }

    func load() async {
        await loadGenres()
        guard rows.isEmpty || loadedFilter != settingsManager.catalogFilter else { return }
        await reload()
    }

    func reload() async {
        loadTask?.cancel()
        loadMoreTasks.values.forEach { $0.cancel() }
        loadMoreTasks = [:]
        generation += 1
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

    /// Dočte další stránku řady (volá se při dorolování ke konci)
    func loadMore(_ source: ContentSource) {
        guard !isLoading, loadMoreTasks[source] == nil,
              let index = rows.firstIndex(where: { $0.source == source }),
              rows[index].hasMore, !rows[index].isLoadingMore,
              let filter = loadedFilter else { return }

        rows[index].isLoadingMore = true
        let page = rows[index].page + 1
        let path = filter.apply(to: kind.path(for: source), page: page)
        let generation = generation

        loadMoreTasks[source] = Task { [weak self] in
            let result = try? await ApiClient.fetchMenu(urlPath: path)
            guard let self, generation == self.generation else { return }
            loadMoreTasks[source] = nil
            guard let index = rows.firstIndex(where: { $0.source == source }) else { return }
            rows[index].isLoadingMore = false

            // Chyba: zkusí se znovu při dalším dorolování
            guard let result else { return }

            // Prázdná stránka nebo jen už známé položky (web za poslední stránkou vrací poslední) = konec
            let known = Set(rows[index].items.map(\.id))
            let newItems = result.filter { $0.itemType.isSupported && !known.contains($0.id) }
            rows[index].page = page
            rows[index].hasMore = !newItems.isEmpty
            rows[index].items += watchHistoryManager?.applyWatchOverrides(to: newItems) ?? newItems
        }
    }

    func refreshWatchStatus() {
        guard let manager = watchHistoryManager else { return }
        for index in rows.indices {
            rows[index].items = manager.applyWatchOverrides(to: rows[index].items)
        }
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
                        let items = try await ApiClient.fetchMenu(urlPath: filter.apply(to: kind.path(for: source), page: 1))
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
            return Row(
                source: source,
                items: items.filter { $0.itemType.isSupported },
                hasMore: !items.isEmpty,
                sortSupported: source.supportedSorts(series: kind == .shows).contains(filter.sort),
            )
        }
        loadedFilter = filter
        rowsVersion += 1

        if results.values.allSatisfy({ if case .failure = $0 { true } else { false } }),
           case let .failure(error)? = results[0]
        {
            errorMessage = error.localizedDescription
        }
        refreshWatchStatus()
    }
}
