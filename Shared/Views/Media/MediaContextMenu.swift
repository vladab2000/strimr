import SwiftUI

/// Kontextová nabídka dlaždice (dlouhý stisk): knihovna, zhlédnuto, odebrání z Pokračovat ve sledování
struct MediaContextMenu: View {
    @Environment(FavoritesManager.self) private var favoritesManager
    @Environment(WatchHistoryManager.self) private var watchHistoryManager
    let media: Media

    var body: some View {
        if media.itemType == .movie || media.itemType == .tvshow {
            let isFavorite = favoritesManager.isFavorite(media)
            Button {
                Task {
                    if isFavorite {
                        await favoritesManager.remove(media)
                    } else {
                        await favoritesManager.add(media)
                    }
                }
            } label: {
                Label(
                    isFavorite ? "library.removeFromLibrary" : "library.addToLibrary",
                    systemImage: isFavorite ? "heart.slash" : "heart"
                )
            }
        }

        // Pořady z TV archivu se do Pokračovat ve sledování ukládají taky
        if media.itemType == .movie || media.itemType == .episode || media.itemType == .program {
            let isWatched = media.watchCompleted ?? false
            Button {
                Task { await watchHistoryManager.setWatched(media: media, watched: !isWatched) }
            } label: {
                Label(
                    isWatched ? "library.removeWatched" : "library.setWatched",
                    systemImage: isWatched ? "eye.slash" : "eye"
                )
            }

            if (media.watchPosition ?? 0) > 0, !isWatched {
                Button(role: .destructive) {
                    Task { await watchHistoryManager.remove(media: media) }
                } label: {
                    Label("home.continueWatching.remove", systemImage: "xmark.circle")
                }
            }
        }
    }
}
