import Foundation

@MainActor
protocol PlayerCoordinating: AnyObject {
    func play(_ url: URL)
    func togglePlayback()
    func pause()
    func resume()
    func seek(to time: Double)
    func seek(by delta: Double)
    func setPlaybackRate(_ rate: Float)
    func selectAudioTrack(id: Int?)
    func selectSubtitleTrack(id: Int?)
    func trackList() -> [PlayerTrack]
    func destruct()
    /// Přidá externí titulky; volat po play(_:), přehrávač je načte až s videem
    func addExternalSubtitles(_ subtitles: [ExternalSubtitle])
}

extension PlayerCoordinating {
    // Přehrávače bez podpory externích titulků (VLC, AVPlayer) je ignorují
    func addExternalSubtitles(_: [ExternalSubtitle]) {}
}
