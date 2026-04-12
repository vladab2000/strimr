import Foundation

enum PlaybackPlayer: String, Codable, CaseIterable, Identifiable {
    case vlc
    case mpv
    case infuse
    case avPlayer

    var id: String {
        rawValue
    }

    var localizationKey: String {
        switch self {
        case .mpv:
            "settings.playback.player.mpv"
        case .vlc:
            "settings.playback.player.vlc"
        case .infuse:
            "settings.playback.player.infuse"
        case .avPlayer:
            "settings.playback.player.avPlayer"
        }
    }

    var isExternal: Bool {
        self == .infuse
    }
}

enum InternalPlaybackPlayer: String, CaseIterable, Identifiable {
    case vlc
    case mpv
    case avPlayer

    var id: String {
        rawValue
    }

    init?(player: PlaybackPlayer) {
        switch player {
        case .vlc:
            self = .vlc
        case .mpv:
            self = .mpv
        case .avPlayer:
            self = .avPlayer
        case .infuse:
            return nil
        }
    }
}
