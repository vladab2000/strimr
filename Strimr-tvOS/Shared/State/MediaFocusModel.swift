import Observation

@MainActor
@Observable
final class MediaFocusModel {
    var focusedMedia: Media? {
        didSet {
            print("[FocusModel] focusedMedia: '\(oldValue?.primaryLabel ?? "nil")' → '\(focusedMedia?.primaryLabel ?? "nil")' (id: \(focusedMedia?.id ?? "nil"))")
        }
    }

    init(focusedMedia: Media? = nil) {
        self.focusedMedia = focusedMedia
    }
}
