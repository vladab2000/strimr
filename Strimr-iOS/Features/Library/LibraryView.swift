import SwiftUI

struct LibraryView: View {
    @Environment(FavoritesManager.self) private var favoritesManager
    let onSelectMedia: (Media) -> Void

    var body: some View {
        ScrollView {
            if favoritesManager.favoriteMovies.isEmpty, favoritesManager.favoriteShows.isEmpty {
                ContentUnavailableView(
                    String(localized: "library.empty.title"),
                    systemImage: "books.vertical",
                    description: Text("library.empty.description")
                )
                .padding(.top, 60)
            } else {
                VStack(alignment: .leading, spacing: 24) {
                    if !favoritesManager.favoriteMovies.isEmpty {
                        MediaHubSection(title: String(localized: "library.movies")) {
                            MediaCarousel(
                                layout: .portrait,
                                items: favoritesManager.favoriteMovies,
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
                                showsLabels: true,
                                onSelectMedia: onSelectMedia,
                            )
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 20)
            }
        }
        .navigationTitle("tabs.library")
        .navigationBarTitleDisplayMode(.inline)
        .refreshable {
            await favoritesManager.load()
        }
    }
}
