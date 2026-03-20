//
//  Video.swift
//  StreamCinema
//
//  Created by Vladimír Bárta on 21.02.2026.
//

struct TvShow: MediaItem, MediaInfo, Hashable {
    let id: String
    let name: String
    let type: String //= "tvshow"
    let description: String?
    let url: String?
    let art: Art?
    let mediaType: String?
    let year: Int?
    let rating: Double?
    let duration: Int?
    let langs: [String]?
    let genres: [String]?
    let originalTitle: String?
    let season: Int?
    let episode: Int?
    let episodeTitle: String?
    
    // Hashable conformance
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    static func == (lhs: TvShow, rhs: TvShow) -> Bool {
        lhs.id == rhs.id
    }
}

extension TvShow {
    static let preview1 = TvShow(
        id: "1",
        name: "Vladimir - [B]CZ, EN, EN tit[/B] (2026)",
        type: "tvshow",
        description: "As a woman's life unravels, she becomes obsessed with her captivating new colleague. Full of sexy secrets, dark humor and complex characters, Vladimir is about what happens when a woman goes hell-bent to turn her fantasies into reality.",
        url: "/FGet/m_cCYo48yu4Df5",
        art: Art.previewTvShow1,
        mediaType: "tvshow",
        year: 2026,
        rating: nil,
        duration: 1729,
        langs: ["CZ", "EN", "EN tit"],
        genres: ["Drama", "Komedie"],
        originalTitle: "Vladimir",
        season: 1,
        episode: 1,
        episodeTitle: "We Have Always Lived in the Castle"
    )
    static let preview2 = TvShow(
        id: "2",
        name: "Y: Marshals - [B]CZ, EN, EN tit[/B] (2026)",
        type: "tvshow",
        description: "With the Yellowstone Ranch behind him, Kayce Dutton joins an elite unit of U.S. Marshals, combining his skills as a cowboy and Navy SEAL to bring range justice to Montana, where he and his teammates must balance family, duty and the high psychological cost that comes with serving as the last line of defense in the region's war on violence.",
        url: "/FGet/m_KwU8vuiDVOAo",
        art: Art.previewTvShow2,
        mediaType: "tvshow",
        year: 2026,
        rating: 8.3,
        duration: 2577,
        langs: ["CZ", "EN", "EN+tit"],
        genres: ["Western"],
        originalTitle: "Y: Marshals",
        season: 1,
        episode: 1,
        episodeTitle: "Piya Wiconi"
    )
    static let preview3 = TvShow(
        id: "3",
        name: "Mladý Sherlock - [B]CZ, EN, EN tit[/B] (2026)",
        type: "tvshow",
        description: "Sherlock Holmes is a disgraced young man – raw and unfiltered – when he finds himself wrapped up in a murder case that threatens his liberty. His first ever case unravels a globe-trotting conspiracy that changes his life forever.",
        url: "/FGet/m_5merMQIA3zFc",
        art: Art.previewTvShow3,
        mediaType: "tvshow",
        year: 2026,
        rating: 9.4,
        duration: 2879,
        langs: ["CZ", "EN", "EN tit"],
        genres: ["Akční", "Dobrodružný", "Mysteriózní"],
        originalTitle: "Mladý Sherlock",
        season: 6,
        episode: 1,
        episodeTitle: "The Case of the Killing Jar"
    )
    static let preview4 = TvShow(
        id: "4",
        name: "Kacken an der Havel - [B]CZ[/B] (2026)",
        type: "tvshow",
        description: "Ever since he can remember, Toni has wanted nothing more than to leave his hometown of Kacken and become a famous rapper. But even after 18 years in Berlin, his career still hasn't taken off and Toni makes a living as a pizza baker. Until his life is turned upside down when his mother dies while rescuing a duck and Toni has to return to Kacken. Unexpectedly, he's offered the career opportunity of a lifetime - yet at the same time, he must deal with his younger stepfather Johnny Carrera, the talking baby duck Tupac, and the other quirky villagers. And as if that weren't enough, his 13-year-old son Charly, whom he never knew about, suddenly shows up in his life...",
        url: "/FGet/m_4b50n0vFBYE3",
        art: Art.previewTvShow4,
        mediaType: "tvshow",
        year: 2026,
        rating: 7,
        duration: 2037,
        langs: ["CZ"],
        genres: ["Komedie"],
        originalTitle: "Kacken an der Havel",
        season: 1,
        episode: 2,
        episodeTitle: "Hi, My Name Is"
    )
}

