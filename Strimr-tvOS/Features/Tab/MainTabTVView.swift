import SwiftUI
import Combine

struct MainTabTVView: View {
    @Environment(SettingsManager.self) var settingsManager
    @Environment(WatchHistoryManager.self) var watchHistoryManager
    @Environment(ChannelProgramManager.self) var channelManager
    @StateObject var coordinator = MainCoordinator()
    @State var homeViewModel: HomeViewModel
    @State private var currentDate = Date()
    let timer = Timer.publish(every: 30, on: .main, in: .common).autoconnect()

    init(homeViewModel: HomeViewModel) {
        _homeViewModel = State(initialValue: homeViewModel)
    }
    
    var body: some View {
        let _ = coordinator.playbackLauncher = playbackLauncher

        ZStack(alignment: .topTrailing) {
            tabView()
            datetimeView()
        }
        .onReceive(timer) { input in
            currentDate = input
        }
    }

    fileprivate func tabView() -> some View {
        return TabView(selection: $coordinator.tab) {
            Tab("", systemImage: "house.fill", value: MainCoordinator.Tab.home) {
                NavigationStack(path: coordinator.pathBinding(for: .home)) {
                    HomeTVView(
                        viewModel: homeViewModel,
                        onSelectMedia: coordinator.showMediaDetail
                    )
                    .navigationDestination(for: MainCoordinator.Route.self) { route in
                        destination(for: route)
                    }
                }
            }
            
            Tab("tabs.liveTV", systemImage: "tv.fill", value: MainCoordinator.Tab.channels) {
                NavigationStack(path: coordinator.pathBinding(for: .channels)) {
                    LiveTVTVView()
                        .navigationDestination(for: MainCoordinator.Route.self) { route in
                            destination(for: route)
                        }
                }
            }
            
            Tab("tabs.library", systemImage: "books.vertical.fill", value: MainCoordinator.Tab.library) {
                NavigationStack(path: coordinator.pathBinding(for: .library)) {
                    LibraryTVView(
                        onSelectMedia: coordinator.showMediaDetail
                    )
                    .navigationDestination(for: MainCoordinator.Route.self) { route in
                        destination(for: route)
                    }
                }
            }
            
            Tab("", systemImage: "magnifyingglass", value: MainCoordinator.Tab.search, role: .search) {
                NavigationStack(path: coordinator.pathBinding(for: .search)) {
                    SearchTVView(
                        viewModel: SearchViewModel(settingsManager: settingsManager),
                        onSelectMedia: coordinator.showMediaDetail,
                    )
                    .navigationDestination(for: MainCoordinator.Route.self) { route in
                        destination(for: route)
                    }
                }
            }
            
            Tab("", systemImage: "gearshape.fill", value: MainCoordinator.Tab.more) {
                NavigationStack(path: coordinator.pathBinding(for: .more)) {
                    MoreTVView()
                        .navigationDestination(for: MoreTVRoute.self) { route in
                            switch route {
                            case .settings:
                                SettingsView()
                            }
                        }
                }
            }
        }
        .overlay {
            if coordinator.isLoadingStreams {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(.ultraThinMaterial)
            }
        }
        .environmentObject(coordinator)
        .fullScreenCover(isPresented: $coordinator.isPresentingPlayer, onDismiss: {
            coordinator.resetPlayer()
            Task { await watchHistoryManager.load() }
        }) {
            if let sessionId = coordinator.selectedSessionId, sessionId.isEmpty == false {
                AVPlayerTVView(
                    viewModel: makePlayerViewModel(streamURL: ApiClient.playbackURL(sessionId: sessionId), sessionId: sessionId),
                    onExit: coordinator.resetPlayer,
                )
            }
            else if let streamURL = coordinator.selectedStreamURL {
                PlayerTVWrapper(
                    viewModel: makePlayerViewModel(streamURL: streamURL, sessionId: ""),
                    onExit: coordinator.resetPlayer,
                )
            }
        }
    }
    
    fileprivate func datetimeView() -> some View {
        return VStack(alignment: .center, spacing: 2) {
            Text(currentDate, format: .dateTime.hour().minute())
                .font(.body)
                .bold()
            
            Text(currentDate, format: .dateTime.day().month().year())
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding()
        .background(.ultraThinMaterial)
        .cornerRadius(20)
        .padding(.top, -25)
        .padding(.trailing, 50)
    }
    
    
    @ViewBuilder
    private func destination(for route: MainCoordinator.Route) -> some View {
        switch route {
        case let .mediaDetail(media):
            MediaDetailTVView(
                viewModel: MediaDetailViewModel(media: media),
                onSelectMedia: coordinator.showMediaDetail
            )
        case let .streamSelection(media, streams):
            StreamSelectionTVView(
                viewModel: StreamSelectionViewModel(media: media, streams: streams),
                onPlay: { stream in
                    Task {
                        await playbackLauncher.play(
                            stream: stream,
                            media: media
                        )
                    }
                }
            )
        }
    }

    private var playbackLauncher: PlaybackLauncher {
        PlaybackLauncher(coordinator: coordinator, watchHistoryManager: watchHistoryManager)
    }

    private func makePlayerViewModel(streamURL: URL, sessionId: String = "") -> PlayerViewModel {
        let vm = PlayerViewModel(streamURL: streamURL, sessionId: sessionId, title: coordinator.selectedMedia?.title ?? "")
        vm.resumePosition = coordinator.selectedResumePosition
        vm.skipIntroStart = coordinator.selectedSkipIntroStart
        vm.skipIntroEnd = coordinator.selectedSkipIntroEnd
        vm.skipTitlesStart = coordinator.selectedSkipTitlesStart
        vm.autoSkipIntro = settingsManager.playback.autoSkipIntro

        let media = coordinator.selectedMedia
        let isLiveChannel = media?.itemType == .channel
        vm.isLive = isLiveChannel

        // Set metadata for native player info panel
        if let channel = coordinator.selectedChannel {
            vm.channelName = channel.title
        }
        else {
            vm.channelName = media?.secondaryLabel
        }
        vm.mediaDescription = media?.summary
        vm.artworkURL = media?.thumbURL ?? media?.posterURL
        vm.startDate = media?.programStart
        vm.endDate = media?.programEnd

        // Set up auto-next-program and go-to-live for channel playback
        if let channel = coordinator.selectedChannel {
            let channelMgr = channelManager
            let coord = coordinator

            // Go to live stream action
            vm.onGoToLive = {
                guard let playback = await channelMgr.resolveLivePlayback(for: channel) else { return nil }
                let currentProgram = await MainActor.run { channelMgr.currentProgram(for: channel) }

                let metadata = AVPlayerMetadata(
                    title: currentProgram?.title ?? channel.title,
                    subtitle: media?.secondaryLabel,
                    description: currentProgram?.summary,
                    artworkURL: currentProgram?.thumbURL ?? currentProgram?.posterURL ?? channel.thumbURL,
                    startDate: currentProgram?.programStart,
                    endDate: currentProgram?.programEnd
                )
                return (sessionId: playback.sessionId, title: currentProgram?.title ?? channel.title, metadata: metadata)
            }

            // Auto-next-program for archive program playback
            if coordinator.selectedProgram != nil {
                vm.onPlayNextProgram = {
                    let currentProgramId = await MainActor.run { coord.selectedProgram?.id }
                    guard let currentProgramId else { return nil }

                    let programs = await MainActor.run { channelMgr.programsByChannel[channel.id] ?? [] }
                    guard let idx = programs.firstIndex(where: { $0.id == currentProgramId }) else { return nil }
                    let nextIndex = programs.index(after: idx)
                    guard nextIndex < programs.endIndex else { return nil }

                    let nextProgram = programs[nextIndex]
                    // Only auto-play past programs (archive)
                    guard (nextProgram.programEnd ?? .distantFuture) < Date.now else { return nil }

                    guard let playback = await channelMgr.resolveArchivePlayback(channelId: channel.id, program: nextProgram) else { return nil }

                    // Update coordinator so subsequent calls find the correct "current"
                    await MainActor.run { coord.selectedProgram = nextProgram }

                    let metadata = AVPlayerMetadata(
                        title: nextProgram.title,
                        subtitle: media?.secondaryLabel,
                        description: nextProgram.summary,
                        artworkURL: nextProgram.thumbURL ?? nextProgram.posterURL,
                        startDate: nextProgram.programStart,
                        endDate: nextProgram.programEnd
                    )
                    return (sessionId: playback.sessionId, title: nextProgram.title, metadata: metadata)
                }
            }
        }

        if !isLiveChannel {
            let manager = watchHistoryManager

            vm.onCreateWatchRecord = {
                guard let media else { return }
                Task { @MainActor in
                    await manager.createWatchRecord(for: media)
                }
            }

            vm.onSavePosition = { position in
                guard let media else { return }
                Task { @MainActor in
                    await manager.updatePosition(
                        media: media,
                        position: position
                    )
                }
            }

            vm.onMarkWatched = {
                guard let media else { return }
                Task { @MainActor in
                    await manager.setWatched(media: media, watched: true)
                }
            }
        }
        return vm
    }
}
