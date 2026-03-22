import SwiftUI

struct MainTabTVView: View {
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
                    HomeTVView(
                        viewModel: homeViewModel,
                        onSelectMedia: coordinator.showMediaDetail,
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
        .environmentObject(coordinator)
        .fullScreenCover(isPresented: $coordinator.isPresentingPlayer, onDismiss: coordinator.resetPlayer) {
            if let streamURL = coordinator.selectedStreamURL {
                PlayerTVWrapper(
                    viewModel: PlayerViewModel(
                        streamURL: streamURL,
                        title: coordinator.selectedStreamTitle
                    ),
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
        case let .streamSelection(media):
            StreamSelectionTVView(
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
        PlaybackLauncher(
            coordinator: coordinator
        )
    }
}
