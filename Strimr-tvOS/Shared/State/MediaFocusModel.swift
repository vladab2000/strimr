import Observation

@MainActor
@Observable
final class MediaFocusModel {
    var focusedMedia: MediaDisplayItem?

    init(focusedMedia: MediaDisplayItem? = nil) {
        self.focusedMedia = focusedMedia
    }
}
