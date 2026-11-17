import Foundation
import Testing
@testable import Strimr_macOS

@MainActor
struct CatalogFilterTests {
    private func query(_ path: String) -> [String: String] {
        let items = URLComponents(string: path)?.queryItems ?? []
        return Dictionary(uniqueKeysWithValues: items.map { ($0.name, $0.value ?? "") })
    }

    @Test func defaultFilterHasAudioOnly() {
        let path = CatalogFilter().apply(to: "/uzi/films")
        #expect(path.hasPrefix("/uzi/films?"))
        #expect(query(path) == ["audio": "all"])
    }

    @Test func sortOnlyWhenNotNewest() {
        #expect(query(CatalogFilter(sort: .rating).apply(to: "/bombuj/films"))["sort"] == "rating")
        #expect(query(CatalogFilter(sort: .newest).apply(to: "/bombuj/films"))["sort"] == nil)
    }

    /// Nastavení ze starší verze (bez řazení) se načte s výchozím řazením, ne jako chyba
    @Test func decodesFilterWithoutSort() throws {
        let filter = try JSONDecoder().decode(CatalogFilter.self, from: Data(#"{"genre":"action","audio":"dub"}"#.utf8))
        #expect(filter == CatalogFilter(genre: "action", audio: .dub, sort: .newest))
    }

    @Test func sortSupportPerSource() {
        #expect(ContentSource.bombuj.supportedSorts(series: false).contains(.today))
        #expect(!ContentSource.bombuj.supportedSorts(series: true).contains(.today))
        #expect(ContentSource.oneplay.supportedSorts(series: false) == [.newest, .rating])
        #expect(ContentSource.uzi.supportedSorts(series: true) == [.newest])
    }

    @Test func genreAudioAndPage() {
        let filter = CatalogFilter(genre: "horror", audio: .dub)
        #expect(query(filter.apply(to: "/bombuj/series", page: 3)) == ["audio": "dub", "genre": "horror", "page": "3"])
    }
}

@MainActor
struct ContentSourceTests {
    @Test func sourceFromIdPrefix() {
        #expect(Fixtures.media(id: "bombuj:film:drak-2021").contentSource == .bombuj)
        #expect(Fixtures.media(id: "uzi:series:ludwig", kind: .tvshow).contentSource == .uzi)
        #expect(Fixtures.media(id: "oneplay:movie.4064").contentSource == .oneplay)
        #expect(Fixtures.media(id: "12345").contentSource == .streamCinema)
        #expect(Fixtures.media(id: "program-1", kind: .program).contentSource == nil)
    }
}
