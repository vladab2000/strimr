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
            let urlStr = try await ApiClient.fetchStream(urlPath: urlPath)
            guard let streamURL = URL(string: urlStr) else { return }

            await MainActor.run {
                coordinator.showPlayer(
                    streamURL: streamURL,
                    media: media,
                    resumePosition: resumePosition
                )
            }
        } catch {
            debugPrint("Failed to resolve stream:", error)
        }
    }
}
