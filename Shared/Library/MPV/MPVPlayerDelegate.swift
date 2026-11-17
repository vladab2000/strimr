import Foundation

@MainActor
public protocol MPVPlayerDelegate: AnyObject {
    func propertyChange(mpv: OpaquePointer, property: PlayerProperty, data: Any?)
    func fileLoaded()
    func playbackEnded()
    /// Přehrávání skončilo chybou (výpadek spojení, nečitelný stream)
    func playbackFailed(_ message: String?)
}

public extension MPVPlayerDelegate {
    func playbackFailed(_: String?) {}
}
