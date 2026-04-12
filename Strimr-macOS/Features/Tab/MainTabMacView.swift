import SwiftUI

struct MainTabMacView: View {
    @Environment(SettingsManager.self) var settingsManager
    @Environment(WatchHistoryManager.self) var watchHistoryManager
    @StateObject var coordinator = MainCoordinator()
    @State var homeViewModel: HomeViewModel
    @State private var selectedTab: MainCoordinator.Tab? = .home

    init(homeViewModel: HomeViewModel) {
        _homeViewModel = State(initialValue: homeViewModel)
    }

    var body: some View {
        let _ = coordinator.playbackLauncher = playbackLauncher
        NavigationSplitView {
            List(selection: $selectedTab) {
                Label("tabs.home", systemImage: "house.fill")
                    .tag(MainCoordinator.Tab.home)

                Label("tabs.library", systemImage: "books.vertical.fill")
                    .tag(MainCoordinator.Tab.library)

                Label("tabs.search", systemImage: "magnifyingglass")
                    .tag(MainCoordinator.Tab.search)

                Label("tabs.channels", systemImage: "tv")
                    .tag(MainCoordinator.Tab.channels)

                Label("tabs.epg", systemImage: "list.bullet.rectangle")
                    .tag(MainCoordinator.Tab.epg)

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
            case .library:
                NavigationStack(path: coordinator.pathBinding(for: .library)) {
                    LibraryMacView(
                        onSelectMedia: coordinator.showMediaDetail,
                    )
                    .navigationDestination(for: MainCoordinator.Route.self) { route in
                        destination(for: route)
                    }
                }
            case .search:
                NavigationStack(path: coordinator.pathBinding(for: .search)) {
                    SearchMacView(
                        viewModel: SearchViewModel(),
                        onSelectMedia: coordinator.showMediaDetail,
                    )
                    .navigationDestination(for: MainCoordinator.Route.self) { route in
                        destination(for: route)
                    }
                }
            case .channels:
                NavigationStack(path: coordinator.pathBinding(for: .channels)) {
                    ChannelsMacView()
                        .navigationDestination(for: MainCoordinator.Route.self) { route in
                            destination(for: route)
                        }
                }
            case .epg:
                NavigationStack(path: coordinator.pathBinding(for: .epg)) {
                    EPGMacView()
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
                ProgressView()
                    .controlSize(.large)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(.ultraThinMaterial)
            }
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
            coordinator.resetPlayer()
            Task { await watchHistoryManager.load() }
        }) {
            if let streamURL = coordinator.selectedStreamURL {
                PlayerMacWrapper(
                    viewModel: makePlayerViewModel(streamURL: streamURL),
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

    private func makePlayerViewModel(streamURL: URL) -> PlayerViewModel {
        let vm = PlayerViewModel(streamURL: streamURL, title: coordinator.selectedMedia?.title ?? "")
        vm.resumePosition = coordinator.selectedResumePosition

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
        }
        return vm
    }
}

