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
            try await ApiClient.createWatch(media: media)
        } catch {
            debugPrint("WatchHistoryManager: failed to create watch record:", error)
        }
    }

    func remove(media: Media) async {
        do {
            try await ApiClient.removeWatch(media: media)
            await load()
        } catch {
            debugPrint("WatchHistoryManager: failed to remove watch record:", error)
        }
    }

    func setWatched(media: Media, watched: Bool) async {
        do {
            try await ApiClient.updateWatch(media: media, watched: watched)
            await load()
        } catch {
            debugPrint("WatchHistoryManager: failed to update watch status:", error)
        }
    }
    
    func updatePosition(media: Media, position: Int) async {
        do {
            try await ApiClient.updateWatch(media: media, position: position)
        } catch {
            debugPrint("WatchHistoryManager: failed to update position:", error)
        }
    }
}
