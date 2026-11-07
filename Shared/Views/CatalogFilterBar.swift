import SwiftUI

/// Volba kategorie a jazyka (dabing / titulky / bez rozlišení) na stránkách Filmy a Seriály
struct CatalogFilterBar: View {
    let genres: [CatalogGenre]
    let filter: CatalogFilter
    let onChange: (CatalogFilter) -> Void

    private static let allGenresTitle = "Všechny kategorie"

    var body: some View {
        HStack(spacing: 12) {
            Menu {
                Picker("Kategorie", selection: genreBinding) {
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
                Picker("Jazyk", selection: audioBinding) {
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
