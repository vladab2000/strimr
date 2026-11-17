import Foundation

/// Jazyk seznamu filmů a seriálů
enum CatalogAudio: String, Codable, CaseIterable, Identifiable {
    case all
    case dub
    case tit

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .all: String(localized: "catalog.audio.all")
        case .dub: String(localized: "catalog.audio.dub")
        case .tit: String(localized: "catalog.audio.tit")
        }
    }
}

/// Řazení seznamu; zdroj, který ho neumí, zobrazí výchozí pořadí (ContentSource.supportedSorts)
enum CatalogSort: String, Codable, CaseIterable, Identifiable {
    case newest
    case rating
    case year
    case views
    case today

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .newest: String(localized: "catalog.sort.newest")
        case .rating: String(localized: "catalog.sort.rating")
        case .year: String(localized: "catalog.sort.year")
        case .views: String(localized: "catalog.sort.views")
        case .today: String(localized: "catalog.sort.today")
        }
    }
}

/// Kategorie (žánr) pro filtr — `id` (anglicky) se posílá serveru, `name` se zobrazuje
struct CatalogGenre: Codable, Equatable, Identifiable {
    let id: String
    let name: String
}

/// Filtr seznamů Filmy a Seriály (kategorie, jazyk, řazení). Server ho přeloží pro každý zdroj.
struct CatalogFilter: Codable, Equatable {
    /// `CatalogGenre.id` z `ApiClient.fetchCatalogGenres(source:)`; nil = všechny kategorie
    var genre: String?
    var audio: CatalogAudio = .all
    var sort: CatalogSort = .newest

    init(genre: String? = nil, audio: CatalogAudio = .all, sort: CatalogSort = .newest) {
        self.genre = genre
        self.audio = audio
        self.sort = sort
    }

    /// Uložené nastavení ze starší verze nemá řazení (ani jiné nové položky) — výchozí hodnoty místo chyby
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        genre = try container.decodeIfPresent(String.self, forKey: .genre)
        audio = (try? container.decodeIfPresent(CatalogAudio.self, forKey: .audio)) ?? .all
        sort = (try? container.decodeIfPresent(CatalogSort.self, forKey: .sort)) ?? .newest
    }

    /// "/uzi/films" → "/uzi/films?audio=dub&genre=horror&page=2"
    func apply(to path: String, page: Int? = nil) -> String {
        var components = URLComponents()
        components.path = path
        var items = [URLQueryItem(name: "audio", value: audio.rawValue)]
        if let genre {
            items.append(URLQueryItem(name: "genre", value: genre))
        }
        if sort != .newest {
            items.append(URLQueryItem(name: "sort", value: sort.rawValue))
        }
        if let page {
            items.append(URLQueryItem(name: "page", value: String(page)))
        }
        components.queryItems = items
        return components.string ?? path
    }
}
