//
//  MediaDetails.swift
//  Strimr
//
//  Created by Vladimír Bárta on 06.04.2026.
//

import Foundation

/// Base details shared by all media kinds.
struct MediaDetails: Codable, Hashable {
    let year: Int?
    let rating: Double?
    let duration: Int?
    let langs: [String]?
    let genres: [String]?
    let country: [String]?
}

/// Additional details for playable media (movie, episode).
struct PlayableMediaDetails: Codable, Hashable {
    // Base details
    let year: Int?
    let rating: Double?
    let duration: Int?
    let langs: [String]?
    let genres: [String]?
    let country: [String]?

    // Playable-specific
    let season: Int?
    let seasonTitle: String?
    let episode: Int?
    let episodeTitle: String?
    let streams: [Stream]?
}

/// Details for channels.
struct ChannelDetails: Codable, Hashable {
    // Base details
    let year: Int?
    let rating: Double?
    let duration: Int?
    let langs: [String]?
    let genres: [String]?
    let country: [String]?

    // Channel-specific
    let isAdult: Bool?
    let hasArchive: Bool?
    let number: Int?
}

/// Details for programs.
struct ProgramDetails: Codable, Hashable {
    // Base details
    let year: Int?
    let rating: Double?
    let duration: Int?
    let langs: [String]?
    let genres: [String]?
    let country: [String]?

    // Program-specific
    let start: Date?
    let end: Date?
    let channelId: String?
    let channelName: String?
}

/// Wrapper enum for polymorphic details decoding based on `kind`.
enum MediaDetailsVariant: Codable, Hashable {
    case base(MediaDetails)
    case playable(PlayableMediaDetails)
    case channel(ChannelDetails)
    case program(ProgramDetails)

    // Common accessors
    var year: Int? {
        switch self {
        case .base(let d): d.year
        case .playable(let d): d.year
        case .channel(let d): d.year
        case .program(let d): d.year
        }
    }

    var rating: Double? {
        switch self {
        case .base(let d): d.rating
        case .playable(let d): d.rating
        case .channel(let d): d.rating
        case .program(let d): d.rating
        }
    }

    var duration: Int? {
        switch self {
        case .base(let d): d.duration
        case .playable(let d): d.duration
        case .channel(let d): d.duration
        case .program(let d): d.duration
        }
    }

    var langs: [String]? {
        switch self {
        case .base(let d): d.langs
        case .playable(let d): d.langs
        case .channel(let d): d.langs
        case .program(let d): d.langs
        }
    }

    var genres: [String]? {
        switch self {
        case .base(let d): d.genres
        case .playable(let d): d.genres
        case .channel(let d): d.genres
        case .program(let d): d.genres
        }
    }

    var country: [String]? {
        switch self {
        case .base(let d): d.country
        case .playable(let d): d.country
        case .channel(let d): d.country
        case .program(let d): d.country
        }
    }

    // Playable-specific
    var season: Int? {
        if case .playable(let d) = self { return d.season }
        return nil
    }

    var seasonTitle: String? {
        if case .playable(let d) = self { return d.seasonTitle }
        return nil
    }

    var episode: Int? {
        if case .playable(let d) = self { return d.episode }
        return nil
    }

    var episodeTitle: String? {
        if case .playable(let d) = self { return d.episodeTitle }
        return nil
    }

    var streams: [Stream]? {
        if case .playable(let d) = self { return d.streams }
        return nil
    }

    // Channel-specific
    var isAdult: Bool? {
        if case .channel(let d) = self { return d.isAdult }
        return nil
    }

    var hasArchive: Bool? {
        if case .channel(let d) = self { return d.hasArchive }
        return nil
    }

    var number: Int? {
        if case .channel(let d) = self { return d.number }
        return nil
    }

    // Program-specific
    var start: Date? {
        if case .program(let d) = self { return d.start }
        return nil
    }

    var end: Date? {
        if case .program(let d) = self { return d.end }
        return nil
    }

    var channelId: String? {
        if case .program(let d) = self { return d.channelId }
        return nil
    }

    var channelName: String? {
        if case .program(let d) = self { return d.channelName }
        return nil
    }

    var programState: ProgramState? {
        if case .program(let d) = self, let startTime = d.start, let endTime = d.end {
            let now = Date()
            if endTime < now { return .past }
            if startTime > now { return .future }
            return .current
        }
        return nil
    }
    
    // Codable: encode the inner value directly
    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .base(let d): try container.encode(d)
        case .playable(let d): try container.encode(d)
        case .channel(let d): try container.encode(d)
        case .program(let d): try container.encode(d)
        }
    }

    // Decoding is handled by Media's custom init(from:)
    init(from decoder: Decoder) throws {
        // Default: try base details. Media's init overrides this with the correct variant.
        let container = try decoder.singleValueContainer()
        let base = try container.decode(MediaDetails.self)
        self = .base(base)
    }
}
