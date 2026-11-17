import Foundation
@testable import Strimr_macOS

/// Testovací data: epizody, sezóny, pořady EPG, stopy přehrávače
enum Fixtures {
    static func episode(
        _ id: String,
        season: Int?,
        episode: Int?,
        watched: Bool? = nil,
        position: Int? = nil,
    ) -> Media {
        Media(
            kind: .episode, id: id, name: id, description: nil, url: "/\(id)", art: nil,
            details: .playable(playable(season: season, episode: episode)),
            watchPosition: position, watchCompleted: watched, isFavorite: nil, updatedUtc: nil,
        )
    }

    static func season(_ number: Int?) -> Media {
        Media(
            kind: .season, id: "season:\(number ?? 0)", name: "Sezóna \(number ?? 0)", description: nil,
            url: "/season/\(number ?? 0)", art: nil,
            details: .playable(playable(season: number, episode: nil)),
            watchPosition: nil, watchCompleted: nil, isFavorite: nil, updatedUtc: nil,
        )
    }

    static func media(id: String, kind: SCItemType = .movie) -> Media {
        Media(
            kind: kind, id: id, name: id, description: nil, url: "/\(id)", art: nil, details: nil,
            watchPosition: nil, watchCompleted: nil, isFavorite: nil, updatedUtc: nil,
        )
    }

    static func program(_ name: String, start: Date, minutes: Int = 30) -> Media {
        Media(
            kind: .program, id: name, name: name, description: nil, url: "/\(name)", art: nil,
            details: .program(ProgramDetails(
                year: nil, rating: nil, duration: minutes * 60, langs: nil, genres: nil, country: nil,
                start: start, end: start.addingTimeInterval(TimeInterval(minutes * 60)),
                channelId: "ch", channelName: "Kanál",
            )),
            watchPosition: nil, watchCompleted: nil, isFavorite: nil, updatedUtc: nil,
        )
    }

    static func track(_ id: Int, _ type: PlayerTrack.TrackType, language: String? = nil, title: String? = nil) -> PlayerTrack {
        PlayerTrack(id: id, ffIndex: nil, type: type, title: title, language: language, codec: nil, isDefault: false, isSelected: false)
    }

    /// Půlnoc UTC daného dne (klíče cache EPG)
    static func utcDay(_ year: Int, _ month: Int, _ day: Int, hour: Int = 0) -> Date {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        return calendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour))!
    }

    private static func playable(season: Int?, episode: Int?) -> PlayableMediaDetails {
        PlayableMediaDetails(
            year: nil, rating: nil, duration: nil, langs: nil, genres: nil, country: nil,
            season: season, seasonTitle: nil, episode: episode, episodeTitle: nil, streams: nil,
        )
    }
}
