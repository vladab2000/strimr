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

            Tab("tabs.library", systemImage: "books.vertical.fill", value: MainCoordinator.Tab.library) {
                NavigationStack(path: coordinator.pathBinding(for: .library)) {
                    LibraryView(
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

            Tab("tabs.more", systemImage: "ellipsis.circle", value: MainCoordinator.Tab.more) {
                NavigationStack(path: coordinator.pathBinding(for: .more)) {
                    SettingsView()
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
        .fullScreenCover(isPresented: $coordinator.isPresentingPlayer, onDismiss: {
            coordinator.resetPlayer()
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
        return vm
    }
}
