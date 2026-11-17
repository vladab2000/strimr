import Foundation
import Observation

@MainActor
@Observable
final class PlayerViewModel {
    var streamURL: URL
    var sessionId: String
    var title: String
    /// Menší řádek nad názvem v ovládání (např. "S01E02 - Název epizody")
    var subtitle: String?
    var isLive = false
    var isLoading = false
    var errorMessage: String?
    var isBuffering = false
    var duration: Double?
    var position = 0.0
    var bufferedAhead = 0.0
    var isPaused = false

    /// Externí titulky ke streamu (např. Bombuj .vtt) — přehrávač je přidá po načtení videa
    var externalSubtitles: [ExternalSubtitle] = []

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

    // Další díl seriálu: na konci epizody odpočet a pak přehrání dalšího dílu
    /// Dohledá další díl (volá se jednou, až se epizoda opravdu přehrává)
    var nextEpisodeProvider: (() async -> Media?)?
    /// Přehraje další díl (zavře přehrávač, koordinátor pak spustí další díl)
    var onPlayNextEpisode: ((Media) -> Void)?
    private(set) var nextEpisode: Media?
    /// Zbývající sekundy odpočtu; nil = odpočet se nezobrazuje
    private(set) var nextEpisodeCountdown: Int?
    private var hasRequestedNextEpisode = false
    private var nextEpisodeDismissed = false
    private var countdownTask: Task<Void, Never>?

    static let nextEpisodeCountdownSeconds = 10
    /// Bez značky závěrečných titulků začne odpočet tolik sekund před koncem
    private static let nextEpisodeLeadSeconds: Double = 30

    // Jazyk zvuku a titulků: zapamatovaná volba seriálu, jinak nastavení
    var rememberedTracks: TrackChoice?
    var preferredAudioLanguage = ""
    var preferredSubtitleLanguage = ""
    /// Uloží volbu uživatele (jen u seriálu)
    var onTrackChoiceChanged: ((TrackChoice) -> Void)?

    // Načítání a výpadky
    enum PlaybackStatus: Equatable {
        /// Čeká se na první načtení videa
        case loading
        case playing
        /// Výpadek — automatický pokus o obnovení (číslo pokusu)
        case recovering(attempt: Int)
        /// Obnovení se nepodařilo
        case failed(message: String?)
    }

    var status: PlaybackStatus = .loading
    /// Znovu načte stream od pozice (nil = od začátku / živě)
    var onReload: ((Double?) -> Void)?
    static let maxRecoveryAttempts = 3
    /// Zaseknuté načítání delší než tato doba = výpadek
    private static let stallTimeout: Duration = .seconds(20)
    private var recoveryAttempts = 0
    private var recoveryTask: Task<Void, Never>?
    private var stallTask: Task<Void, Never>?
    /// Pozice před výpadkem (časová osa se po novém načtení vynuluje)
    private var lastGoodPosition = 0.0
    /// Pozice, od které se naposledy obnovovalo — po minutě plynulého přehrávání se pokusy vynulují
    private var recoveryStartPosition = 0.0

    /// "S01E03 · Název epizody"
    var nextEpisodeLabel: String? {
        guard let nextEpisode else { return nil }
        return [nextEpisode.episodeIdentifier, nextEpisode.episodeTitle]
            .compactMap { $0 }
            .joined(separator: " · ")
    }

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
            watchStall()
        case .timePos:
            guard !isScrubbing else { return }
            position = data as? Double ?? 0.0
            if position > 0, status == .playing {
                lastGoodPosition = position
                if recoveryAttempts > 0, position - recoveryStartPosition > 60 {
                    recoveryAttempts = 0
                }
            }
            periodicSave()
            checkAutoSkipIntro()
            checkSkipTitles()
            checkNextEpisode()
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

    /// Zhlédnuto: od závěrečných titulků, bez jejich značky v posledních 5 % (aspoň minuta před koncem)
    private func checkSkipTitles() {
        guard !hasMarkedWatchedAtTitles else { return }
        if let titlesStart = skipTitlesStart, titlesStart > 0 {
            guard position >= titlesStart else { return }
        } else {
            guard !isLive, let duration, duration > 300,
                  duration - position <= max(60, duration * 0.05) else { return }
        }
        hasMarkedWatchedAtTitles = true
        onMarkWatched?()
    }

    // MARK: - Tracks

    func preferredTracks(in tracks: [PlayerTrack]) -> TrackSelection {
        TrackSelection.resolve(
            tracks: tracks,
            remembered: rememberedTracks,
            preferredAudio: preferredAudioLanguage,
            preferredSubtitle: preferredSubtitleLanguage,
        )
    }

    /// Ruční volba zvuku / titulků v přehrávači — u seriálu se použije i pro další díly
    func rememberTrackChoice(audio: PlayerTrack?, subtitle: PlayerTrack?) {
        guard let onTrackChoiceChanged else { return }
        let choice = TrackChoice(
            audioLanguage: audio.flatMap(TrackLanguage.of),
            subtitleLanguage: subtitle.flatMap(TrackLanguage.of),
            subtitlesOff: subtitle == nil,
        )
        rememberedTracks = choice
        onTrackChoiceChanged(choice)
    }

    // MARK: - Loading & recovery

    /// Video je načtené (první spuštění i po obnovení)
    func handleMediaLoaded() {
        recoveryTask?.cancel()
        status = .playing
    }

    /// Přehrávač ohlásil chybu (výpadek spojení, neplatný stream…) — zkusí stream načíst znovu
    func handlePlaybackFailed(_ message: String?) {
        stallTask?.cancel()
        guard recoveryAttempts < Self.maxRecoveryAttempts else {
            status = .failed(message: message)
            return
        }
        recoveryAttempts += 1
        let attempt = recoveryAttempts
        status = .recovering(attempt: attempt)

        recoveryTask?.cancel()
        recoveryTask = Task { [weak self] in
            // Mezi pokusy delší pauza (2, 4, 6 s)
            try? await Task.sleep(for: .seconds(2 * attempt))
            guard let self, !Task.isCancelled else { return }
            reload()
        }
    }

    /// Tlačítko "Zkusit znovu" po neúspěšném obnovení
    func retry() {
        recoveryAttempts = 0
        status = .recovering(attempt: 0)
        reload()
    }

    private func reload() {
        let resume = isLive || lastGoodPosition < 1 ? nil : lastGoodPosition
        recoveryStartPosition = lastGoodPosition
        resumePosition = resume
        onReload?(resume)
    }

    /// Načítání, které se nehne déle než stallTimeout, se bere jako výpadek
    private func watchStall() {
        stallTask?.cancel()
        guard isBuffering, status == .playing else { return }
        stallTask = Task { [weak self] in
            try? await Task.sleep(for: Self.stallTimeout)
            guard let self, !Task.isCancelled, isBuffering else { return }
            handlePlaybackFailed(String(localized: "player.status.stalled"))
        }
    }

    // MARK: - Next episode

    private func checkNextEpisode() {
        guard let nextEpisodeProvider, !isLive else { return }

        // Další díl se dohledá, až se epizoda opravdu přehrává (stejně jako záznam do historie)
        if !hasRequestedNextEpisode, position >= Self.minimumPlaybackSeconds {
            hasRequestedNextEpisode = true
            Task { [weak self] in
                let next = await nextEpisodeProvider()
                self?.nextEpisode = next
            }
        }

        guard nextEpisode != nil, !nextEpisodeDismissed, nextEpisodeCountdown == nil,
              let duration, duration > 120 else { return }
        let trigger = skipTitlesStart.flatMap { $0 > 0 ? $0 : nil } ?? (duration - Self.nextEpisodeLeadSeconds)
        guard position >= trigger else { return }
        startNextEpisodeCountdown()
    }

    private func startNextEpisodeCountdown() {
        nextEpisodeCountdown = Self.nextEpisodeCountdownSeconds
        countdownTask?.cancel()
        countdownTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(1))
                guard let self, !Task.isCancelled, let remaining = nextEpisodeCountdown else { return }
                if remaining <= 1 {
                    playNextEpisode()
                    return
                }
                nextEpisodeCountdown = remaining - 1
            }
        }
    }

    /// Tlačítko "Přehrát" v odpočtu nebo konec odpočtu
    func playNextEpisode() {
        countdownTask?.cancel()
        nextEpisodeCountdown = nil
        guard let nextEpisode else { return }
        nextEpisodeDismissed = true
        if !hasMarkedWatchedAtTitles {
            hasMarkedWatchedAtTitles = true
            onMarkWatched?()
        }
        onPlayNextEpisode?(nextEpisode)
    }

    /// Tlačítko "Zrušit" — epizoda dohraje, přehrávač se pak zavře
    func cancelNextEpisode() {
        countdownTask?.cancel()
        nextEpisodeCountdown = nil
        nextEpisodeDismissed = true
    }

    /// Konec videa: true = pokračuje se dalším dílem (přehrávač se nezavírá sám)
    func handlePlaybackEnded() -> Bool {
        guard nextEpisode != nil, onPlayNextEpisode != nil, nextEpisodeCountdown != nil || !nextEpisodeDismissed else {
            return false
        }
        playNextEpisode()
        return true
    }
}
