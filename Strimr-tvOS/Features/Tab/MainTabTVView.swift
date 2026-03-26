import SwiftUI

struct MainTabTVView: View {
    @Environment(SettingsManager.self) var settingsManager
    @Environment(WatchHistoryManager.self) var watchHistoryManager
    @StateObject var coordinator = MainCoordinator()
    @State var homeViewModel: HomeViewModel

    init(homeViewModel: HomeViewModel) {
        _homeViewModel = State(initialValue: homeViewModel)
    }

    var body: some View {
        let _ = coordinator.playbackLauncher = playbackLauncher
        TabView(selection: $coordinator.tab) {
            Tab("tabs.home", systemImage: "house.fill", value: MainCoordinator.Tab.home) {
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

            Tab("tabs.search", systemImage: "magnifyingglass", value: MainCoordinator.Tab.search, role: .search) {
                NavigationStack(path: coordinator.pathBinding(for: .search)) {
                    SearchTVView(
                        viewModel: SearchViewModel(),
                        onSelectMedia: coordinator.showMediaDetail,
                    )
                    .navigationDestination(for: MainCoordinator.Route.self) { route in
                        destination(for: route)
                    }
                }
            }

            Tab("tabs.more", systemImage: "ellipsis.circle", value: MainCoordinator.Tab.more) {
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
            if let streamURL = coordinator.selectedStreamURL {
                PlayerTVWrapper(
                    viewModel: makePlayerViewModel(streamURL: streamURL),
                    onExit: coordinator.resetPlayer,
                )
            }
        }
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
                onPlay: { stream, resumePosition in
                    Task {
                        await playbackLauncher.play(
                            stream: stream,
                            media: media,
                            resumePosition: resumePosition
                        )
                    }
                }
            )
        }
    }

    private var playbackLauncher: PlaybackLauncher {
        PlaybackLauncher(coordinator: coordinator, watchHistoryManager: watchHistoryManager)
    }

    private func makePlayerViewModel(streamURL: URL) -> PlayerViewModel {
        let vm = PlayerViewModel(streamURL: streamURL, title: coordinator.selectedStreamTitle)
        vm.mediaUrl = coordinator.selectedMediaUrl
        vm.resumePosition = coordinator.selectedResumePosition

        let mediaUrl = coordinator.selectedMediaUrl
        let season = coordinator.selectedSeasonNumber
        let episode = coordinator.selectedEpisodeNumber
        let manager = watchHistoryManager

        vm.onSavePosition = { position in
            guard let mediaUrl else { return }
            Task { @MainActor in
                await manager.updatePosition(
                    url: mediaUrl,
                    season: season,
                    episode: episode,
                    position: position
                )
            }
        }
        return vm
    }
}
