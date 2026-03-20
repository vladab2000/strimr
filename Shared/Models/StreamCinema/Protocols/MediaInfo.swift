//
//  MediaInfo.swift
//  BartTV
//
//  Created by Vladimír Bárta on 15.03.2026.
//

protocol MediaInfo: MediaItem , MediaLangItem {
    var mediaType: String? { get }
    var year: Int? { get }
    var rating: Double? { get }
    var duration: Int? { get }
    var langs: [String]? { get }
    var genres: [String]? { get }
    var originalTitle: String? { get }
}


extension MediaInfo {
    var durationString: String? {
        guard let duration else { return nil }
        let totalMinutes = duration / 60
        let hours = totalMinutes / 60
        let minutes = totalMinutes % 60
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else {
            return "\(minutes)m"
        }
    }

    var genreString: String? {
        if let genres, !genres.isEmpty {
            return genres.joined(separator: " · ")
        }
        return nil
    }
}
