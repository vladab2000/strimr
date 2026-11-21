import Foundation

struct PlaybackLauncher {
    let coordinator: MainCoordinator
    let watchHistoryManager: WatchHistoryManager

    /// Kód chyby serveru: přehrání z omezeného počtu přehrání zdarma (OnePlay) je potřeba potvrdit
    static let confirmLimitedPlayCode = "OnePlay:ConfirmLimitedPlay"

    func play(
        stream: Stream,
        media: Media,
        confirmed: Bool = false
    ) async {
        guard let streamPath = stream.url else { return }
        // Potvrzené přehrání: server pošle OnePlay souhlas se spotřebou přehrání zdarma.
        // OnePlay: tituly z limitu přehrání jsou jen šifrované — AVPlayer je přehraje s FairPlay (iOS, tvOS)
        var query: [String] = []
        if confirmed { query.append("confirm=1") }
        #if canImport(UIKit)
        if streamPath.hasPrefix("/oneplay/stream/") { query.append("drm=fairplay") }
        #endif
        let urlPath = query.isEmpty ? streamPath : streamPath + (streamPath.contains("?") ? "&" : "?") + query.joined(separator: "&")

        // Získání streamu může trvat i několik sekund (uzi.la spouští přehrávač na serveru)
        await MainActor.run {
            coordinator.loadingMessage = String(localized: "player.preparing")
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
                await MainActor.run { coordinator.errorMessage = String(localized: "player.error.invalidStream") }
                return
            }

            let resume: Double? = if let pos = media.watchPosition, pos > 0, media.watchCompleted != true {
                Double(pos)
            } else {
                nil
            }

            await MainActor.run {
                coordinator.currentStream = stream
                coordinator.showPlayer(
                    streamURL: streamURL,
                    sessionId: "",
                    media: media,
                    resumePosition: resume,
                    skipIntroStart: stream.skipIntroStart,
                    skipIntroEnd: stream.skipIntroEnd,
                    skipTitlesStart: stream.skipTitlesStart,
                    externalSubtitles: resolved.subtitles ?? [],
                    drm: resolved.drm
                )
            }
        } catch let error as ApiError where error.code == Self.confirmLimitedPlayCode && !confirmed {
            await MainActor.run {
                coordinator.playbackConfirmation = .init(message: error.localizedDescription) {
                    Task { await play(stream: stream, media: media, confirmed: true) }
                }
            }
        } catch {
            debugPrint("Failed to resolve stream:", error)
            await MainActor.run { coordinator.showError(error) }
        }
    }
}
