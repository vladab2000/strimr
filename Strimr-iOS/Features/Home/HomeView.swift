import SwiftUI

@MainActor
struct HomeView: View {
    @State var viewModel: HomeViewModel

    init(viewModel: HomeViewModel = HomeViewModel()) {
        _viewModel = State(initialValue: viewModel)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                if !viewModel.latestVideos.isEmpty {
                    sectionView(
                        title: String(localized: "home.latestVideos"),
                        items: viewModel.latestVideos,
                    )
                }

                if !viewModel.latestSeries.isEmpty {
                    sectionView(
                        title: String(localized: "home.latestSeries"),
                        items: viewModel.latestSeries,
                    )
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

    @ViewBuilder
    private func sectionView(title: String, items: [any MediaItem]) -> some View {
        MediaHubSection(title: title) {
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(alignment: .top, spacing: 12) {
                    ForEach(items, id: \.id) { item in
                        StreamCinemaItemCard(item: item) {}
                    }
                }
                .padding(.horizontal, 2)
            }
        }
    }
}
