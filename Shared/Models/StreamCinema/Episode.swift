//
//  Episode.swift
//  BartTV
//
//  Created by Vladimír Bárta on 09.03.2026.
//

import Foundation

struct Episode: MediaItem, MediaInfo, Hashable {
    var id: String { url ?? ""}
    let name: String
    let type: String //= "episode"
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
    
    static func == (lhs: Episode, rhs: Episode) -> Bool {
        lhs.id == rhs.id
    }
}

extension Episode {
    var episodeIdentifier: String? {
        guard let season = season, let episode = episode else {
            return nil
        }
        return String(format: "S%02dE%02d", season, episode)
    }
    
    static let preview1 = Episode(
        name: "Mladý Sherlock - [B]CZ, EN, EN tit[/B] (2026)",
        type: "episode",
        description: "Sherlock Holmes is a disgraced young man – raw and unfiltered – when he finds himself wrapped up in a murder case that threatens his liberty. His first ever case unravels a globe-trotting conspiracy that changes his life forever.",
        url: "/FGet/m_5merMQIA3zFc",
        art: Art.previewTvShow3,
        mediaType: "episode",
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
}
