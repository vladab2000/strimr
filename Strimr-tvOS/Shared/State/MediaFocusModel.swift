import Observation

@MainActor
@Observable
final class MediaFocusModel {
    var focusedMedia: Media?

    init(focusedMedia: Media? = nil) {
        self.focusedMedia = focusedMedia
    }
}
