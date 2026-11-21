import Foundation
import Observation

@MainActor
@Observable
final class StreamSelectionViewModel {
    var media: Media
    let streams: [Stream]
    var isResolvingStream = false
    var errorMessage: String?

    init(media: Media, streams: [Stream]) {
        self.media = media
        self.streams = streams
    }

    var heroImageURL: URL? {
        media.artURL("banner", width: Media.ArtSize.hero.width, height: Media.ArtSize.hero.height) ?? media.artURL("fanart", width: Media.ArtSize.hero.width, height: Media.ArtSize.hero.height) ?? media.posterURL
    }

    var yearText: String? {
        media.year.map(String.init)
    }

    var ratingText: String? {
        media.rating.map { String(format: "%.1f", $0) }
    }

    var runtimeText: String? {
        media.durationText
    }

    var genresText: String? {
        guard let genres = media.genres, !genres.isEmpty else { return nil }
        return genres.joined(separator: ", ")
    }
}
