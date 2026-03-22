import SwiftUI

struct MainTabView: View {
    @Environment(SettingsManager.self) var settingsManager
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
                        onSelectMedia: coordinator.showMediaDetail,
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
        .fullScreenCover(isPresented: $coordinator.isPresentingPlayer, onDismiss: coordinator.resetPlayer) {
            if let streamURL = coordinator.selectedStreamURL {
                PlayerWrapper(
                    viewModel: PlayerViewModel(
                        streamURL: streamURL,
                        title: coordinator.selectedStreamTitle,
                    ),
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
                onPlay: { stream in
                    Task {
                        await playbackLauncher.play(stream: stream)
                    }
                }
            )
        }
    }

    private var playbackLauncher: PlaybackLauncher {
        PlaybackLauncher(coordinator: coordinator)
    }
}
