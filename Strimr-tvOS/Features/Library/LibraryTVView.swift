import SwiftUI

@MainActor
struct LibraryTVView: View {
    @Environment(MediaFocusModel.self) private var focusModel
    @Environment(FavoritesManager.self) private var favoritesManager
    let onSelectMedia: (Media) -> Void

    #if os(tvOS)
    @State private var favoriteMoviesSelectedID: Media.ID?
    @State private var favoriteShowsSelectedID: Media.ID?
    #endif

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

                        libraryContent
                            .frame(height: proxy.size.height * 0.60)
                    }
                }
            } else {
                ContentUnavailableView(
                    String(localized: "library.empty.title"),
                    systemImage: "books.vertical",
                    description: Text("library.empty.description")
                )
            }
        }
        .onChange(of: heroMedia?.id) { _, _ in
            updateInitialFocus()
        }
        .onAppear {
            updateInitialFocus()
        }
    }

    private var libraryContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 32) {
                if !favoritesManager.favoriteMovies.isEmpty {
                    MediaHubSection(title: String(localized: "library.movies")) {
                        MediaCarousel(
                            layout: .portrait,
                            items: favoritesManager.favoriteMovies,
                            selectedID: $favoriteMoviesSelectedID,
                            showsLabels: true,
                            onSelectMedia: onSelectMedia,
                        )
                    }
                }

                if !favoritesManager.favoriteShows.isEmpty {
                    MediaHubSection(title: String(localized: "library.shows")) {
                        MediaCarousel(
                            layout: .portrait,
                            items: favoritesManager.favoriteShows,
                            selectedID: $favoriteShowsSelectedID,
                            showsLabels: true,
                            onSelectMedia: onSelectMedia,
                        )
                    }
                }
            }
            .padding(.trailing, 24)
        }
    }

    private var heroMedia: Media? {
        favoritesManager.favoriteMovies.first ?? favoritesManager.favoriteShows.first
    }

    private func updateInitialFocus() {
        guard focusModel.focusedMedia == nil, let heroMedia else { return }
        focusModel.focusedMedia = heroMedia
    }
}
