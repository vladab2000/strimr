import Observation

@MainActor
@Observable
final class MediaFocusModel {
    var focusedMedia: PlexMediaItem?

    init(focusedMedia: PlexMediaItem? = nil) {
        self.focusedMedia = focusedMedia
    }
}
