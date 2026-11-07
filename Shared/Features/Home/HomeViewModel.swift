import Foundation
import Observation

/// Domovská stránka: pokračovat ve sledování (filmy a seriály mají vlastní stránky — CatalogViewModel)
@MainActor
@Observable
final class HomeViewModel {
    var continueWatching: [Media] = []
    var isLoading = false

    var watchHistoryManager: WatchHistoryManager?

    var hasContent: Bool {
        !continueWatching.isEmpty
    }

    func load() async {
        await reload()
    }

    func reload() async {
        isLoading = true
        defer { isLoading = false }
        await watchHistoryManager?.load()
        continueWatching = watchHistoryManager?.continueWatching ?? []
    }

    func refreshWatchStatus() {
        continueWatching = watchHistoryManager?.continueWatching ?? []
    }
}
