import Foundation
import Observation

@MainActor
@Observable
final class PlayerViewModel {
    let streamURL: URL
    let title: String
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

    init(streamURL: URL, title: String) {
        self.streamURL = streamURL
        self.title = title
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
