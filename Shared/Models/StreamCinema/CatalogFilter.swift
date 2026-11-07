import Foundation

/// Jazyk seznamu filmů a seriálů
enum CatalogAudio: String, Codable, CaseIterable, Identifiable {
    case all
    case dub
    case tit

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .all: "Bez rozlišení"
        case .dub: "Dabing"
        case .tit: "Titulky"
        }
    }
}

/// Kategorie (žánr) pro filtr — `id` (anglicky) se posílá serveru, `name` se zobrazuje
struct CatalogGenre: Codable, Equatable, Identifiable {
    let id: String
    let name: String
}

/// Filtr seznamů na Home (kategorie + jazyk). Server ho přeloží pro každý zdroj (SC, Bombuj, uzi.la).
struct CatalogFilter: Codable, Equatable {
    /// `CatalogGenre.id` z `ApiClient.fetchCatalogGenres(source:)`; nil = všechny kategorie
    var genre: String?
    var audio: CatalogAudio = .all

    /// "/uzi/films" → "/uzi/films?audio=dub&genre=horror"
    func apply(to path: String) -> String {
        var components = URLComponents()
        components.path = path
        var items = [URLQueryItem(name: "audio", value: audio.rawValue)]
        if let genre {
            items.append(URLQueryItem(name: "genre", value: genre))
        }
        components.queryItems = items
        return components.string ?? path
    }
}
