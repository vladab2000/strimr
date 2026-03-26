import Foundation
import Observation

@MainActor
@Observable
final class StreamSelectionViewModel {
    let media: Media
    let streams: [Stream]
    var isResolvingStream = false
    var errorMessage: String?

    init(media: Media, streams: [Stream]) {
        self.media = media
        self.streams = streams
    }

    var heroImageURL: URL? {
        media.bannerURL ?? media.funartURL ?? media.posterURL
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
