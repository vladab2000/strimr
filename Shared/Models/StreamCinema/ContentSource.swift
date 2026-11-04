import Foundation

enum ContentSource: String, Codable, CaseIterable, Identifiable {
    case streamCinema
    case bombuj
    case all

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .streamCinema: "StreamCinema"
        case .bombuj: "Bombuj"
        case .all: "Vše"
        }
    }

    var moviesPath: String {
        switch self {
        case .streamCinema: "/FMovies/latestd"
        case .bombuj: "/bombuj/films"
        case .all: "/FMovies/latestd"
        }
    }

    var showsPath: String {
        switch self {
        case .streamCinema: "/FSeries/latestd"
        case .bombuj: "/bombuj/series"
        case .all: "/FSeries/latestd"
        }
    }

    var bombujMoviesPath: String { "/bombuj/films" }
    var bombujShowsPath: String { "/bombuj/series" }

    var includesBombuj: Bool {
        self == .bombuj || self == .all
    }

    var includesSC: Bool {
        self == .streamCinema || self == .all
    }
}
