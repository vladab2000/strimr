import SwiftUI

@MainActor
struct HomeView: View {
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
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
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
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await viewModel.load()
        }
        .refreshable {
            await viewModel.reload()
        }
    }
}
