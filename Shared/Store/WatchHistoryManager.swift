import Foundation
import Observation

@MainActor
@Observable
final class WatchHistoryManager {
    var continueWatching: [Media] = []

    func load() async {
        do {
            continueWatching = try await ApiClient.fetchContinueWatching()
        } catch {
            debugPrint("WatchHistoryManager: failed to load continue watching:", error)
        }
    }

    func createWatchRecord(for media: Media) async {
        do {
            try await ApiClient.createWatchRecord(media: media)
        } catch {
            debugPrint("WatchHistoryManager: failed to create watch record:", error)
        }
    }

    func remove(_ media: Media) async {
        do {
            try await ApiClient.removeWatchRecord(media: media)
            await load()
        } catch {
            debugPrint("WatchHistoryManager: failed to remove watch record:", error)
        }
    }

    func markAsWatched(_ media: Media) async {
        guard let url = media.url else { return }
        do {
            try await ApiClient.updateWatchPosition(
                mediaUrl: url,
                season: media.season,
                episode: media.episode,
                position: media.duration ?? 0,
                watched: true
            )
        } catch {
            debugPrint("WatchHistoryManager: failed to mark as watched:", error)
        }
    }

    func markAsUnwatched(_ media: Media) async {
        await remove(media)
    }

    func updatePosition(
        url: String,
        season: Int?,
        episode: Int?,
        position: Int
    ) async {
        do {
            try await ApiClient.updateWatchPosition(
                mediaUrl: url,
                season: season,
                episode: episode,
                position: position
            )
        } catch {
            debugPrint("WatchHistoryManager: failed to update position:", error)
        }
    }
}
