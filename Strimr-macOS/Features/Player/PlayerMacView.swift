import SwiftUI

struct PlayerMacView: View {
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
            .ignoresSafeArea()
        }
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

                if controlsVisible {
                    PlayerControlsMacView(
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
                    )
                    .transition(.opacity)
                }
            }
        }
        .onAppear {
            showControls(temporarily: true)
            playerCoordinator.setPlaybackRate(playbackRate)
            startPlayback(url: bindableViewModel.streamURL)
        }
        .onDisappear {
            viewModel.handleStop()
            hideControlsWorkItem?.cancel()
            playerCoordinator.destruct()
        }
        .onChange(of: bindableViewModel.position) { _, newValue in
            guard !isScrubbing else { return }
            timelinePosition = newValue
        }
        .sheet(isPresented: $showingSettings) {
            MacPlaybackSettingsView(
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
            .frame(minWidth: 400, minHeight: 300)
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

// MARK: - Playback Settings Sheet

private struct MacPlaybackSettingsView: View {
    let audioTracks: [PlaybackSettingsTrack]
    let subtitleTracks: [PlaybackSettingsTrack]
    let selectedAudioTrackID: Int?
    let selectedSubtitleTrackID: Int?
    let playbackRate: Float
    let onSelectAudio: (Int?) -> Void
    let onSelectSubtitle: (Int?) -> Void
    let onSelectPlaybackRate: (Float) -> Void
    let onClose: () -> Void

    private let speedOptions: [Float] = [0.5, 0.75, 1.0, 1.25, 1.5, 1.75, 2.0]

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("settings.title")
                    .font(.headline)
                Spacer()
                Button(action: onClose) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal)
            .padding(.top)

            if !audioTracks.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("player.settings.audio")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .padding(.horizontal)

                    ForEach(audioTracks) { track in
                        Button {
                            onSelectAudio(track.id)
                        } label: {
                            HStack {
                                Text(track.displayTitle)
                                Spacer()
                                if selectedAudioTrackID == track.id {
                                    Image(systemName: "checkmark")
                                        .foregroundStyle(.brandPrimary)
                                }
                            }
                            .padding(.horizontal)
                            .padding(.vertical, 6)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            if !subtitleTracks.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("player.settings.subtitles")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .padding(.horizontal)

                    Button {
                        onSelectSubtitle(nil)
                    } label: {
                        HStack {
                            Text("player.settings.off")
                            Spacer()
                            if selectedSubtitleTrackID == nil {
                                Image(systemName: "checkmark")
                                    .foregroundStyle(.brandPrimary)
                            }
                        }
                        .padding(.horizontal)
                        .padding(.vertical, 6)
                    }
                    .buttonStyle(.plain)

                    ForEach(subtitleTracks) { track in
                        Button {
                            onSelectSubtitle(track.id)
                        } label: {
                            HStack {
                                Text(track.displayTitle)
                                Spacer()
                                if selectedSubtitleTrackID == track.id {
                                    Image(systemName: "checkmark")
                                        .foregroundStyle(.brandPrimary)
                                }
                            }
                            .padding(.horizontal)
                            .padding(.vertical, 6)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("player.settings.speed")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal)

                ForEach(speedOptions, id: \.self) { speed in
                    Button {
                        onSelectPlaybackRate(speed)
                    } label: {
                        HStack {
                            Text(String(format: "%.2gx", speed))
                            Spacer()
                            if playbackRate == speed {
                                Image(systemName: "checkmark")
                                    .foregroundStyle(.brandPrimary)
                            }
                        }
                        .padding(.horizontal)
                        .padding(.vertical, 6)
                    }
                    .buttonStyle(.plain)
                }
            }

            Spacer()
        }
    }
}
