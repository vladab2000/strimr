import SwiftUI

/// Volba kategorie, jazyka (dabing / titulky / bez rozlišení) a řazení na stránkách Filmy a Seriály
struct CatalogFilterBar: View {
    let genres: [CatalogGenre]
    /// Řazení, která umí aspoň jeden zdroj stránky
    var sortOptions: [CatalogSort] = CatalogSort.allCases
    let filter: CatalogFilter
    let onChange: (CatalogFilter) -> Void

    private static var allGenresTitle: String { String(localized: "catalog.filter.allGenres") }

    var body: some View {
        HStack(spacing: 12) {
            Menu {
                Picker("catalog.filter.category", selection: genreBinding) {
                    Text(Self.allGenresTitle).tag(String?.none)
                    ForEach(genres) { genre in
                        Text(genre.name).tag(Optional(genre.id))
                    }
                }
                .pickerStyle(.inline)
            } label: {
                Label(selectedGenreName, systemImage: "line.3.horizontal.decrease.circle")
            }
            #if os(macOS)
            .fixedSize()
            #endif

            Menu {
                Picker("catalog.filter.audio", selection: audioBinding) {
                    ForEach(CatalogAudio.allCases) { audio in
                        Text(audio.displayName).tag(audio)
                    }
                }
                .pickerStyle(.inline)
            } label: {
                Label(filter.audio.displayName, systemImage: "captions.bubble")
            }
            #if os(macOS)
            .fixedSize()
            #endif

            if sortOptions.count > 1 {
                Menu {
                    Picker("catalog.filter.sort", selection: sortBinding) {
                        ForEach(sortOptions) { sort in
                            Text(sort.displayName).tag(sort)
                        }
                    }
                    .pickerStyle(.inline)
                } label: {
                    Label(filter.sort.displayName, systemImage: "arrow.up.arrow.down")
                }
                #if os(macOS)
                .fixedSize()
                #endif
            }

            Spacer(minLength: 12)
        }
        #if os(iOS)
        .buttonStyle(.bordered)
        #endif
    }

    private var selectedGenreName: String {
        guard let id = filter.genre else { return Self.allGenresTitle }
        return genres.first { $0.id == id }?.name ?? Self.allGenresTitle
    }

    private var genreBinding: Binding<String?> {
        Binding(
            get: { filter.genre },
            set: { genre in
                var updated = filter
                updated.genre = genre
                onChange(updated)
            },
        )
    }

    private var sortBinding: Binding<CatalogSort> {
        Binding(
            get: { filter.sort },
            set: { sort in
                var updated = filter
                updated.sort = sort
                onChange(updated)
            },
        )
    }

    private var audioBinding: Binding<CatalogAudio> {
        Binding(
            get: { filter.audio },
            set: { audio in
                var updated = filter
                updated.audio = audio
                onChange(updated)
            },
        )
    }
}
