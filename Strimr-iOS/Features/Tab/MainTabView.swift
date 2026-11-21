import SwiftUI

struct MainTabView: View {
    @Environment(SettingsManager.self) var settingsManager
    @Environment(WatchHistoryManager.self) var watchHistoryManager
    @StateObject var coordinator = MainCoordinator()
    @State var homeViewModel: HomeViewModel
    @State var moviesViewModel: CatalogViewModel
    @State var showsViewModel: CatalogViewModel

    init(homeViewModel: HomeViewModel, moviesViewModel: CatalogViewModel, showsViewModel: CatalogViewModel) {
        _homeViewModel = State(initialValue: homeViewModel)
        _moviesViewModel = State(initialValue: moviesViewModel)
        _showsViewModel = State(initialValue: showsViewModel)
    }

    var body: some View {
        let _ = coordinator.playbackLauncher = playbackLauncher
        TabView(selection: $coordinator.tab) {
            Tab("tabs.home", systemImage: "house.fill", value: MainCoordinator.Tab.home) {
                NavigationStack(path: coordinator.pathBinding(for: .home)) {
                    HomeView(
                        viewModel: homeViewModel,
                        onSelectMedia: coordinator.showMediaDetail
                    )
                    .navigationDestination(for: MainCoordinator.Route.self) {
                        destination(for: $0)
                    }
                }
            }

            Tab("tabs.search", systemImage: "magnifyingglass", value: MainCoordinator.Tab.search, role: .search) {
                NavigationStack(path: coordinator.pathBinding(for: .search)) {
                    SearchView(
                        viewModel: SearchViewModel(settingsManager: settingsManager),
                        onSelectMedia: coordinator.showMediaDetail,
                    )
                    .navigationDestination(for: MainCoordinator.Route.self) {
                        destination(for: $0)
                    }
                }
            }

            Tab("tabs.liveTV", systemImage: "tv.and.mediabox", value: MainCoordinator.Tab.channels) {
                NavigationStack(path: coordinator.pathBinding(for: .channels)) {
                    LiveTVView()
                        .navigationDestination(for: MainCoordinator.Route.self) {
                            destination(for: $0)
                        }
                }
            }

            Tab("tabs.movies", systemImage: "film.fill", value: MainCoordinator.Tab.movies) {
                NavigationStack(path: coordinator.pathBinding(for: .movies)) {
                    CatalogListView(
                        viewModel: moviesViewModel,
                        onSelectMedia: coordinator.showMediaDetail
                    )
                    .navigationDestination(for: MainCoordinator.Route.self) {
                        destination(for: $0)
                    }
                }
            }

            Tab("tabs.shows", systemImage: "play.rectangle.on.rectangle.fill", value: MainCoordinator.Tab.shows) {
                NavigationStack(path: coordinator.pathBinding(for: .shows)) {
                    CatalogListView(
                        viewModel: showsViewModel,
                        onSelectMedia: coordinator.showMediaDetail
                    )
                    .navigationDestination(for: MainCoordinator.Route.self) {
                        destination(for: $0)
                    }
                }
            }

            Tab("tabs.more", systemImage: "ellipsis.circle", value: MainCoordinator.Tab.more) {
                NavigationStack(path: coordinator.pathBinding(for: .more)) {
                    SettingsView()
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
        .fullScreenCover(isPresented: $coordinator.isPresentingPlayer, onDismiss: {
            coordinator.playerDidDismiss()
            Task { await watchHistoryManager.load() }
        }) {
            if let streamURL = coordinator.selectedStreamURL, let sessionId = coordinator.selectedSessionId {
                PlayerWrapper(
                    viewModel: makePlayerViewModel(streamURL: streamURL, sessionId: sessionId),
                )
            }
        }
    }

    @ViewBuilder
    private func destination(for route: MainCoordinator.Route) -> some View {
        switch route {
        case let .mediaDetail(media):
            MediaDetailView(
                viewModel: MediaDetailViewModel(media: media),
                onSelectMedia: coordinator.showMediaDetail
            )
        case let .streamSelection(media, streams):
            StreamSelectionView(
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

    private func makePlayerViewModel(streamURL: URL, sessionId: String) -> PlayerViewModel {
        let vm = PlayerViewModel(streamURL: streamURL, sessionId: sessionId, title: coordinator.selectedMedia?.title ?? "")
        vm.resumePosition = coordinator.selectedResumePosition
        vm.externalSubtitles = coordinator.selectedExternalSubtitles
        vm.drm = coordinator.selectedDrm
        vm.skipIntroStart = coordinator.selectedSkipIntroStart
        vm.skipIntroEnd = coordinator.selectedSkipIntroEnd
        vm.skipTitlesStart = coordinator.selectedSkipTitlesStart
        vm.autoSkipIntro = settingsManager.playback.autoSkipIntro

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
        coordinator.configureNextEpisode(for: vm, media: media, enabled: settingsManager.playback.autoPlayNextEpisode)
        coordinator.configureTrackPreferences(for: vm, media: media, settingsManager: settingsManager)
        return vm
    }
}
