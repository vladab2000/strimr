import SwiftUI

struct PlayerView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(SettingsManager.self) private var settingsManager
    @State var viewModel: PlayerViewModel
    let activePlayer: InternalPlaybackPlayer
    @State private var playerCoordinator: any PlayerCoordinating
    @State private var controlsVisible = true
    @State private var hideControlsWorkItem: DispatchWorkItem?
    @State private var isScrubbing = false
    @State private var showingSettings = false
    @State private var audioTracks: [PlayerTrack] = []
    @State private var subtitleTracks: [PlayerTrack] = []
    @State private var settingsAudioTracks: [PlaybackSettingsTrack] = []
    @State private var settingsSubtitleTracks: [PlaybackSettingsTrack] = []
    @State private var selectedAudioTrackID: Int?
    @State private var selectedSubtitleTrackID: Int?
    @State private var playbackRate: Float = 1.0
    @State private var timelinePosition = 0.0
    @State private var isRotationLocked = false
    @State private var activePlaybackURL: URL?
    @State private var awaitingMediaLoad = false

    private let controlsHideDelay: TimeInterval = 3.0
    private var seekBackwardInterval: Double {
        Double(settingsManager.playback.seekBackwardSeconds)
    }

    private var seekForwardInterval: Double {
        Double(settingsManager.playback.seekForwardSeconds)
    }

    init(viewModel: PlayerViewModel, initialPlayer: InternalPlaybackPlayer, options: PlayerOptions) {
        _viewModel = State(initialValue: viewModel)
        activePlayer = initialPlayer
        _playerCoordinator = State(initialValue: PlayerFactory.makeCoordinator(for: initialPlayer, options: options))
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
                },
                onPlaybackEnded: {
                    dismissPlayer()
                },
                onMediaLoaded: {
                    handleMediaLoaded()
                },
            )
            .onAppear {
                showControls(temporarily: true)
            }
            .ignoresSafeArea()
        }
        .statusBarHidden()
        .overlay {
            ZStack {
                Color.clear
                    .contentShape(Rectangle())
                    .ignoresSafeArea()
                    .onTapGesture {
                        controlsVisible ? hideControls() : showControls(temporarily: true)
                    }

                if bindableViewModel.isBuffering {
                    bufferingOverlay
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
                }

                if bindableViewModel.showSkipIntroButton && !bindableViewModel.autoSkipIntro {
                    skipIntroButton
                        .transition(.move(edge: .trailing).combined(with: .opacity))
                }

                if controlsVisible {
                    PlayerControlsView(
                        title: bindableViewModel.title,
                        isPaused: bindableViewModel.isPaused,
                        isBuffering: bindableViewModel.isBuffering,
                        position: timelineBinding,
                        duration: bindableViewModel.duration,
                        bufferedAhead: bindableViewModel.bufferedAhead,
                        bufferBasePosition: bindableViewModel.position,
                        isScrubbing: isScrubbing,
                        onDismiss: { dismissPlayer() },
                        onShowSettings: showSettings,
                        onSeekBackward: { jump(by: -seekBackwardInterval) },
                        onPlayPause: togglePlayPause,
                        onSeekForward: { jump(by: seekForwardInterval) },
                        seekBackwardSeconds: settingsManager.playback.seekBackwardSeconds,
                        seekForwardSeconds: settingsManager.playback.seekForwardSeconds,
                        onScrubbingChanged: handleScrubbing(editing:),
                        isRotationLocked: isRotationLocked,
                        onToggleRotationLock: toggleRotationLock,
                        skipIntroStart: bindableViewModel.skipIntroStart,
                        skipIntroEnd: bindableViewModel.skipIntroEnd,
                        skipTitlesStart: bindableViewModel.skipTitlesStart,
                    )
                    .transition(.opacity)
                }
            }
        }
        .onAppear {
            showControls(temporarily: true)
            playerCoordinator.setPlaybackRate(playbackRate)
            startPlayback(url: bindableViewModel.streamURL)
            viewModel.onSeek = { [playerCoordinator] position in
                playerCoordinator.seek(to: position)
            }
        }
        .onDisappear {
            viewModel.handleStop()
            hideControlsWorkItem?.cancel()
            playerCoordinator.destruct()
            AppDelegate.orientationLock = .all
            isRotationLocked = false
        }
        .onChange(of: bindableViewModel.position) { _, newValue in
            guard !isScrubbing else { return }
            timelinePosition = newValue
        }
        .sheet(isPresented: $showingSettings) {
            PlaybackSettingsView(
                audioTracks: settingsAudioTracks,
                subtitleTracks: settingsSubtitleTracks,
                selectedAudioTrackID: selectedAudioTrackID,
                selectedSubtitleTrackID: selectedSubtitleTrackID,
                playbackRate: playbackRate,
                onSelectAudio: selectAudioTrack(_:),
                onSelectSubtitle: selectSubtitleTrack(_:),
                onSelectPlaybackRate: selectPlaybackRate(_:),
                onClose: { showingSettings = false },
            )
            .presentationDetents([.medium])
            .presentationBackground(.ultraThinMaterial)
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
                        .foregroundStyle(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(.ultraThinMaterial, in: Capsule(style: .continuous))
                }
            }
            .padding(.bottom, 60)
            .padding(.trailing, 20)
        }
    }

    private var bufferingOverlay: some View {
        HStack(spacing: 8) {
            ProgressView()
                .progressViewStyle(.circular)
                .tint(.white)

            Text("player.status.buffering")
                .font(.callout.weight(.semibold))
                .foregroundStyle(.white.opacity(0.9))
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

    private func showSettings() {
        refreshTracks()
        showingSettings = true
        hideControlsWorkItem?.cancel()
    }

    private func toggleRotationLock() {
        if isRotationLocked {
            AppDelegate.orientationLock = .all
            isRotationLocked = false
        } else {
            AppDelegate.lockToCurrentOrientation()
            isRotationLocked = true
        }
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

    private func jump(by seconds: Double) {
        playerCoordinator.seek(by: seconds)
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
        dismiss()
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

    private func startPlayback(url: URL) {
        guard activePlaybackURL != url else { return }
        activePlaybackURL = url
        awaitingMediaLoad = true
        playerCoordinator.play(url)
        playerCoordinator.setPlaybackRate(playbackRate)
        showControls(temporarily: true)
    }

    private func showControls(temporarily: Bool) {
        withAnimation(.easeInOut) {
            controlsVisible = true
        }

        if temporarily, !isScrubbing {
            scheduleControlsHide()
        } else {
            hideControlsWorkItem?.cancel()
        }
    }

    private func hideControls() {
        hideControlsWorkItem?.cancel()
        withAnimation(.easeInOut) {
            controlsVisible = false
        }
    }

    private func scheduleControlsHide() {
        hideControlsWorkItem?.cancel()

        let workItem = DispatchWorkItem {
            withAnimation(.easeInOut) {
                controlsVisible = false
            }
        }

        hideControlsWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + controlsHideDelay, execute: workItem)
    }
}
