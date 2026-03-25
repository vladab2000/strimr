import Foundation

struct PlaybackLauncher {
    let coordinator: MainCoordinator
    let watchHistoryManager: WatchHistoryManager

    func play(
        stream: Stream,
        media: Media,
        resumePosition: Double? = nil
    ) async {
        guard let urlPath = stream.url else { return }

        do {
            let response = try await ApiClient.fetchStream(urlPath: urlPath)
            let urlStr = response.resolved.isEmpty ? response.input : response.resolved
            guard let streamURL = URL(string: urlStr) else { return }

            // Create watch record on server before showing player
            await watchHistoryManager.createWatchRecord(for: media)

            await MainActor.run {
                coordinator.showPlayer(
                    streamURL: streamURL,
                    title: media.title,
                    mediaUrl: media.url,
                    seasonNumber: media.seasonNumber,
                    episodeNumber: media.episodeNumber,
                    resumePosition: resumePosition
                )
            }
        } catch {
            debugPrint("Failed to resolve stream:", error)
        }
    }
}
