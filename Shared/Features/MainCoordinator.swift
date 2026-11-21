import Combine
import SwiftUI

@MainActor
final class MainCoordinator: ObservableObject {
    enum Tab: String, Hashable {
        case home
        case movies
        case shows
        case search
        case channels
        case more
    }

    enum Route: Hashable {
        case mediaDetail(Media)
        case streamSelection(media: Media, streams: [Stream])
    }

    /// Poslední záložka se obnoví po novém spuštění (vyhledávání ne — začíná se prázdným dotazem)
    @Published var tab: Tab = AppStateStore.lastTab.flatMap(Tab.init(rawValue:)).flatMap { $0 == .search ? nil : $0 } ?? .home {
        didSet { AppStateStore.lastTab = tab.rawValue }
    }
    @Published var homePath = NavigationPath()
    @Published var moviesPath = NavigationPath()
    @Published var showsPath = NavigationPath()
    @Published var searchPath = NavigationPath()
    @Published var channelsPath = NavigationPath()
    @Published var morePath = NavigationPath()

    @Published var selectedStreamURL: URL?
    @Published var selectedSessionId: String?
    @Published var selectedMedia: Media?
    @Published var selectedResumePosition: Double?
    @Published var selectedSkipIntroStart: Double?
    @Published var selectedSkipIntroEnd: Double?
    @Published var selectedSkipTitlesStart: Double?
    @Published var selectedExternalSubtitles: [ExternalSubtitle] = []
    /// Šifrovaný stream (FairPlay) — přehraje ho jen AVPlayer
    @Published var selectedDrm: StreamDrm?
    @Published var isPresentingPlayer = false

    /// Channel context for LiveTV playback (auto-next program)
    @Published var selectedChannel: Media?
    @Published var selectedProgram: Media?

    @Published var isLoadingStreams = false
    /// Text pod ukazatelem průběhu (např. při čekání na stream ze serveru)
    @Published var loadingMessage: String?
    /// Chyba přehrávání zobrazená v alertu
    @Published var errorMessage: String?
    /// Dotaz před přehráním (např. OnePlay: omezený počet přehrání zdarma)
    @Published var playbackConfirmation: PlaybackConfirmation?

    struct PlaybackConfirmation: Identifiable {
        let id = UUID()
        let message: String
        let onConfirm: () -> Void
    }

    var playbackLauncher: PlaybackLauncher?

    /// Stream, který se právě přehrává — u dalšího dílu se vybere podobný (stejné jazyky)
    var currentStream: Stream?
    /// Další díl, který se spustí po zavření přehrávače
    private var pendingNextEpisode: Media?

    func pathBinding(for tab: Tab) -> Binding<NavigationPath> {
        Binding(
            get: {
                switch tab {
                case .home:
                    self.homePath
                case .movies:
                    self.moviesPath
                case .shows:
                    self.showsPath
                case .search:
                    self.searchPath
                case .channels:
                    self.channelsPath
                case .more:
                    self.morePath
                }
            },
            set: { newValue in
                switch tab {
                case .home:
                    self.homePath = newValue
                case .movies:
                    self.moviesPath = newValue
                case .shows:
                    self.showsPath = newValue
                case .search:
                    self.searchPath = newValue
                case .channels:
                    self.channelsPath = newValue
                case .more:
                    self.morePath = newValue
                }
            },
        )
    }

    func showMediaDetail(_ media: Media) {
        if media.itemType == .movie || media.itemType == .episode {
            Task { await loadStreamsAndNavigate(media) }
            return
        }
        if media.itemType == .program {
            Task { await playProgram(media) }
            return
        }
        appendRoute(.mediaDetail(media))
    }

    private func playProgram(_ program: Media) async {
        guard let channelId = program.channelId else {
            debugPrint("Program has no channelId, cannot resolve archive stream")
            return
        }

        isLoadingStreams = true
        defer { isLoadingStreams = false }

        do {
            let playback = try await ApiClient.fetchArchiveStream(
                channelId: channelId,
                programId: program.id
            )
            let url = ApiClient.playbackURL(sessionId: playback.sessionId)

            let resume: Double? = if let pos = program.watchPosition, pos > 0, program.watchCompleted != true {
                Double(pos)
            } else {
                nil
            }
            
            showPlayer(streamURL: url, sessionId: playback.sessionId, media: program, resumePosition: resume)
        } catch {
            debugPrint("Failed to resolve program stream:", error)
            showError(error)
        }
    }

    private func loadStreamsAndNavigate(_ media: Media) async {
        isLoadingStreams = true
        defer { isLoadingStreams = false }

        let (streams, richer) = await fetchStreams(for: media)
        // Bohatší verze ze serveru nemá vazbu epizody na seriál (pokračování, další díl)
        var selected = richer ?? media
        selected.parentId = selected.parentId ?? media.parentId
        selected.parentUrl = selected.parentUrl ?? media.parentUrl
        appendRoute(.streamSelection(media: selected, streams: streams))
    }

    private func fetchStreams(for media: Media) async -> ([Stream], Media?) {
        // Inline streams: skip folder fetch, no enriched media available
        if let inlineStreams = media.streams, !inlineStreams.isEmpty {
            return (StreamSorter.sorted(inlineStreams), nil)
        }

        let urlPath = media.url
        do {
            let items = try await ApiClient.fetchMenu(urlPath: urlPath)
            let allStreams = items.flatMap { $0.streams ?? [] }
            // Look for an enriched version of the same item returned alongside streams
            let richer = items.first(where: { $0.id == media.id })
            return (StreamSorter.sorted(allStreams), richer)
        } catch {
            debugPrint("Failed to fetch streams:", error)
            return ([], nil)
        }
    }

    private func appendRoute(_ route: Route) {
        switch tab {
        case .home:
            homePath.append(route)
        case .movies:
            moviesPath.append(route)
        case .shows:
            showsPath.append(route)
        case .search:
            searchPath.append(route)
        case .channels:
            channelsPath.append(route)
        case .more:
            break
        }
    }

    func showError(_ error: Error) {
        errorMessage = error.localizedDescription
    }

    func showPlayer(
        streamURL: URL,
        sessionId: String,
        media: Media? = nil,
        resumePosition: Double? = nil,
        skipIntroStart: Double? = nil,
        skipIntroEnd: Double? = nil,
        skipTitlesStart: Double? = nil,
        externalSubtitles: [ExternalSubtitle] = [],
        drm: StreamDrm? = nil,
        channel: Media? = nil,
        program: Media? = nil
    ) {
        selectedStreamURL = streamURL
        selectedSessionId = sessionId
        selectedMedia = media
        selectedResumePosition = resumePosition
        selectedSkipIntroStart = skipIntroStart
        selectedSkipIntroEnd = skipIntroEnd
        selectedSkipTitlesStart = skipTitlesStart
        selectedExternalSubtitles = externalSubtitles
        selectedDrm = drm
        selectedChannel = channel
        selectedProgram = program
        isPresentingPlayer = true
    }

    /// Další díl seriálu v přehrávači: na konci epizody odpočet, pak přehrávač zavře a spustí další díl
    func configureNextEpisode(for viewModel: PlayerViewModel, media: Media?, enabled: Bool) {
        guard enabled, let media, media.itemType == .episode, media.parentUrl != nil else { return }
        viewModel.nextEpisodeProvider = { await SeriesNavigator.nextEpisode(after: media) }
        viewModel.onPlayNextEpisode = { [weak self] next in
            guard let self else { return }
            pendingNextEpisode = next
            resetPlayer()
        }
    }

    /// Jazyk zvuku a titulků: u seriálu zapamatovaná volba (ruční změna v přehrávači se uloží), jinak nastavení
    func configureTrackPreferences(for viewModel: PlayerViewModel, media: Media?, settingsManager: SettingsManager) {
        viewModel.preferredAudioLanguage = settingsManager.playback.preferredAudioLanguage
        viewModel.preferredSubtitleLanguage = settingsManager.playback.preferredSubtitleLanguage
        guard let seriesId = media?.parentId else { return }
        viewModel.rememberedTracks = settingsManager.seriesTrackChoice(for: seriesId)
        viewModel.onTrackChoiceChanged = { [weak settingsManager] choice in
            settingsManager?.setSeriesTrackChoice(choice, for: seriesId)
        }
    }

    /// Volá se po zavření přehrávače (onDismiss) — případně spustí další díl.
    /// Až po zavření: nový přehrávač otevřený během zavírání by onDismiss hned zrušil.
    func playerDidDismiss() {
        resetPlayer()
        guard let next = pendingNextEpisode else { return }
        pendingNextEpisode = nil
        Task { await playNextEpisode(next) }
    }

    private func playNextEpisode(_ episode: Media) async {
        isLoadingStreams = true
        let (streams, richer) = await fetchStreams(for: episode)
        isLoadingStreams = false

        var next = richer ?? episode
        next.parentId = next.parentId ?? episode.parentId
        next.parentUrl = next.parentUrl ?? episode.parentUrl

        // Stejné jazyky jako u předchozího dílu, jinak nejlepší podle řazení; bez streamu výběr ručně
        let preferredLangs = currentStream?.langs.map(Set.init)
        guard let stream = streams.first(where: { preferredLangs != nil && $0.langs.map(Set.init) == preferredLangs }) ?? streams.first,
              let playbackLauncher else {
            appendRoute(.streamSelection(media: next, streams: streams))
            return
        }
        await playbackLauncher.play(stream: stream, media: next)
    }

    func resetPlayer() {
        selectedStreamURL = nil
        selectedSessionId = nil
        selectedMedia = nil
        selectedResumePosition = nil
        selectedSkipIntroStart = nil
        selectedSkipIntroEnd = nil
        selectedSkipTitlesStart = nil
        selectedExternalSubtitles = []
        selectedDrm = nil
        selectedChannel = nil
        selectedProgram = nil
        isPresentingPlayer = false
    }
}
