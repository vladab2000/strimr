import SwiftUI

struct MainTabMacView: View {
    @Environment(SettingsManager.self) var settingsManager
    @Environment(WatchHistoryManager.self) var watchHistoryManager
    @StateObject var coordinator = MainCoordinator()
    @State var homeViewModel: HomeViewModel
    @State var moviesViewModel: CatalogViewModel
    @State var showsViewModel: CatalogViewModel
    @State private var selectedTab: MainCoordinator.Tab? = .home

    init(homeViewModel: HomeViewModel, moviesViewModel: CatalogViewModel, showsViewModel: CatalogViewModel) {
        _homeViewModel = State(initialValue: homeViewModel)
        _moviesViewModel = State(initialValue: moviesViewModel)
        _showsViewModel = State(initialValue: showsViewModel)
    }

    var body: some View {
        let _ = coordinator.playbackLauncher = playbackLauncher
        NavigationSplitView {
            List(selection: $selectedTab) {
                Label("tabs.home", systemImage: "house.fill")
                    .tag(MainCoordinator.Tab.home)

                Label("tabs.liveTV", systemImage: "tv.and.mediabox")
                    .tag(MainCoordinator.Tab.channels)

                Label("tabs.movies", systemImage: "film.fill")
                    .tag(MainCoordinator.Tab.movies)

                Label("tabs.shows", systemImage: "play.rectangle.on.rectangle.fill")
                    .tag(MainCoordinator.Tab.shows)

                Label("tabs.search", systemImage: "magnifyingglass")
                    .tag(MainCoordinator.Tab.search)

                Label("tabs.more", systemImage: "gearshape")
                    .tag(MainCoordinator.Tab.more)
            }
            .listStyle(.sidebar)
            .navigationTitle("Strimr")
        } detail: {
            switch selectedTab ?? .home {
            case .home:
                NavigationStack(path: coordinator.pathBinding(for: .home)) {
                    HomeMacView(
                        viewModel: homeViewModel,
                        onSelectMedia: coordinator.showMediaDetail,
                    )
                    .navigationDestination(for: MainCoordinator.Route.self) { route in
                        destination(for: route)
                    }
                }
            case .movies, .shows:
                let isMovies = (selectedTab ?? .home) == .movies
                NavigationStack(path: coordinator.pathBinding(for: isMovies ? .movies : .shows)) {
                    CatalogListView(
                        viewModel: isMovies ? moviesViewModel : showsViewModel,
                        onSelectMedia: coordinator.showMediaDetail,
                    )
                    .id(isMovies)
                    .navigationDestination(for: MainCoordinator.Route.self) { route in
                        destination(for: route)
                    }
                }
            case .search:
                NavigationStack(path: coordinator.pathBinding(for: .search)) {
                    SearchMacView(
                        viewModel: SearchViewModel(settingsManager: settingsManager),
                        onSelectMedia: coordinator.showMediaDetail,
                    )
                    .navigationDestination(for: MainCoordinator.Route.self) { route in
                        destination(for: route)
                    }
                }
            case .channels:
                NavigationStack(path: coordinator.pathBinding(for: .channels)) {
                    LiveTVMacView()
                        .navigationDestination(for: MainCoordinator.Route.self) { route in
                            destination(for: route)
                        }
                }
            case .more:
                NavigationStack(path: coordinator.pathBinding(for: .more)) {
                    SettingsMacView()
                }
            }
        }
        .overlay {
            if coordinator.isLoadingStreams {
                ProgressView {
                    if let message = coordinator.loadingMessage {
                        Text(message)
                    }
                }
                    .controlSize(.large)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(.ultraThinMaterial)
            }
        }
        .alert(
            "player.error.title",
            isPresented: Binding(
                get: { coordinator.errorMessage != nil },
                set: { if !$0 { coordinator.errorMessage = nil } }
            ),
            presenting: coordinator.errorMessage
        ) { _ in
            Button("OK", role: .cancel) {}
        } message: { message in
            Text(message)
        }
        .alert(
            "player.confirm.title",
            isPresented: Binding(
                get: { coordinator.playbackConfirmation != nil },
                set: { if !$0 { coordinator.playbackConfirmation = nil } }
            ),
            presenting: coordinator.playbackConfirmation
        ) { confirmation in
            Button("player.confirm.play") { confirmation.onConfirm() }
            Button("common.actions.cancel", role: .cancel) {}
        } message: { confirmation in
            Text(confirmation.message)
        }
        .environmentObject(coordinator)
        .onChange(of: selectedTab) { _, newTab in
            if let tab = newTab {
                coordinator.tab = tab
            }
        }
        .onChange(of: coordinator.tab) { _, newTab in
            selectedTab = newTab
        }
        .sheet(isPresented: $coordinator.isPresentingPlayer, onDismiss: {
            coordinator.playerDidDismiss()
            Task { await watchHistoryManager.load() }
        }) {
            if let streamURL = coordinator.selectedStreamURL, let sessionId = coordinator.selectedSessionId {
                PlayerMacWrapper(
                    viewModel: makePlayerViewModel(streamURL: streamURL, sessionId: sessionId),
                )
                .frame(minWidth: 800, minHeight: 450)
            }
        }
    }

    @ViewBuilder
    private func destination(for route: MainCoordinator.Route) -> some View {
        switch route {
        case let .mediaDetail(media):
            MediaDetailMacView(
                viewModel: MediaDetailViewModel(media: media),
                onSelectMedia: coordinator.showMediaDetail,
            )
        case let .streamSelection(media, streams):
            StreamSelectionMacView(
                viewModel: StreamSelectionViewModel(media: media, streams: streams),
                onPlay: { stream, _ in
                    Task {
                        await playbackLauncher.play(
                            stream: stream,
                            media: media,
                        )
                    }
                },
            )
        }
    }

    private var playbackLauncher: PlaybackLauncher {
        PlaybackLauncher(coordinator: coordinator, watchHistoryManager: watchHistoryManager)
    }

    private func makePlayerViewModel(streamURL: URL, sessionId: String) -> PlayerViewModel {
        let vm = PlayerViewModel(streamURL: streamURL, sessionId: sessionId, title: coordinator.selectedMedia?.title ?? "")
        vm.resumePosition = coordinator.selectedResumePosition
        vm.externalSubtitles = coordinator.selectedExternalSubtitles

        let media = coordinator.selectedMedia
        let isLiveChannel = media?.itemType == .channel
        let isProgram = media?.itemType == .program
        vm.isLive = isLiveChannel

        if !isLiveChannel, !isProgram {
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
                        position: position,
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
        coordinator.configureNextEpisode(for: vm, media: media, enabled: settingsManager.playback.autoPlayNextEpisode)
        coordinator.configureTrackPreferences(for: vm, media: media, settingsManager: settingsManager)
        return vm
    }
}

