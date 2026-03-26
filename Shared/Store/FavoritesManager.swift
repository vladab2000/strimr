import Foundation
import Observation

@MainActor
@Observable
final class FavoritesManager {
    var favorites: [Media] = []

    var favoriteMovies: [Media] {
        favorites.filter { $0.itemType == .movie }
    }

    var favoriteShows: [Media] {
        favorites.filter { $0.itemType == .tvshow }
    }

    func load() async {
        do {
            favorites = try await ApiClient.fetchFavorites()
        } catch {
            debugPrint("FavoritesManager: failed to load favorites:", error)
        }
    }

    func add(_ media: Media) async {
        do {
            try await ApiClient.addFavorite(media: media)
            await load()
        } catch {
            debugPrint("FavoritesManager: failed to add favorite:", error)
        }
    }

    func remove(_ media: Media) async {
        do {
            try await ApiClient.removeFavorite(media: media)
            await load()
        } catch {
            debugPrint("FavoritesManager: failed to remove favorite:", error)
        }
    }

    func isFavorite(_ media: Media) -> Bool {
        favorites.contains { $0.id == media.id }
    }
}
