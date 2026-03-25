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

    var mediaUrl: String?
    var resumePosition: Double?
    var onSavePosition: ((Int) -> Void)?

    private var lastSaveTime: Date = .distantPast

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
        case .duration:
            duration = data as? Double
        case .demuxerCacheDuration:
            bufferedAhead = data as? Double ?? 0.0
        default:
            break
        }
    }

    func handleStop() {
        onSavePosition?(Int(position))
    }

    private func periodicSave() {
        guard Date().timeIntervalSince(lastSaveTime) >= 15 else { return }
        lastSaveTime = Date()
        onSavePosition?(Int(position))
    }
}
