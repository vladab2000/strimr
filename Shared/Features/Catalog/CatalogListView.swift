#if !os(tvOS)
import SwiftUI

/// Stránka Filmy / Seriály pro iOS a macOS: filtr kategorie a jazyka, řada pro každý zdroj (tvOS: CatalogTVView)
@MainActor
struct CatalogListView: View {
    @Environment(WatchHistoryManager.self) private var watchHistoryManager
    @State var viewModel: CatalogViewModel
    let onSelectMedia: (Media) -> Void

    init(
        viewModel: CatalogViewModel,
        onSelectMedia: @escaping (Media) -> Void = { _ in },
    ) {
        _viewModel = State(initialValue: viewModel)
        self.onSelectMedia = onSelectMedia
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                CatalogFilterBar(
                    genres: viewModel.genres,
                    filter: viewModel.catalogFilter,
                    onChange: viewModel.setCatalogFilter,
                )

                ForEach(viewModel.rows) { row in
                    if !row.items.isEmpty {
                        MediaHubSection(title: row.title) {
                            MediaCarousel(
                                layout: .portrait,
                                items: row.items,
                                showsLabels: true,
                                onSelectMedia: onSelectMedia,
                            )
                        }
                    }
                }

                if viewModel.isLoading, !viewModel.hasContent {
                    ProgressView("home.loading")
                        .frame(maxWidth: .infinity)
                } else if let errorMessage = viewModel.errorMessage {
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
        .navigationTitle(viewModel.kind.title)
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .onAppear {
            viewModel.watchHistoryManager = watchHistoryManager
            viewModel.refreshWatchStatus()
            Task { await viewModel.load() }
        }
        .onChange(of: watchHistoryManager.changeCounter) {
            viewModel.refreshWatchStatus()
        }
        .refreshable {
            await viewModel.reload()
        }
    }
}
#endif
