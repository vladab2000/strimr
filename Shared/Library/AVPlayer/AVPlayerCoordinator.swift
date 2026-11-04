import AVFoundation
import AVKit
import Foundation
import Observation

struct AVPlayerMetadata {
    var title: String?
    var subtitle: String?
    var description: String?
    var artworkURL: URL?
    var startDate: Date?
    var endDate: Date?
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
    @ObservationIgnored private var backgroundObserver: NSObjectProtocol?
    @ObservationIgnored private var foregroundObserver: NSObjectProtocol?
    @ObservationIgnored private var cachedAudioGroup: AVMediaSelectionGroup?
    @ObservationIgnored private var cachedSubtitleGroup: AVMediaSelectionGroup?

    // MARK: - Bitrate monitoring
    @ObservationIgnored private var bitrateMonitorTimer: Timer?
    @ObservationIgnored private var lowBitrateStartDate: Date?
    @ObservationIgnored private var lastKnownPeakBitrate: Double = 0

    // MARK: - Wake restart
    @ObservationIgnored private var currentURL: URL?
    @ObservationIgnored private var currentMetadata: AVPlayerMetadata?
    @ObservationIgnored private var backgroundEntryDate: Date?
    @ObservationIgnored private var wasPlayingBeforeBackground = false

    private static let lowBitrateThresholdFraction = 0.3
    private static let lowBitrateDuration: TimeInterval = 30
    private static let bitrateMonitorInterval: TimeInterval = 10
    // Minimální doba v pozadí (sekundy) po které restartujeme stream po probuzení
    private static let backgroundRestartThreshold: TimeInterval = 60

    func play(_ url: URL) {
        play(url, seekPosition: nil, metadata: nil)
    }

    func play(_ url: URL, seekPosition: Double?, metadata: AVPlayerMetadata?) {
        currentURL = url
        currentMetadata = metadata
        cleanup()

        let options = [
            "AVURLAssetHTTPHeaderFieldsKey": [
                "User-Agent": "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/146.0.0.0 Safari/537.36",
                "Referer": "https://www.oneplay.cz/"
                ]
            ]

        let asset = AVURLAsset(url: url, options: options)
        let item = AVPlayerItem(asset: asset)
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
        if seekPosition != nil {
            seek(to: seekPosition!)
        }
        else {
            avPlayer.play()
        }
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

#if !os(iOS)
        if let startDate = metadata.startDate, let endDate = metadata.endDate, let channel = metadata.subtitle {
            let startDateItem = makeMetadataItem(identifier: AVMetadataIdentifier(AVKitMetadataIdentifierExactStartDate), value: startDate as (NSCopying & NSObjectProtocol))
            let endDateItem = makeMetadataItem(identifier: AVMetadataIdentifier(AVKitMetadataIdentifierExactEndDate), value: endDate as (NSCopying & NSObjectProtocol))
            let serviceItentifier = makeMetadataItem(identifier: AVMetadataIdentifier(AVKitMetadataIdentifierServiceIdentifier), value: channel as (NSCopying & NSObjectProtocol))
            metadataItems.append(startDateItem)
            metadataItems.append(endDateItem)
            metadataItems.append(serviceItentifier)
        }
#endif

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

    /// Configures custom transport bar items on the AVPlayerViewController.
    func configureTransportBarActions(
        onPlayFromBeginning: (() -> Void)?,
        onGoToLive: (() -> Void)?
    ) {
        guard let vc = playerViewController else { return }
        var items: [UIMenuElement] = []

        if let onPlayFromBeginning {
            let action = UIAction(
                title: String(localized: "player.action.playFromBeginning"),
                image: UIImage(systemName: "backward.fill")
            ) { _ in
                onPlayFromBeginning()
            }
            items.append(action)
        }

        if let onGoToLive {
            let action = UIAction(
                title: String(localized: "player.action.goToLive"),
                image: UIImage(systemName: "dot.radiowaves.left.and.right")
            ) { _ in
                onGoToLive()
            }
            items.append(action)
        }

#if !os(iOS)
        vc.transportBarCustomMenuItems = items
#endif
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

        if let audioGroup = cachedAudioGroup {
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

        if let subtitleGroup = cachedSubtitleGroup {
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
        currentURL = nil
        currentMetadata = nil
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
        statusObservation = item.observe(\.status, options: [.new]) { [weak self] item, _ in
            Task { @MainActor in
                if item.status == .readyToPlay {
                    if item.duration.isNumeric {
                        propertyChange?(.duration, item.duration.seconds)
                    }
                    self?.cachedAudioGroup = try? await item.asset.loadMediaSelectionGroup(for: .audible)
                    self?.cachedSubtitleGroup = try? await item.asset.loadMediaSelectionGroup(for: .legible)
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

        NotificationCenter.default.addObserver(forName: .AVPlayerItemNewErrorLogEntry, object: item, queue: .main) { _ in
            guard let errorLog = player.currentItem?.errorLog() else { return }
            for entry in errorLog.events {
                print("Chyba přehrávání: \(entry.errorComment ?? "Neznámá chyba")")
                print("Doména chyby: \(entry.errorDomain)")
                print("Kód chyby: \(entry.errorStatusCode)")
            }
        }

        NotificationCenter.default.addObserver(forName: .AVPlayerItemNewAccessLogEntry, object: player.currentItem, queue: .main) { _ in
            guard let accessLog = player.currentItem?.accessLog() else { return }
            for entry in accessLog.events {
                print("Indikovaný bitrate: \(entry.indicatedBitrate)")
                print("Počet záseků (stalls): \(entry.numberOfStalls)")
            }
        }

        // Sledujeme přechod do pozadí — zaznamenáme stav přehrávání
        backgroundObserver = NotificationCenter.default.addObserver(
            forName: UIApplication.didEnterBackgroundNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            guard let self else { return }
            self.wasPlayingBeforeBackground = self.player?.timeControlStatus == .playing
            self.backgroundEntryDate = Date()
        }

        // Po probuzení: pokud přehrávač běžel a aplikace spala dost dlouho → nová instance AVPlayer
        foregroundObserver = NotificationCenter.default.addObserver(
            forName: UIApplication.didBecomeActiveNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.handleForeground()
            }
        }

        // Periodický monitor bitrate — detekuje pokles kvality během přehrávání
        startBitrateMonitor()
    }

    // MARK: - Wake restart

    private func handleForeground() {
        guard
            wasPlayingBeforeBackground,
            let bgDate = backgroundEntryDate,
            Date().timeIntervalSince(bgDate) >= Self.backgroundRestartThreshold,
            let url = currentURL
        else {
            backgroundEntryDate = nil
            return
        }
        backgroundEntryDate = nil
        print("Wake: aplikace spala \(Int(Date().timeIntervalSince(bgDate)))s — restartuji přehrávač")
        play(url, seekPosition: nil, metadata: currentMetadata)
    }

    // MARK: - Bitrate monitor

    private func startBitrateMonitor() {
        bitrateMonitorTimer?.invalidate()
        lowBitrateStartDate = nil
        lastKnownPeakBitrate = 0

        bitrateMonitorTimer = Timer.scheduledTimer(
            withTimeInterval: Self.bitrateMonitorInterval,
            repeats: true
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.checkBitrate()
            }
        }
    }

    private func checkBitrate() {
        guard let player,
              player.timeControlStatus == .playing,
              let event = player.currentItem?.accessLog()?.events.last else {
            return
        }

        let indicated = event.indicatedBitrate
        guard indicated > 0 else { return }

        if indicated > lastKnownPeakBitrate {
            lastKnownPeakBitrate = indicated
        }

        guard lastKnownPeakBitrate > 0 else { return }

        let ratio = indicated / lastKnownPeakBitrate
        print("Bitrate monitor: indicated=\(Int(indicated)) peak=\(Int(lastKnownPeakBitrate)) ratio=\(String(format: "%.2f", ratio))")

        if ratio < Self.lowBitrateThresholdFraction {
            if lowBitrateStartDate == nil {
                lowBitrateStartDate = Date()
            }

            let elapsed = Date().timeIntervalSince(lowBitrateStartDate!)
            print("Bitrate monitor: low bitrate detected for \(Int(elapsed))s")

            if elapsed >= Self.lowBitrateDuration {
                resetBitrateAdaptation()
            }
        } else {
            lowBitrateStartDate = nil
        }
    }

    // Po 30s na nízké kvalitě odstraníme omezení a dáme AVPlayer šanci přehodnotit
    private func resetBitrateAdaptation() {
        print("Bitrate reset: vynucené přehodnocení ABR")
        lowBitrateStartDate = nil
        lastKnownPeakBitrate = 0
        player?.currentItem?.preferredPeakBitRate = 0
    }

    private func cleanup() {
        bitrateMonitorTimer?.invalidate()
        bitrateMonitorTimer = nil
        lowBitrateStartDate = nil
        lastKnownPeakBitrate = 0
        backgroundEntryDate = nil
        wasPlayingBeforeBackground = false

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
        if let observer = backgroundObserver {
            NotificationCenter.default.removeObserver(observer)
            backgroundObserver = nil
        }
        if let observer = foregroundObserver {
            NotificationCenter.default.removeObserver(observer)
            foregroundObserver = nil
        }
        cachedAudioGroup = nil
        cachedSubtitleGroup = nil
        player?.pause()
    }
}

#endif
