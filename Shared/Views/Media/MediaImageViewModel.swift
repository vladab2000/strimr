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
            media.posterURL
        case .art:
            media.funartURL ?? media.logoURL
        }
    }
}
