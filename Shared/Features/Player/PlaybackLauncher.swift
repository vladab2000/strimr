import Foundation

struct PlaybackLauncher {
    let coordinator: MainCoordinator
    let watchHistoryManager: WatchHistoryManager

    func play(
        stream: Stream,
        media: Media
    ) async {
        guard let urlPath = stream.url else { return }

        do {
            let urlStr = try await ApiClient.fetchStream(urlPath: urlPath)
            guard let streamURL = URL(string: urlStr) else { return }

            let resume: Double? = if let pos = media.watchPosition, pos > 0, media.watchCompleted != true {
                Double(pos)
            } else {
                nil
            }

            await MainActor.run {
                coordinator.showPlayer(
                    streamURL: streamURL,
                    sessionId: "",
                    media: media,
                    resumePosition: resume,
                    skipIntroStart: stream.skipIntroStart,
                    skipIntroEnd: stream.skipIntroEnd,
                    skipTitlesStart: stream.skipTitlesStart
                )
            }
        } catch {
            debugPrint("Failed to resolve stream:", error)
        }
    }
}
