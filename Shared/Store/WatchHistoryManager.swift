import Foundation
import Observation

@MainActor
@Observable
final class WatchHistoryManager {
    var continueWatching: [Media] = []

    /// Incremented after any watch status change so views can react.
    var changeCounter: Int = 0

    /// Tracks local watch status overrides keyed by Media.id.
    private var watchOverrides: [String: Bool] = [:]

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
            changeCounter += 1
        } catch {
            debugPrint("WatchHistoryManager: failed to remove watch record:", error)
        }
    }

    func setWatched(media: Media, watched: Bool) async {
        watchOverrides[media.id] = watched
        changeCounter += 1
        do {
            try await ApiClient.updateWatch(media: media, watched: watched)
            await load()
        } catch {
            debugPrint("WatchHistoryManager: failed to update watch status:", error)
        }
    }

    /// Applies any pending watch status overrides to a list of media items.
    func applyWatchOverrides(to items: [Media]) -> [Media] {
        guard !watchOverrides.isEmpty else { return items }
        return items.map { item in
            guard let watched = watchOverrides[item.id] else { return item }
            var updated = item
            updated.watchCompleted = watched
            return updated
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
