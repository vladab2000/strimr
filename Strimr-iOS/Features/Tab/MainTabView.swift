import SwiftUI

struct MainTabView: View {
    @Environment(SettingsManager.self) var settingsManager
    @Environment(WatchHistoryManager.self) var watchHistoryManager
    @StateObject var coordinator = MainCoordinator()
    @State var homeViewModel: HomeViewModel

    init(homeViewModel: HomeViewModel) {
        _homeViewModel = State(initialValue: homeViewModel)
    }

    var body: some View {
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
                        viewModel: SearchViewModel(),
                        onSelectMedia: coordinator.showMediaDetail,
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
        .environmentObject(coordinator)
        .fullScreenCover(isPresented: $coordinator.isPresentingPlayer, onDismiss: {
            coordinator.resetPlayer()
            Task { await watchHistoryManager.load() }
        }) {
            if let streamURL = coordinator.selectedStreamURL {
                PlayerWrapper(
                    viewModel: makePlayerViewModel(streamURL: streamURL),
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
        case let .streamSelection(media):
            StreamSelectionView(
                viewModel: StreamSelectionViewModel(media: media),
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
        vm.mediaId = coordinator.selectedMediaId
        vm.resumePosition = coordinator.selectedResumePosition

        let mediaId = coordinator.selectedMediaId
        let season = coordinator.selectedSeasonNumber
        let episode = coordinator.selectedEpisodeNumber
        let manager = watchHistoryManager

        vm.onSavePosition = { position in
            guard let mediaId else { return }
            Task { @MainActor in
                await manager.updatePosition(
                    id: mediaId,
                    season: season,
                    episode: episode,
                    position: position
                )
            }
        }
        return vm
    }
}
