//
//  Media.swift
//  Strimr
//
//  Created by Vladimír Bárta on 23.03.2026.
//

import Foundation

struct Media: Codable, Hashable, Identifiable {

    // MARK: - JSON properties

    let kind: SCItemType
    let id: String
    let name: String
    let description: String?
    let url: String
    let art: [String: String]?
    let details: MediaDetailsVariant?

    // Watch data
    var watchPosition: Int?
    var watchCompleted: Bool?
    var isFavorite: Bool?
    let updatedUtc: Date?

    enum CodingKeys: String, CodingKey {
        case kind, id, name, description, url, art, details
        case watchPosition, watchCompleted, isFavorite, updatedUtc
    }

    // MARK: - Custom Codable for polymorphic details

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        kind = try container.decode(SCItemType.self, forKey: .kind)
        id = try container.decode(String.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        description = try container.decodeIfPresent(String.self, forKey: .description)
        url = try container.decode(String.self, forKey: .url)
        art = try container.decodeIfPresent([String: String].self, forKey: .art)
        watchPosition = try container.decodeIfPresent(Int.self, forKey: .watchPosition)
        watchCompleted = try container.decodeIfPresent(Bool.self, forKey: .watchCompleted)
        isFavorite = try container.decodeIfPresent(Bool.self, forKey: .isFavorite)
        updatedUtc = try container.decodeIfPresent(Date.self, forKey: .updatedUtc)

        // Polymorphic details decoding based on kind
        switch kind {
        case .movie, .tvshow, .season, .episode:
            if let d = try container.decodeIfPresent(PlayableMediaDetails.self, forKey: .details) {
                details = .playable(d)
            } else {
                details = nil
            }
        case .channel:
            if let d = try container.decodeIfPresent(ChannelDetails.self, forKey: .details) {
                details = .channel(d)
            } else {
                details = nil
            }
        case .program:
            if let d = try container.decodeIfPresent(ProgramDetails.self, forKey: .details) {
                details = .program(d)
            } else {
                details = nil
            }
        default:
            details = nil
        }
    }

    // Manual memberwise init for preview data and factory methods
    init(
        kind: SCItemType,
        id: String,
        name: String,
        description: String?,
        url: String,
        art: [String: String]?,
        details: MediaDetailsVariant?,
        watchPosition: Int?,
        watchCompleted: Bool?,
        isFavorite: Bool?,
        updatedUtc: Date?,
    ) {
        self.kind = kind
        self.id = id
        self.name = name
        self.description = description
        self.url = url
        self.art = art
        self.details = details
        self.watchPosition = watchPosition
        self.watchCompleted = watchCompleted
        self.isFavorite = isFavorite
        self.updatedUtc = updatedUtc
    }

    // MARK: - Computed: type

    var itemType: SCItemType { kind }

    // MARK: - Computed: detail accessors (delegate to details)

    var year: Int? { details?.year }
    var rating: Double? { details?.rating }
    var duration: Int? { details?.duration }
    var langs: [String]? { details?.langs }
    var genres: [String]? { details?.genres }
    var country: [String]? { details?.country }
    var season: Int? { details?.season }
    var seasonTitle: String? { details?.seasonTitle }
    var episode: Int? { details?.episode }
    var episodeTitle: String? { details?.episodeTitle }
    var streams: [Stream]? { details?.streams }

    // Channel-specific
    var hasArchive: Bool? { details?.hasArchive }
    var channelNumber: Int? { details?.number }

    // Program-specific
    var programStart: Date? { details?.start }
    var programEnd: Date? { details?.end }
    var channelId: String? { details?.channelId }

    // MARK: - Computed: labels

    var title: String {
        name
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
        if let thumb = art?["thumb"], let url = URL(string: thumb) { return url }
        return nil
    }

    var funartURL: URL? {
        if let fanart = art?["fanart"], let url = URL(string: fanart) { return url }
        return nil
    }

    var bannerURL: URL? {
        if let banner = art?["banner"], let url = URL(string: banner) { return url }
        return nil
    }

    var posterURL: URL? {
        if let poster = art?["poster"], let url = URL(string: poster) { return url }
        return nil
    }

    var clearlogoURL: URL? {
        if let clearlogo = art?["clearlogo"], let url = URL(string: clearlogo) { return url }
        return nil
    }

    var logoURL: URL? {
        if let logo = art?["logo"], let url = URL(string: logo) { return url }
        return nil
    }

    var isFullyWatched: Bool {
        switch itemType {
        case .movie, .episode:
            return watchCompleted ?? false
        case .tvshow, .season:
            return watchCompleted ?? false  //TODO: Implementovat počet epizod a sériií + počet shlédnutých
        default:
            return false
        }
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

    var remainingUnwatchedEpisodes: Int? {
        return nil   //TODO: Implementovat počet epizod a sériií + počet shlédnutých
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
            && lhs.watchCompleted == rhs.watchCompleted
            && lhs.watchPosition == rhs.watchPosition
    }

    // MARK: - Factory

    static func createSeason(from media: Media?) -> Media {
        let seasonNo = media?.season ?? 1
        let name = "Season \(seasonNo)"
        return Media(
            kind: .season,
            id: UUID().uuidString,
            name: name,
            description: media?.description,
            url: "",
            art: media?.art,
            details: .base(MediaDetails(
                year: media?.year,
                rating: media?.rating,
                duration: media?.duration,
                langs: media?.langs,
                genres: media?.genres,
                country: media?.country
            )),
            watchPosition: nil,
            watchCompleted: nil,
            isFavorite: nil,
            updatedUtc: nil
        )
    }
}

// MARK: - Preview Data

extension Media {
    static let empty = Media(
        kind: .movie,
        id: "",
        name: "",
        description: "",
        url: "",
        art: nil,
        details: nil,
        watchPosition: nil, watchCompleted: nil, isFavorite: nil, updatedUtc: nil

    )
    static let preview1 = Media(
        kind: .movie,
        id: "1",
        name: "Los aitas",
        description: "In the late 1980s, in a working-class neighborhood on the outskirts of Bilbao, Basque Country, Spain. A girls' rhythmic gymnastics team has the opportunity to compete in a tournament in Berlin; but since the girls' mothers cannot take time off work, it is the fathers who must accompany them on the trip.",
        url: "/Play/m_jUX4kCmN98hj",
        art: ArtPreview.preview1,
        details: .playable(PlayableMediaDetails(
            year: 2025, rating: 5.7, duration: 5115,
            langs: ["CZ", "ES", "ES+tit"], genres: ["Komedie"], country: nil,
            season: nil, seasonTitle: nil, episode: nil, episodeTitle: nil, streams: nil
        )),
        watchPosition: nil, watchCompleted: nil, isFavorite: nil, updatedUtc: nil
    )
    static let preview2 = Media(
        kind: .movie,
        id: "2",
        name: "LEGO Frozen: Operation Puffins",
        description: "Po událostech ve filmu Ledové království chtějí Anna s Elsou začít v Arendellu nový život a udělat si hrad trochu útulnějším.",
        url: "/Play/m_cC7w48yu4Df5",
        art: ArtPreview.preview2,
        details: .playable(PlayableMediaDetails(
            year: 2025, rating: 4.5, duration: 967,
            langs: ["CZ"], genres: ["Animovaný", "Komedie", "Rodinný", "Fantasy", "Krátkometrážní"], country: nil,
            season: nil, seasonTitle: nil, episode: nil, episodeTitle: nil, streams: nil
        )),
        watchPosition: nil, watchCompleted: nil, isFavorite: nil, updatedUtc: nil
    )
    static let preview3 = Media(
        kind: .movie,
        id: "3",
        name: "Neporazitelní",
        description: "Tři zcela odlišní hrdinové a jejich rodiny vezmou diváky na emocionální a zábavnou jízdu.",
        url: "/Play/m_Pd2m65GFXC7R",
        art: ArtPreview.preview3,
        details: .playable(PlayableMediaDetails(
            year: 2025, rating: 8, duration: 7114,
            langs: ["CZ"], genres: ["Drama"], country: nil,
            season: nil, seasonTitle: nil, episode: nil, episodeTitle: nil, streams: nil
        )),
        watchPosition: nil, watchCompleted: nil, isFavorite: nil, updatedUtc: nil
    )
    static let preview4 = Media(
        kind: .movie,
        id: "4",
        name: "Predátor: Nebezpečné území",
        description: "Film se odehrává v budoucnosti na vzdálené planetě.",
        url: "/Play/m_A3Q7YWXMIyjY",
        art: ArtPreview.preview4,
        details: .playable(PlayableMediaDetails(
            year: 2025, rating: 7.8, duration: 6480,
            langs: ["CZ", "JA"], genres: ["Komedie"], country: nil,
            season: nil, seasonTitle: nil, episode: nil, episodeTitle: nil, streams: nil
        )),
        watchPosition: nil, watchCompleted: nil, isFavorite: nil, updatedUtc: nil
    )

    static let previewTvShow1 = Media(
        kind: .tvshow,
        id: "tv1",
        name: "Vladimir",
        description: "As a woman's life unravels, she becomes obsessed with her captivating new colleague.",
        url: "/FGet/m_cCYo48yu4Df5",
        art: ArtPreview.previewTvShow1,
        details: .base(MediaDetails(
            year: 2026, rating: nil, duration: 1729,
            langs: ["CZ", "EN", "EN tit"], genres: ["Drama", "Komedie"], country: nil
        )),
        watchPosition: nil, watchCompleted: nil, isFavorite: nil, updatedUtc: nil
    )
    static let previewTvShow2 = Media(
        kind: .tvshow,
        id: "tv2",
        name: "Y: Marshals",
        description: "With the Yellowstone Ranch behind him, Kayce Dutton joins an elite unit of U.S. Marshals.",
        url: "/FGet/m_KwU8vuiDVOAo",
        art: ArtPreview.previewTvShow2,
        details: .base(MediaDetails(
            year: 2026, rating: 8.3, duration: 2577,
            langs: ["CZ", "EN", "EN+tit"], genres: ["Western"], country: nil
        )),
        watchPosition: nil, watchCompleted: nil, isFavorite: nil, updatedUtc: nil
    )
    static let previewTvShow3 = Media(
        kind: .tvshow,
        id: "tv3",
        name: "Mladý Sherlock",
        description: "Sherlock Holmes is a disgraced young man – raw and unfiltered – when he finds himself wrapped up in a murder case that threatens his liberty.",
        url: "/FGet/m_5merMQIA3zFc",
        art: ArtPreview.previewTvShow3,
        details: .base(MediaDetails(
            year: 2026, rating: 9.4, duration: 2879,
            langs: ["CZ", "EN", "EN tit"], genres: ["Akční", "Dobrodružný", "Mysteriózní"], country: nil
        )),
        watchPosition: nil, watchCompleted: nil, isFavorite: nil, updatedUtc: nil
    )
    static let previewTvShow4 = Media(
        kind: .tvshow,
        id: "tv4",
        name: "Kacken an der Havel",
        description: "Ever since he can remember, Toni has wanted nothing more than to leave his hometown of Kacken and become a famous rapper.",
        url: "/FGet/m_4b50n0vFBYE3",
        art: ArtPreview.previewTvShow4,
        details: .base(MediaDetails(
            year: 2026, rating: 7, duration: 2037,
            langs: ["CZ"], genres: ["Komedie"], country: nil
        )),
        watchPosition: nil, watchCompleted: nil, isFavorite: nil, updatedUtc: nil
    )

    static let previewEpisode1 = Media(
        kind: .episode,
        id: "ep1",
        name: "Mladý Sherlock",
        description: "Sherlock Holmes is a disgraced young man.",
        url: "/FGet/m_5merMQIA3zFc",
        art: ArtPreview.previewTvShow3,
        details: .playable(PlayableMediaDetails(
            year: 2026, rating: 9.4, duration: 2879,
            langs: ["CZ", "EN", "EN tit"], genres: ["Akční", "Dobrodružný", "Mysteriózní"], country: nil,
            season: 6, seasonTitle: "Season 6", episode: 1, episodeTitle: "The Case of the Killing Jar", streams: nil
        )),
        watchPosition: nil, watchCompleted: nil, isFavorite: nil, updatedUtc: nil
    )
}
