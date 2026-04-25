import SwiftUI

@MainActor
struct HomeMacView: View {
    @Environment(WatchHistoryManager.self) private var watchHistoryManager
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

                if !viewModel.latestVideos.isEmpty {
                    MediaHubSection(title: String(localized: "home.latestVideos")) {
                        MediaCarousel(
                            layout: .portrait,
                            items: viewModel.latestVideos,
                            showsLabels: true,
                            onSelectMedia: onSelectMedia,
                        )
                    }
                }

                if !viewModel.latestShows.isEmpty {
                    MediaHubSection(title: String(localized: "home.latestShows")) {
                        MediaCarousel(
                            layout: .portrait,
                            items: viewModel.latestShows,
                            showsLabels: true,
                            onSelectMedia: onSelectMedia,
                        )
                    }
                }

                if viewModel.isLoading, !viewModel.hasContent {
                    ProgressView("home.loading")
                        .frame(maxWidth: .infinity)
                }

                if let errorMessage = viewModel.errorMessage {
                    Label(errorMessage, systemImage: "exclamationmark.triangle.fill")
                        .foregroundStyle(.red)
                } else if !viewModel.hasContent, !viewModel.isLoading {
                    Text("common.empty.nothingToShow")
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 20)
        }
        .navigationTitle("tabs.home")
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
}
