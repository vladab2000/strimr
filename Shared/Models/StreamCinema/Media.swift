//
//  Media.swift
//  Strimr
//
//  Created by Vladimír Bárta on 23.03.2026.
//

import Foundation

struct Media: Codable, Hashable, Identifiable {

    // MARK: - JSON properties

    let type: String?
    private let _id: String?
    let name: String?
    let url: String?
    let mediaType: String?
    let year: Int?
    let rating: Double?
    let duration: Int?
    let langs: [String]?
    let genres: [String]?
    let country: [String]?
    let description: String?
    let season: Int?
    let seasonTitle: String?
    let episode: Int?
    let episodeTitle: String?
    let art: Art?
    let streams: [Stream]?

    // Watch data
    let watchPosition: Int?
    let watchCompleted: Bool?
    let watchDuration: Int?
    let updatedUtc: Date?

    enum CodingKeys: String, CodingKey {
        case type
        case _id = "id"
        case name, url, mediaType, year, rating, duration
        case langs, genres, country
        case description
        case season, seasonTitle, episode, episodeTitle
        case art, streams
        case watchPosition, watchCompleted, watchDuration, updatedUtc
    }

    // MARK: - Identifiable

    var id: String { (_id ?? "") + (url ?? "") }

    // MARK: - Computed: type

    var itemType: SCItemType {
        guard let type else { return .unknown }
        return SCItemType(rawValue: type) ?? .unknown
    }

    var isPlayable: Bool {
        itemType == .movie || itemType == .episode
    }

    // MARK: - Computed: labels

    var title: String {
        name ?? ""
    }

    var primaryLabel: String {
        title
    }

    var secondaryLabel: String? {
        switch itemType {
        case .episode:
            if let episodeIdentifier, let episodeTitle, !episodeTitle.isEmpty && !episodeIdentifier.isEmpty {
                episodeIdentifier + " - " + episodeTitle
            }
            else {
                episodeIdentifier
            }
        case .season:
            seasonTitle
        default:
            year.map(String.init)
        }
    }

    var summary: String? {
        description
    }

    // MARK: - Computed: art URLs

    var thumbURL: URL? {
        if let thumb = art?.thumb, let url = URL(string: thumb) { return url }
        return nil
    }

    var funartURL: URL? {
        if let fanart = art?.fanart, let url = URL(string: fanart) { return url }
        return nil
    }

    var bannerURL: URL? {
        if let banner = art?.banner, let url = URL(string: banner) { return url }
        return nil
    }

    var posterURL: URL? {
        if let poster = art?.poster, let url = URL(string: poster) { return url }
        return nil
    }

    var clearlogoURL: URL? {
        if let clearlogo = art?.clearlogo, let url = URL(string: clearlogo) { return url }
        return nil
    }

    // MARK: - Computed: progress

    var progressFraction: Double? {
        guard let watchPosition, let duration, duration > 0 else { return nil }
        let fraction = Double(watchPosition) / Double(duration)
        guard fraction > 0 else { return nil }
        return min(1, max(0, fraction))
    }

    // MARK: - Computed: episode

    var seasonNumber: Int? { season }
    var episodeNumber: Int? { episode }

    var episodeIdentifier: String? {
        guard let season, let episode else { return nil }
        return String(format: "S%02dE%02d", season, episode)
    }

    // MARK: - Computed: lang (inlined from MediaLangItem)

    var isCZLang: Bool {
        if let langs, langs.contains("CZ") {
            return true
        }
        return false
    }

    var langString: String? {
        guard let langs, !langs.isEmpty else { return nil }
        var arr = langs
        if let idx = arr.firstIndex(where: { $0.caseInsensitiveCompare("CZ") == .orderedSame }) {
            let cz = arr.remove(at: idx)
            arr.insert(cz, at: 0)
        }
        return arr.joined(separator: ", ")
    }

    // MARK: - Computed: duration text (inlined from MediaInfo)

    var durationText: String? {
        guard let duration else { return nil }
        return TimeInterval(duration).mediaDurationText()
    }

    var genreString: String? {
        if let genres, !genres.isEmpty {
            return genres.joined(separator: " · ")
        }
        return nil
    }

    // MARK: - Hashable

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    static func == (lhs: Media, rhs: Media) -> Bool {
        lhs.id == rhs.id
    }

    // MARK: - Factory

    static func createSeason(from media: Media?) -> Media {
        let seasonNo = media?.season ?? 1
        let name = "Season \(seasonNo)"
        return Media(
            type: "season",
            _id: UUID().uuidString,
            name: media?.title,
            url: nil,
            mediaType: "season",
            year: media?.year,
            rating: media?.rating,
            duration: media?.duration,
            langs: media?.langs,
            genres: media?.genres,
            country: media?.country,
            description: media?.description,
            season: seasonNo,
            seasonTitle: name,
            episode: media?.episode,
            episodeTitle: media?.episodeTitle,
            art: media?.art,
            streams: nil,
            watchPosition: nil,
            watchCompleted: nil,
            watchDuration: nil,
            updatedUtc: nil
        )
    }
}

// MARK: - Preview Data

extension Media {
    static let preview1 = Media(
        type: "movie",
        _id: "1",
        name: "Los aitas",
        url: "/Play/m_jUX4kCmN98hj",
        mediaType: "video",
        year: 2025,
        rating: 5.7,
        duration: 5115,
        langs: ["CZ", "ES", "ES+tit"],
        genres: ["Komedie"],
        country: nil,
        description: "In the late 1980s, in a working-class neighborhood on the outskirts of Bilbao, Basque Country, Spain. A girls' rhythmic gymnastics team has the opportunity to compete in a tournament in Berlin; but since the girls' mothers cannot take time off work, it is the fathers who must accompany them on the trip.",
        season: nil, seasonTitle: nil, episode: nil, episodeTitle: nil,
        art: Art.preview1,
        streams: nil,
        watchPosition: nil, watchCompleted: nil, watchDuration: nil, updatedUtc: nil
    )
    static let preview2 = Media(
        type: "movie",
        _id: "2",
        name: "LEGO Frozen: Operation Puffins",
        url: "/Play/m_cC7w48yu4Df5",
        mediaType: "video",
        year: 2025,
        rating: 4.5,
        duration: 967,
        langs: ["CZ"],
        genres: ["Animovaný", "Komedie", "Rodinný", "Fantasy", "Krátkometrážní"],
        country: nil,
        description: "Po událostech ve filmu Ledové království chtějí Anna s Elsou začít v Arendellu nový život a udělat si hrad trochu útulnějším.",
        season: nil, seasonTitle: nil, episode: nil, episodeTitle: nil,
        art: Art.preview2,
        streams: nil,
        watchPosition: nil, watchCompleted: nil, watchDuration: nil, updatedUtc: nil
    )
    static let preview3 = Media(
        type: "movie",
        _id: "3",
        name: "Neporazitelní",
        url: "/Play/m_Pd2m65GFXC7R",
        mediaType: "video",
        year: 2025,
        rating: 8,
        duration: 7114,
        langs: ["CZ"],
        genres: ["Drama"],
        country: nil,
        description: "Tři zcela odlišní hrdinové a jejich rodiny vezmou diváky na emocionální a zábavnou jízdu.",
        season: nil, seasonTitle: nil, episode: nil, episodeTitle: nil,
        art: Art.preview3,
        streams: nil,
        watchPosition: nil, watchCompleted: nil, watchDuration: nil, updatedUtc: nil
    )
    static let preview4 = Media(
        type: "movie",
        _id: "4",
        name: "Predátor: Nebezpečné území",
        url: "/Play/m_A3Q7YWXMIyjY",
        mediaType: "video",
        year: 2025,
        rating: 7.8,
        duration: 6480,
        langs: ["CZ", "JA"],
        genres: ["Komedie"],
        country: nil,
        description: "Film se odehrává v budoucnosti na vzdálené planetě.",
        season: nil, seasonTitle: nil, episode: nil, episodeTitle: nil,
        art: Art.preview4,
        streams: nil,
        watchPosition: nil, watchCompleted: nil, watchDuration: nil, updatedUtc: nil
    )

    static let previewTvShow1 = Media(
        type: "tvshow",
        _id: "tv1",
        name: "Vladimir",
        url: "/FGet/m_cCYo48yu4Df5",
        mediaType: "tvshow",
        year: 2026,
        rating: nil,
        duration: 1729,
        langs: ["CZ", "EN", "EN tit"],
        genres: ["Drama", "Komedie"],
        country: nil,
        description: "As a woman's life unravels, she becomes obsessed with her captivating new colleague.",
        season: 1, seasonTitle: "Season 1", episode: 1, episodeTitle: "We Have Always Lived in the Castle",
        art: Art.previewTvShow1,
        streams: nil,
        watchPosition: nil, watchCompleted: nil, watchDuration: nil, updatedUtc: nil
    )
    static let previewTvShow2 = Media(
        type: "tvshow",
        _id: "tv2",
        name: "Y: Marshals",
        url: "/FGet/m_KwU8vuiDVOAo",
        mediaType: "tvshow",
        year: 2026,
        rating: 8.3,
        duration: 2577,
        langs: ["CZ", "EN", "EN+tit"],
        genres: ["Western"],
        country: nil,
        description: "With the Yellowstone Ranch behind him, Kayce Dutton joins an elite unit of U.S. Marshals.",
        season: 1, seasonTitle: "Season 1", episode: 1, episodeTitle: "Piya Wiconi",
        art: Art.previewTvShow2,
        streams: nil,
        watchPosition: nil, watchCompleted: nil, watchDuration: nil, updatedUtc: nil
    )
    static let previewTvShow3 = Media(
        type: "tvshow",
        _id: "tv3",
        name: "Mladý Sherlock",
        url: "/FGet/m_5merMQIA3zFc",
        mediaType: "tvshow",
        year: 2026,
        rating: 9.4,
        duration: 2879,
        langs: ["CZ", "EN", "EN tit"],
        genres: ["Akční", "Dobrodružný", "Mysteriózní"],
        country: nil,
        description: "Sherlock Holmes is a disgraced young man – raw and unfiltered – when he finds himself wrapped up in a murder case that threatens his liberty.",
        season: 6, seasonTitle: "Season 1", episode: 1, episodeTitle: "The Case of the Killing Jar",
        art: Art.previewTvShow3,
        streams: nil,
        watchPosition: nil, watchCompleted: nil, watchDuration: nil, updatedUtc: nil
    )
    static let previewTvShow4 = Media(
        type: "tvshow",
        _id: "tv4",
        name: "Kacken an der Havel",
        url: "/FGet/m_4b50n0vFBYE3",
        mediaType: "tvshow",
        year: 2026,
        rating: 7,
        duration: 2037,
        langs: ["CZ"],
        genres: ["Komedie"],
        country: nil,
        description: "Ever since he can remember, Toni has wanted nothing more than to leave his hometown of Kacken and become a famous rapper.",
        season: 1, seasonTitle: "Season 1", episode: 2, episodeTitle: "Hi, My Name Is",
        art: Art.previewTvShow4,
        streams: nil,
        watchPosition: nil, watchCompleted: nil, watchDuration: nil, updatedUtc: nil
    )

    static let previewEpisode1 = Media(
        type: "episode",
        _id: nil,
        name: "Mladý Sherlock",
        url: "/FGet/m_5merMQIA3zFc",
        mediaType: "episode",
        year: 2026,
        rating: 9.4,
        duration: 2879,
        langs: ["CZ", "EN", "EN tit"],
        genres: ["Akční", "Dobrodružný", "Mysteriózní"],
        country: nil,
        description: "Sherlock Holmes is a disgraced young man.",
        season: 6, seasonTitle: "Season 6", episode: 1, episodeTitle: "The Case of the Killing Jar",
        art: Art.previewTvShow3,
        streams: nil,
        watchPosition: nil, watchCompleted: nil, watchDuration: nil, updatedUtc: nil
    )
}
