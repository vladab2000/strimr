//
//  Season.swift
//  BartTV
//
//  Created by Vladimír Bárta on 09.03.2026.
//

struct Season: MediaItem, MediaInfo {
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
}
