import Foundation

struct PlaybackLauncher {
    let coordinator: MainCoordinator
    let watchHistoryManager: WatchHistoryManager

    func play(
        stream: Stream,
        media: Media
    ) async {
        guard let urlPath = stream.url else { return }

        // Získání streamu může trvat i několik sekund (uzi.la spouští přehrávač na serveru)
        await MainActor.run {
            coordinator.loadingMessage = "Připravuji přehrávání…"
            coordinator.isLoadingStreams = true
        }
        defer {
            Task { @MainActor in
                coordinator.isLoadingStreams = false
                coordinator.loadingMessage = nil
            }
        }

        do {
            let resolved = try await ApiClient.fetchResolvedStream(urlPath: urlPath)
            guard let streamURL = URL(string: resolved.url) else {
                await MainActor.run { coordinator.errorMessage = "Server vrátil neplatnou adresu streamu." }
                return
            }

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
                    skipTitlesStart: stream.skipTitlesStart,
                    externalSubtitles: resolved.subtitles ?? []
                )
            }
        } catch {
            debugPrint("Failed to resolve stream:", error)
            await MainActor.run { coordinator.showError(error) }
        }
    }
}
