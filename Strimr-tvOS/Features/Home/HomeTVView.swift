import SwiftUI

@MainActor
struct HomeTVView: View {
    @Environment(MediaFocusModel.self) private var focusModel

    @State var viewModel: HomeViewModel
    let onSelectMedia: (MediaDisplayItem) -> Void

    init(
        viewModel: HomeViewModel,
        onSelectMedia: @escaping (MediaDisplayItem) -> Void = { _ in },
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
            await viewModel.load()
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

    private var heroMedia: MediaDisplayItem? {
        viewModel.latestVideos.first ?? viewModel.latestShows.first
    }

    private func updateInitialFocus() {
        guard focusModel.focusedMedia == nil, let heroMedia else { return }
        focusModel.focusedMedia = heroMedia
    }
}
