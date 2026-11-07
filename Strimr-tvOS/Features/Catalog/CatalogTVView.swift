import SwiftUI

/// Stránka Filmy / Seriály: náhled a popis vybrané dlaždice, filtr kategorie a jazyka, řada pro každý zdroj
@MainActor
struct CatalogTVView: View {
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
        let pageMedia = viewModel.rows.flatMap(\.items)

        MediaHeroPageTVView(heroMedia: pageMedia.first, pageMedia: pageMedia) {
            ScrollView {
                VStack(alignment: .leading, spacing: 32) {
                    filterBar
                    rowsContent
                }
                .padding(.trailing, 24)
            }
        } emptyState: {
            // I prázdný výsledek filtru musí jít změnit
            filterBar
            statusContent
        }
        .onAppear {
            viewModel.watchHistoryManager = watchHistoryManager
            viewModel.refreshWatchStatus()
            Task { await viewModel.load() }
        }
        .onChange(of: watchHistoryManager.changeCounter) {
            viewModel.refreshWatchStatus()
        }
    }

    private var filterBar: some View {
        CatalogFilterBar(
            genres: viewModel.genres,
            filter: viewModel.catalogFilter,
            onChange: viewModel.setCatalogFilter,
        )
    }

    @ViewBuilder
    private var rowsContent: some View {
        ForEach(viewModel.rows) { row in
            if !row.items.isEmpty {
                MediaHubSection(title: row.title) {
                    MediaCarousel(
                        layout: .portrait,
                        items: row.items,
                        showsLabels: false,
                        onSelectMedia: onSelectMedia,
                    )
                }
            }
        }

        statusContent
    }

    @ViewBuilder
    private var statusContent: some View {
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
}
