import Foundation

enum ContentSource: String, Codable, CaseIterable, Identifiable {
    case streamCinema
    case bombuj
    case uzi
    case oneplay
    case all

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .streamCinema: "StreamCinema"
        case .bombuj: "Bombuj"
        case .uzi: "uzi.la"
        case .oneplay: "OnePlay"
        case .all: String(localized: "contentSource.all")
        }
    }

    var moviesPath: String {
        switch self {
        case .streamCinema: "/FMovies/latestd"
        case .bombuj: "/bombuj/films"
        case .uzi: "/uzi/films"
        case .oneplay: "/oneplay/films"
        case .all: "/FMovies/latestd"
        }
    }

    var showsPath: String {
        switch self {
        case .streamCinema: "/FSeries/latestd"
        case .bombuj: "/bombuj/series"
        case .uzi: "/uzi/series"
        case .oneplay: "/oneplay/series"
        case .all: "/FSeries/latestd"
        }
    }

    var bombujMoviesPath: String { "/bombuj/films" }
    var bombujShowsPath: String { "/bombuj/series" }
    var uziMoviesPath: String { "/uzi/films" }
    var uziShowsPath: String { "/uzi/series" }

    var includesBombuj: Bool {
        self == .bombuj || self == .all
    }

    var includesSC: Bool {
        self == .streamCinema || self == .all
    }
}

extension ContentSource {
    /// Řazení, která zdroj umí (ostatní = výchozí pořadí). Bombuj podle nabídky webu, OnePlay nejnovější a hodnocení,
    /// uzi.la jen nejnovější (server prochází seznam po rocích)
    func supportedSorts(series: Bool) -> Set<CatalogSort> {
        switch self {
        case .bombuj: series ? [.newest, .rating, .year, .views] : Set(CatalogSort.allCases)
        case .oneplay: [.newest, .rating]
        case .uzi, .streamCinema, .all: [.newest]
        }
    }
}

extension Media {
    /// Zdroj filmu / seriálu podle prefixu id (Bombuj „bombuj:…“, uzi.la „uzi:…“, OnePlay „oneplay:…“, jinak StreamCinema);
    /// TV pořady nemají
    var contentSource: ContentSource? {
        if id.hasPrefix("bombuj:") { return .bombuj }
        if id.hasPrefix("uzi:") { return .uzi }
        if id.hasPrefix("oneplay:") { return .oneplay }
        switch itemType {
        case .movie, .tvshow, .season, .episode: return .streamCinema
        default: return nil
        }
    }
}
