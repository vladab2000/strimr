import Foundation

enum MediaDisplayItem: Identifiable, Hashable {
    case video(Video)
    case tvshow(TvShow)
    case season(Season)
    case episode(Episode)

    var id: String {
        switch self {
        case let .video(item): item.id
        case let .tvshow(item): item.id
        case let .season(item): item.id
        case let .episode(item): item.id
        }
    }

    var type: SCItemType {
        switch self {
        case .video: .video
        case .tvshow: .tvshow
        case .season: .season
        case .episode: .episode
        }
    }

    var title: String {
        switch self {
        case let .video(item): item.name
        case let .tvshow(item): item.name
        case let .season(item): item.name
        case let .episode(item): item.name
        }
    }

    var summary: String? {
        switch self {
        case let .video(item): item.description
        case let .tvshow(item): item.description
        case let .season(item): item.description
        case let .episode(item): item.description
        }
    }

    var thumbURL: URL? {
        let art = artValue
        if let poster = art?.poster, let url = URL(string: poster) { return url }
        if let thumb = art?.thumb, let url = URL(string: thumb) { return url }
        return nil
    }

    var artURL: URL? {
        if let fanart = artValue?.fanart, let url = URL(string: fanart) { return url }
        return thumbURL
    }

    var primaryLabel: String {
        title
    }

    var secondaryLabel: String? {
        switch self {
        case let .video(item):
            item.year.map(String.init)
        case let .tvshow(item):
            item.year.map(String.init)
        case let .season(item):
            item.year.map(String.init)
        case let .episode(item):
            item.episodeIdentifier
        }
    }

    var year: Int? {
        switch self {
        case let .video(item): item.year
        case let .tvshow(item): item.year
        case let .season(item): item.year
        case let .episode(item): item.year
        }
    }

    var rating: Double? {
        switch self {
        case let .video(item): item.rating
        case let .tvshow(item): item.rating
        case let .season(item): item.rating
        case let .episode(item): item.rating
        }
    }

    var duration: Int? {
        switch self {
        case let .video(item): item.duration
        case let .tvshow(item): item.duration
        case let .season(item): item.duration
        case let .episode(item): item.duration
        }
    }

    var genres: [String]? {
        switch self {
        case let .video(item): item.genres
        case let .tvshow(item): item.genres
        case let .season(item): item.genres
        case let .episode(item): item.genres
        }
    }

    var url: String? {
        switch self {
        case let .video(item): item.url
        case let .tvshow(item): item.url
        case let .season(item): item.url
        case let .episode(item): item.url
        }
    }

    private var artValue: Art? {
        switch self {
        case let .video(item): item.art
        case let .tvshow(item): item.art
        case let .season(item): item.art
        case let .episode(item): item.art
        }
    }

    // MARK: - Init from protocol

    init?(from item: any MediaItem) {
        if let video = item as? Video {
            self = .video(video)
        } else if let tvshow = item as? TvShow {
            self = .tvshow(tvshow)
        } else if let season = item as? Season {
            self = .season(season)
        } else if let episode = item as? Episode {
            self = .episode(episode)
        } else {
            return nil
        }
    }
}
