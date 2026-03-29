import SwiftUI

@MainActor
struct HomeTVView: View {
    @Environment(MediaFocusModel.self) private var focusModel
    @Environment(WatchHistoryManager.self) private var watchHistoryManager

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
        ZStack {
            Color("Background")
                .ignoresSafeArea()

            if let heroMedia {
                GeometryReader { proxy in
                    ZStack(alignment: .bottom) {
                        ZStack(alignment: .topLeading) {
                            MediaHeroBackgroundView(media: focusModel.focusedMedia ?? heroMedia)
                            MediaHeroContentView(media: focusModel.focusedMedia ?? heroMedia)
                                .frame(maxWidth: proxy.size.width * 0.60, maxHeight: .infinity, alignment: .topLeading)
                        }

                        homeContent
                            .frame(height: proxy.size.height * 0.60)
                    }
                }
            } else {
                emptyState
            }
        }
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
        .onChange(of: heroMedia?.id) { _, _ in
            updateInitialFocus()
        }
        .onAppear {
            updateInitialFocus()
        }
    }

    private var homeContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 32) {
                if !viewModel.continueWatching.isEmpty {
                    MediaHubSection(title: String(localized: "home.continueWatching")) {
                        MediaCarousel(
                            layout: .landscape,
                            items: viewModel.continueWatching,
                            showsLabels: false,
                            onSelectMedia: onSelectMedia,
                        )
                    }
                }

                if !viewModel.latestVideos.isEmpty {
                     MediaHubSection(title: String(localized: "home.latestVideos")) {
                         MediaCarousel(
                             layout: .portrait,
                             items: viewModel.latestVideos,
                             showsLabels: false,
                             onSelectMedia: onSelectMedia,
                         )
                     }
                 }

                 if !viewModel.latestShows.isEmpty {
                     MediaHubSection(title: String(localized: "home.latestShows")) {
                         MediaCarousel(
                             layout: .portrait,
                             items: viewModel.latestShows,
                             showsLabels: false,
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
            .padding(.trailing, 24)
        }
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            if viewModel.isLoading {
                ProgressView("home.loading")
            } else if let errorMessage = viewModel.errorMessage {
                Label(errorMessage, systemImage: "exclamationmark.triangle.fill")
                    .foregroundStyle(.red)
            } else {
                Text("common.empty.nothingToShow")
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var heroMedia: Media? {
        viewModel.continueWatching.first ?? viewModel.latestVideos.first ?? viewModel.latestShows.first
    }

    private func updateInitialFocus() {
        guard focusModel.focusedMedia == nil, let heroMedia else { return }
        focusModel.focusedMedia = heroMedia
    }
}
