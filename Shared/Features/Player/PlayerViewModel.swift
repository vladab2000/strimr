import Foundation
import Observation

@MainActor
@Observable
final class PlayerViewModel {
    var streamURL: URL
    var sessionId: String
    var title: String
    var isLive = false
    var isLoading = false
    var errorMessage: String?
    var isBuffering = false
    var duration: Double?
    var position = 0.0
    var bufferedAhead = 0.0
    var isPaused = false

    var resumePosition: Double?
    var onSavePosition: ((Int) -> Void)?
    var onCreateWatchRecord: (() -> Void)?
    var onMarkWatched: (() -> Void)?
    var onSeek: ((Double) -> Void)?

    /// Called when playback ends and a next program should be played.
    /// Returns the stream URL and metadata for the next program, or nil if none.
    var onPlayNextProgram: (() async -> (sessionId: String, title: String, metadata: AVPlayerMetadata)?)?

    /// Channel name displayed in metadata subtitle
    var channelName: String?

    /// Description for player metadata display
    var mediaDescription: String?

    /// Artwork URL for player metadata display
    var artworkURL: URL?
    
    var startDate: Date?
    var endDate: Date?

    /// Called to switch playback to the live stream of the current channel.
    var onGoToLive: (() async -> (sessionId: String, title: String, metadata: AVPlayerMetadata)?)?

    // Skip intro
    var skipIntroStart: Double?
    var skipIntroEnd: Double?
    var autoSkipIntro = false
    private var hasAutoSkippedIntro = false

    // Skip titles (mark as watched)
    var skipTitlesStart: Double?
    private var hasMarkedWatchedAtTitles = false

    /// Whether the "Skip Intro" button should be visible.
    var showSkipIntroButton: Bool {
        guard let end = skipIntroEnd, end > 0 else { return false }
        let start = skipIntroStart ?? 0
        return position >= start && position < end
    }

    private static let minimumPlaybackSeconds: Double = 60
    private var lastSaveTime: Date = .distantPast
    private var hasCreatedWatchRecord = false

    private var keepaliveTask: Task<Void, Never>?

    init(streamURL: URL, sessionId: String, title: String) {
        self.streamURL = streamURL
        self.sessionId = sessionId
        self.title = title
    }

    // MARK: - Keepalive

    func startKeepalive() {
        guard !sessionId.isEmpty else { return }
        stopKeepalive()
        keepaliveTask = Task { [weak self] in
            while !Task.isCancelled {
                guard let self else { return }
                if !self.isPaused {
                    await ApiClient.sendKeepalive(sessionId: self.sessionId)
                }
                try? await Task.sleep(nanoseconds: 5_000_000_000)
            }
        }
    }

    func stopKeepalive() {
        keepaliveTask?.cancel()
        keepaliveTask = nil
    }

    func handlePropertyChange(
        property: PlayerProperty,
        data: Any?,
        isScrubbing: Bool,
    ) {
        switch property {
        case .pause:
            isPaused = (data as? Bool) ?? false
        case .pausedForCache:
            isBuffering = (data as? Bool) ?? false
        case .timePos:
            guard !isScrubbing else { return }
            position = data as? Double ?? 0.0
            periodicSave()
            checkAutoSkipIntro()
            checkSkipTitles()
        case .duration:
            duration = data as? Double
        case .demuxerCacheDuration:
            bufferedAhead = data as? Double ?? 0.0
        default:
            break
        }
    }

    func handleStop() {
        guard position >= Self.minimumPlaybackSeconds else { return }
        ensureWatchRecordCreated()
        onSavePosition?(Int(position))
    }

    private func periodicSave() {
        guard position >= Self.minimumPlaybackSeconds else { return }
        guard Date().timeIntervalSince(lastSaveTime) >= 15 else { return }
        lastSaveTime = Date()
        ensureWatchRecordCreated()
        onSavePosition?(Int(position))
    }

    private func ensureWatchRecordCreated() {
        guard !hasCreatedWatchRecord else { return }
        hasCreatedWatchRecord = true
        onCreateWatchRecord?()
    }

    /// Called when the user taps "Skip Intro" button.
    func skipIntro() {
        guard let end = skipIntroEnd, end > 0 else { return }
        onSeek?(end)
    }

    private func checkAutoSkipIntro() {
        guard autoSkipIntro, !hasAutoSkippedIntro else { return }
        guard let end = skipIntroEnd, end > 0 else { return }
        let start = skipIntroStart ?? 0
        if position >= start {
            hasAutoSkippedIntro = true
            onSeek?(end)
        }
    }

    private func checkSkipTitles() {
        guard !hasMarkedWatchedAtTitles else { return }
        guard let titlesStart = skipTitlesStart, titlesStart > 0 else { return }
        if position >= titlesStart {
            hasMarkedWatchedAtTitles = true
            onMarkWatched?()
        }
    }
}
