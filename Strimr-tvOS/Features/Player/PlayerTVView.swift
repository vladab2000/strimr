import SwiftUI

struct PlayerTVView: View {
    @Environment(SettingsManager.self) private var settingsManager
    @State var viewModel: PlayerViewModel
    let onExit: () -> Void
    let activePlayer: InternalPlaybackPlayer
    @State private var playerCoordinator: any PlayerCoordinating
    @State private var controlsVisible = true
    @State private var hideControlsWorkItem: DispatchWorkItem?
    @State private var isScrubbing = false
    @State private var supportsHDR = false
    @State private var audioTracks: [PlayerTrack] = []
    @State private var subtitleTracks: [PlayerTrack] = []
    @State private var settingsAudioTracks: [PlaybackSettingsTrack] = []
    @State private var settingsSubtitleTracks: [PlaybackSettingsTrack] = []
    @State private var selectedAudioTrackID: Int?
    @State private var selectedSubtitleTrackID: Int?
    @State private var playbackRate: Float = 1.0
    @State private var appliedPreferredAudio = false
    @State private var appliedPreferredSubtitle = false
    @State private var awaitingMediaLoad = false
    @State private var timelinePosition = 0.0
    @State private var activeSettingsSheet: PlayerSettingsSheet?
    @FocusState private var focusedPlayerSurface: PlayerFocusTarget?

    private let controlsHideDelay: TimeInterval = 3.0

    private var seekBackwardInterval: Double {
        Double(settingsManager.playback.seekBackwardSeconds)
    }

    private var seekForwardInterval: Double {
        Double(settingsManager.playback.seekForwardSeconds)
    }

    init(
        viewModel: PlayerViewModel,
        initialPlayer: InternalPlaybackPlayer,
        options: PlayerOptions,
        onExit: @escaping () -> Void,
    ) {
        _viewModel = State(initialValue: viewModel)
        activePlayer = initialPlayer
        _playerCoordinator = State(initialValue: PlayerFactory.makeCoordinator(for: initialPlayer, options: options))
        self.onExit = onExit
    }

    var body: some View {
        @Bindable var bindableViewModel = viewModel

        ZStack {
            Color.black.ignoresSafeArea()

            PlayerFactory.makeView(
                selection: activePlayer,
                coordinator: playerCoordinator,
                onPropertyChange: { propertyName, data in
                    bindableViewModel.handlePropertyChange(
                        property: propertyName,
                        data: data,
                        isScrubbing: isScrubbing,
                    )

                    if propertyName == .videoParamsSigPeak {
                        let supportsHdr = (data as? Double ?? 1.0) > 1.0
                        supportsHDR = supportsHdr
                    }
                },
                onPlaybackEnded: {
                    dismissPlayer()
                },
                onMediaLoaded: {
                    handleMediaLoaded()
                },
            )
            .ignoresSafeArea()
            .contentShape(Rectangle())
        }
        .overlay {
            ZStack {
                if !controlsVisible {
                    Color.clear
                        .contentShape(Rectangle())
                        .focusable()
                        .focused($focusedPlayerSurface, equals: .controlsProxy)
                        .onTapGesture {
                            showControls(temporarily: true)
                        }
                        .onMoveCommand { direction in
                            handleMoveCommand(direction)
                        }
                }

                if bindableViewModel.isBuffering {
                    bufferingOverlay
                }

                if controlsVisible {
                    PlayerControlsTVView(
                        title: bindableViewModel.title,
                        subtitle: bindableViewModel.subtitle,
                        isPaused: bindableViewModel.isPaused,
                        supportsHDR: supportsHDR,
                        position: timelineBinding,
                        duration: bindableViewModel.duration,
                        bufferedAhead: bindableViewModel.bufferedAhead,
                        bufferBasePosition: bindableViewModel.position,
                        isScrubbing: isScrubbing,
                        onShowAudioSettings: showAudioSettings,
                        onShowSubtitleSettings: showSubtitleSettings,
                        onShowSpeedSettings: showSpeedSettings,
                        onPlayPause: togglePlayPause,
                        onScrubbingChanged: handleScrubbing(editing:),
                        onUserInteraction: { showControls(temporarily: true) },
                        isLive: bindableViewModel.isLive,
                        skipIntroStart: bindableViewModel.skipIntroStart,
                        skipIntroEnd: bindableViewModel.skipIntroEnd,
                        skipTitlesStart: bindableViewModel.skipTitlesStart,
                    )
                    .transition(.opacity)
                }

                if bindableViewModel.showSkipIntroButton && !bindableViewModel.autoSkipIntro {
                    skipIntroButton
                        .transition(.move(edge: .trailing).combined(with: .opacity))
                }
            }
        }
        .onAppear {
            showControls(temporarily: true)
            playerCoordinator.setPlaybackRate(playbackRate)
            awaitingMediaLoad = true
            playerCoordinator.play(viewModel.streamURL)
            playerCoordinator.addExternalSubtitles(viewModel.externalSubtitles)
            viewModel.onSeek = { [playerCoordinator] position in
                playerCoordinator.seek(to: position)
            }
            viewModel.startKeepalive()
        }
        .onDisappear {
            viewModel.stopKeepalive()
            viewModel.handleStop()
            hideControlsWorkItem?.cancel()
            playerCoordinator.destruct()
        }
        .onPlayPauseCommand {
            guard !viewModel.isLive else { return }
            togglePlayPause()
        }
        .onExitCommand {
            dismissPlayer()
        }
        .onChange(of: controlsVisible) { _, isVisible in
            if isVisible {
                focusedPlayerSurface = nil
                return
            }

            DispatchQueue.main.async {
                guard !controlsVisible else { return }
                focusedPlayerSurface = .controlsProxy
            }
        }
        .onChange(of: bindableViewModel.position) { _, newValue in
            guard !isScrubbing else { return }
            timelinePosition = newValue
        }
        .sheet(item: $activeSettingsSheet) { sheet in
            switch sheet {
            case .audio:
                PlayerTrackSelectionView(
                    titleKey: sheet.titleKey,
                    tracks: settingsAudioTracks,
                    selectedTrackID: selectedAudioTrackID,
                    showOffOption: false,
                    onSelect: selectAudioTrack(_:),
                    onClose: { activeSettingsSheet = nil },
                )
            case .subtitle:
                PlayerTrackSelectionView(
                    titleKey: sheet.titleKey,
                    tracks: settingsSubtitleTracks,
                    selectedTrackID: selectedSubtitleTrackID,
                    showOffOption: true,
                    onSelect: selectSubtitleTrack(_:),
                    onClose: { activeSettingsSheet = nil },
                )
            case .speed:
                PlayerSpeedSelectionView(
                    selectedRate: playbackRate,
                    onSelect: selectPlaybackRate(_:),
                    onClose: { activeSettingsSheet = nil },
                )
            }
        }
    }

    private var skipIntroButton: some View {
        VStack {
            Spacer()
            HStack {
                Spacer()
                Button {
                    viewModel.skipIntro()
                } label: {
                    Label("player.skipIntro", systemImage: "forward.fill")
                        .font(.callout.weight(.semibold))
                }
                .buttonStyle(.bordered)
            }
            .padding(.bottom, 80)
            .padding(.trailing, 60)
        }
    }

    private var bufferingOverlay: some View {
        VStack {
            Spacer()

            HStack(spacing: 8) {
                ProgressView()
                    .progressViewStyle(.circular)
                    .tint(.white)

                Text("player.status.buffering")
                    .font(.callout.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.9))
            }
        }
        .padding(.bottom, 20)
    }

    private var timelineBinding: Binding<Double> {
        Binding(
            get: { timelinePosition },
            set: { timelinePosition = $0 },
        )
    }

    private func togglePlayPause() {
        playerCoordinator.togglePlayback()
        showControls(temporarily: true)
    }

    private func showAudioSettings() {
        refreshTracks()
        activeSettingsSheet = .audio
        showControls(temporarily: true)
    }

    private func showSubtitleSettings() {
        refreshTracks()
        activeSettingsSheet = .subtitle
        showControls(temporarily: true)
    }

    private func showSpeedSettings() {
        activeSettingsSheet = .speed
        showControls(temporarily: true)
    }

    private func refreshTracks() {
        Task {
            let tracks = playerCoordinator.trackList()

            let audio = tracks.filter { $0.type == .audio }
            let subtitles = tracks.filter { $0.type == .subtitle }

            await MainActor.run {
                audioTracks = audio
                subtitleTracks = subtitles

                settingsAudioTracks = audio.map {
                    PlaybackSettingsTrack(track: $0)
                }

                settingsSubtitleTracks = subtitles.map {
                    PlaybackSettingsTrack(track: $0)
                }

                if selectedAudioTrackID == nil,
                   let activeAudio = audio.first(where: { $0.isSelected })?.id ?? audioTracks.first?.id
                {
                    selectedAudioTrackID = activeAudio
                }

                if selectedSubtitleTrackID == nil,
                   let activeSubtitle = subtitles.first(where: { $0.isSelected })?.id
                {
                    selectedSubtitleTrackID = activeSubtitle
                }
            }
        }
    }

    private func selectAudioTrack(_ id: Int?) {
        selectedAudioTrackID = id
        playerCoordinator.selectAudioTrack(id: id)
    }

    private func selectSubtitleTrack(_ id: Int?) {
        selectedSubtitleTrackID = id
        playerCoordinator.selectSubtitleTrack(id: id)
    }

    private func selectPlaybackRate(_ rate: Float) {
        playbackRate = rate
        playerCoordinator.setPlaybackRate(rate)
        showControls(temporarily: true)
    }

    /// Skok šipkou bez zobrazeného ovládání — zobrazí ovládání s časovou osou (fokus na ní, další šipky posouvají)
    private func quickSeek(by seconds: Double) {
        playerCoordinator.seek(by: seconds)
        timelinePosition = min(max(viewModel.position + seconds, 0), viewModel.duration ?? .greatestFiniteMagnitude)
        showControls(temporarily: true)
    }

    private func handleMediaLoaded() {
        guard awaitingMediaLoad else { return }
        awaitingMediaLoad = false
        refreshTracks()

        if let resume = viewModel.resumePosition, resume > 0 {
            playerCoordinator.seek(to: resume)
            viewModel.resumePosition = nil
        }
    }

    private func dismissPlayer() {
        hideControlsWorkItem?.cancel()
        onExit()
    }

    private func handleScrubbing(editing: Bool) {
        isScrubbing = editing

        if editing {
            timelinePosition = viewModel.position
            hideControlsWorkItem?.cancel()
            withAnimation(.easeInOut) {
                controlsVisible = true
            }
        } else {
            playerCoordinator.seek(to: timelinePosition)
            viewModel.position = timelinePosition
            scheduleControlsHide()
        }
    }

    private func showControls(temporarily: Bool) {
        focusedPlayerSurface = nil

        withAnimation(.easeInOut) {
            controlsVisible = true
        }

        if temporarily, !isScrubbing {
            scheduleControlsHide()
        } else {
            hideControlsWorkItem?.cancel()
        }
    }

    private func scheduleControlsHide() {
        hideControlsWorkItem?.cancel()

        let workItem = DispatchWorkItem {
            // Při pauze zůstává ovládání zobrazené (jako systémový přehrávač)
            guard !viewModel.isPaused || activeSettingsSheet != nil else {
                scheduleControlsHide()
                return
            }
            withAnimation(.easeInOut) {
                controlsVisible = false
            }
        }

        hideControlsWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + controlsHideDelay, execute: workItem)
    }

    private func handleMoveCommand(_ direction: MoveCommandDirection) {
        switch direction {
        case .up:
            showControls(temporarily: true)
        // Vlevo/vpravo bez zobrazeného ovládání = skok zpět/vpřed (i během přehrávání)
        case .left:
            guard !controlsVisible, !viewModel.isLive else { return }
            quickSeek(by: -seekBackwardInterval)
        case .right:
            guard !controlsVisible, !viewModel.isLive else { return }
            quickSeek(by: seekForwardInterval)
        default:
            break
        }
    }
}

private enum PlayerSettingsSheet: String, Identifiable {
    case audio
    case subtitle
    case speed

    var id: String {
        rawValue
    }

    var titleKey: LocalizedStringKey {
        switch self {
        case .audio:
            "player.settings.audio"
        case .subtitle:
            "player.settings.subtitles"
        case .speed:
            "player.settings.speed"
        }
    }
}

private enum PlayerFocusTarget: Hashable {
    case controlsProxy
}
