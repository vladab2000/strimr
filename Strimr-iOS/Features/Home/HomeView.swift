import SwiftUI

@MainActor
struct HomeView: View {
    @Environment(WatchHistoryManager.self) private var watchHistoryManager
    @Environment(FavoritesManager.self) private var favoritesManager
    @Environment(\.scenePhase) private var scenePhase
    @State var viewModel: HomeViewModel
    let onSelectMedia: (Media) -> Void

    init(
        viewModel: HomeViewModel,
        onSelectMedia: @escaping (Media) -> Void = { _ in },
    ) {
        _viewModel = State(initialValue: viewModel)
        self.onSelectMedia = onSelectMedia
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                if !viewModel.continueWatching.isEmpty {
                    MediaHubSection(title: String(localized: "home.continueWatching")) {
                        MediaCarousel(
                            layout: .landscape,
                            items: viewModel.continueWatching,
                            showsLabels: true,
                            onSelectMedia: onSelectMedia,
                        )
                    }
                }

                if !libraryItems.isEmpty {
                    MediaHubSection(title: String(localized: "home.library")) {
                        MediaCarousel(
                            layout: .portrait,
                            items: libraryItems,
                            showsLabels: true,
                            onSelectMedia: onSelectMedia,
                        )
                    }
                }

                if viewModel.isLoading, !hasContent {
                    ProgressView("home.loading")
                        .frame(maxWidth: .infinity)
                }

                if !hasContent, !viewModel.isLoading {
                    Text("common.empty.nothingToShow")
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 20)
        }
        .navigationTitle("tabs.home")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            viewModel.watchHistoryManager = watchHistoryManager
            await viewModel.load()
        }
        .onAppear {
            viewModel.refreshWatchStatus()
        }
        .onChange(of: watchHistoryManager.changeCounter) {
            viewModel.refreshWatchStatus()
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active {
                Task { await viewModel.reload() }
            }
        }
        .refreshable {
            await viewModel.reload()
        }
    }

    /// Filmy a seriály z knihovny (oblíbené)
    private var libraryItems: [Media] {
        watchHistoryManager.applyWatchOverrides(to: favoritesManager.favorites.filter { $0.itemType == .movie || $0.itemType == .tvshow })
    }

    private var hasContent: Bool {
        viewModel.hasContent || !libraryItems.isEmpty
    }
}
