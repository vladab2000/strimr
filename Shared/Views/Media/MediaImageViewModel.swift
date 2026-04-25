import Foundation
import Observation

@MainActor
@Observable
final class MediaImageViewModel {
    enum ArtworkKind: String {
        case poster
        case art
    }

    var artworkKind: ArtworkKind
    var media: Media
    private(set) var imageURL: URL?

    init(artworkKind: ArtworkKind, media: Media) {
        self.artworkKind = artworkKind
        self.media = media
    }

    func load() async {
        imageURL = switch artworkKind {
        case .poster:
            media.posterURL ?? media.funartURL ?? media.thumbURL ?? media.logoURL
        case .art:
            media.funartURL ?? media.thumbURL ?? media.logoURL
        }
    }
}
