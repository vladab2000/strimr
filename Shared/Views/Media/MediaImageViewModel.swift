import Foundation
import Observation

@MainActor
@Observable
final class MediaImageViewModel {
    enum ArtworkKind: String {
        case thumb
        case art
    }

    var artworkKind: ArtworkKind
    var media: MediaDisplayItem
    private(set) var imageURL: URL?

    init(artworkKind: ArtworkKind, media: MediaDisplayItem) {
        self.artworkKind = artworkKind
        self.media = media
    }

    func load() async {
        imageURL = switch artworkKind {
        case .thumb:
            media.thumbURL
        case .art:
            media.artURL
        }
    }
}
