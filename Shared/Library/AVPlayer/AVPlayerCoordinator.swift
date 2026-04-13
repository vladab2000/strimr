import AVFoundation
import AVKit
import Foundation
import Observation

struct AVPlayerMetadata {
    var title: String?
    var subtitle: String?
    var description: String?
    var artworkURL: URL?
}

#if canImport(UIKit)

@MainActor
@Observable
final class AVPlayerCoordinator: NSObject, PlayerCoordinating {
    private(set) var player: AVPlayer?
    weak var playerViewController: AVPlayerViewController?

    @ObservationIgnored var options = PlayerOptions()
    @ObservationIgnored var playbackRate: Float = 1.0
    @ObservationIgnored var onPropertyChange: ((PlayerProperty, Any?) -> Void)?
    @ObservationIgnored var onPlaybackEnded: (() -> Void)?
    @ObservationIgnored var onMediaLoaded: (() -> Void)?

    @ObservationIgnored private var timeObserverToken: Any?
    @ObservationIgnored private var statusObservation: NSKeyValueObservation?
    @ObservationIgnored private var timeControlObservation: NSKeyValueObservation?
    @ObservationIgnored private var durationObservation: NSKeyValueObservation?
    @ObservationIgnored private var endObserver: NSObjectProtocol?

    func play(_ url: URL) {
        play(url, metadata: nil)
    }

    func play(_ url: URL, metadata: AVPlayerMetadata?) {
        cleanup()

        let item = AVPlayerItem(url: url)
        if let metadata {
            applyMetadata(metadata, to: item)
        }
        let avPlayer = AVPlayer(playerItem: item)
        avPlayer.rate = playbackRate
        self.player = avPlayer
        playerViewController?.player = avPlayer
        #if os(iOS)
        playerViewController?.showsTimecodes = true
        #endif

        setupObservers(player: avPlayer, item: item)
        avPlayer.play()
    }

    func updateMetadata(_ metadata: AVPlayerMetadata) {
        guard let item = player?.currentItem else { return }
        applyMetadata(metadata, to: item)
    }

    private func applyMetadata(_ metadata: AVPlayerMetadata, to item: AVPlayerItem) {
        var metadataItems: [AVMetadataItem] = []

        if let title = metadata.title {
            metadataItems.append(makeMetadataItem(identifier: .commonIdentifierTitle, value: title as NSString))
        }

        if let subtitle = metadata.subtitle {
            metadataItems.append(makeMetadataItem(identifier: .iTunesMetadataTrackSubTitle, value: subtitle as NSString))
        }

        if let description = metadata.description {
            metadataItems.append(makeMetadataItem(identifier: .commonIdentifierDescription, value: description as NSString))
        }

        if let artworkURL = metadata.artworkURL {
            Task {
                guard let (data, _) = try? await URLSession.shared.data(from: artworkURL) else { return }
                let artworkItem = self.makeMetadataItem(identifier: .commonIdentifierArtwork, value: data as NSData)
                await MainActor.run {
                    var items = item.externalMetadata
                    items.append(artworkItem)
                    item.externalMetadata = items
                }
            }
        }

        item.externalMetadata = metadataItems
    }

    private func makeMetadataItem(identifier: AVMetadataIdentifier, value: NSCopying & NSObjectProtocol) -> AVMetadataItem {
        let item = AVMutableMetadataItem()
        item.identifier = identifier
        item.value = value
        item.extendedLanguageTag = "und"
        return item.copy() as! AVMetadataItem
    }

    func togglePlayback() {
        guard let player else { return }
        if player.timeControlStatus == .playing {
            player.pause()
        } else {
            player.play()
        }
    }

    func pause() {
        player?.pause()
    }

    func resume() {
        player?.play()
    }

    func seek(to time: Double) {
        let cmTime = CMTime(seconds: time, preferredTimescale: 600)
        player?.seek(to: cmTime, toleranceBefore: .zero, toleranceAfter: .zero)
    }

    func seek(by delta: Double) {
        guard let player else { return }
        let current = player.currentTime().seconds
        seek(to: current + delta)
    }

    func setPlaybackRate(_ rate: Float) {
        playbackRate = rate
        player?.rate = rate
    }

    func selectAudioTrack(id: Int?) {
        guard let item = player?.currentItem else { return }
        Task {
            guard let group = try? await item.asset.loadMediaSelectionGroup(for: .audible) else { return }
            await MainActor.run {
                if let trackID = id,
                   let option = group.options.enumerated().first(where: { $0.offset == trackID })?.element
                {
                    item.select(option, in: group)
                } else {
                    item.select(nil, in: group)
                }
            }
        }
    }

    func selectSubtitleTrack(id: Int?) {
        guard let item = player?.currentItem else { return }
        Task {
            guard let group = try? await item.asset.loadMediaSelectionGroup(for: .legible) else { return }
            await MainActor.run {
                if let trackID = id,
                   let option = group.options.enumerated().first(where: { $0.offset == trackID })?.element
                {
                    item.select(option, in: group)
                } else {
                    item.select(nil, in: group)
                }
            }
        }
    }

    func trackList() -> [PlayerTrack] {
        guard let item = player?.currentItem else { return [] }
        var tracks: [PlayerTrack] = []
        var trackID = 0

        // Use synchronous deprecated API for trackList since it must return synchronously.
        // The async loadMediaSelectionGroup is used in selectAudioTrack/selectSubtitleTrack.
        if let audioGroup = item.asset.mediaSelectionGroup(forMediaCharacteristic: .audible) {
            let selectedAudio = item.currentMediaSelection.selectedMediaOption(in: audioGroup)
            for option in audioGroup.options {
                let locale = option.locale
                tracks.append(PlayerTrack(
                    id: trackID,
                    ffIndex: nil,
                    type: .audio,
                    title: option.displayName,
                    language: locale?.language.languageCode?.identifier,
                    codec: nil,
                    isDefault: option == audioGroup.defaultOption,
                    isSelected: option == selectedAudio
                ))
                trackID += 1
            }
        }

        if let subtitleGroup = item.asset.mediaSelectionGroup(forMediaCharacteristic: .legible) {
            let selectedSub = item.currentMediaSelection.selectedMediaOption(in: subtitleGroup)
            for option in subtitleGroup.options {
                let locale = option.locale
                tracks.append(PlayerTrack(
                    id: trackID,
                    ffIndex: nil,
                    type: .subtitle,
                    title: option.displayName,
                    language: locale?.language.languageCode?.identifier,
                    codec: nil,
                    isDefault: option == subtitleGroup.defaultOption,
                    isSelected: option == selectedSub
                ))
                trackID += 1
            }
        }

        return tracks
    }

    func destruct() {
        cleanup()
        player = nil
        playerViewController?.player = nil
    }

    // MARK: - Private

    private func setupObservers(player: AVPlayer, item: AVPlayerItem) {
        let propertyChange = onPropertyChange
        let mediaLoaded = onMediaLoaded
        let playbackEnded = onPlaybackEnded

        // Periodic time observer (0.5s)
        let interval = CMTime(seconds: 0.5, preferredTimescale: 600)
        timeObserverToken = player.addPeriodicTimeObserver(forInterval: interval, queue: .main) { time in
            Task { @MainActor in
                propertyChange?(.timePos, time.seconds)
            }
        }

        // Time control status (pause/playing/buffering)
        timeControlObservation = player.observe(\.timeControlStatus, options: [.new]) { player, _ in
            Task { @MainActor in
                switch player.timeControlStatus {
                case .paused:
                    propertyChange?(.pause, true)
                    propertyChange?(.pausedForCache, false)
                case .playing:
                    propertyChange?(.pause, false)
                    propertyChange?(.pausedForCache, false)
                case .waitingToPlayAtSpecifiedRate:
                    propertyChange?(.pausedForCache, true)
                @unknown default:
                    break
                }
            }
        }

        // Duration
        durationObservation = item.observe(\.duration, options: [.new]) { item, _ in
            Task { @MainActor in
                let duration = item.duration
                guard duration.isNumeric else { return }
                propertyChange?(.duration, duration.seconds)
            }
        }

        // Item status (ready to play)
        statusObservation = item.observe(\.status, options: [.new]) { item, _ in
            Task { @MainActor in
                if item.status == .readyToPlay {
                    if item.duration.isNumeric {
                        propertyChange?(.duration, item.duration.seconds)
                    }
                    mediaLoaded?()
                }
            }
        }

        // Playback ended
        endObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: item,
            queue: .main
        ) { _ in
            Task { @MainActor in
                playbackEnded?()
            }
        }
    }

    private func cleanup() {
        if let token = timeObserverToken {
            player?.removeTimeObserver(token)
            timeObserverToken = nil
        }
        statusObservation?.invalidate()
        statusObservation = nil
        timeControlObservation?.invalidate()
        timeControlObservation = nil
        durationObservation?.invalidate()
        durationObservation = nil
        if let observer = endObserver {
            NotificationCenter.default.removeObserver(observer)
            endObserver = nil
        }
        player?.pause()
    }
}

#endif
