//
//  Season.swift
//  BartTV
//
//  Created by Vladimír Bárta on 09.03.2026.
//

import Foundation

struct Season: MediaItem, MediaInfo, Hashable {
    let id: String
    let name: String
    let type: String //= "season"
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

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    static func == (lhs: Season, rhs: Season) -> Bool {
        lhs.id == rhs.id
    }
}

extension Season {
    static func create(from: TvShow?) -> Season {
        
        let seasonNo = from?.season ?? 1
        let name = "Season " + String(seasonNo)
        return Season(
            id: UUID().uuidString,
            name: name,
            type: "season",
            description: from?.description,
            url: nil,
            art: from?.art,
            mediaType: "season",
            year: from?.year,
            rating: from?.rating,
            duration: from?.duration,
            langs: from?.langs,
            genres: from?.genres,
            originalTitle: name,
            season: seasonNo,
            episode: from?.episode,
            episodeTitle: from?.episodeTitle
        )
    }
}
