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
