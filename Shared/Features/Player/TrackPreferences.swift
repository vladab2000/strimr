import Foundation

/// Zapamatovaná volba zvuku a titulků (pro seriál)
struct TrackChoice: Codable, Equatable {
    var audioLanguage: String?
    var subtitleLanguage: String?
    var subtitlesOff = false
}

/// Jazyk stopy z kódu nebo názvu ("cze", "CZ titulky", "Slovak"…) → "cs" / "sk" / "en"
enum TrackLanguage {
    /// Volby v nastavení; "" = neměnit
    static let audioOptions = ["", "cs", "sk", "en"]
    /// "off" = titulky vždy vypnout
    static let subtitleOptions = ["", "cs", "sk", "en", "off"]

    static func normalize(_ raw: String?) -> String? {
        guard let value = raw?.trimmingCharacters(in: .whitespaces).lowercased(), !value.isEmpty else { return nil }
        switch value {
        case "cs", "cz", "cze", "ces", "czech", "čeština", "cestina", "česky", "cesky", "dab", "dabing": return "cs"
        case "sk", "slo", "slk", "slovak", "slovenčina", "slovencina", "slovensky": return "sk"
        case "en", "eng", "english", "angličtina", "anglictina": return "en"
        default: return nil
        }
    }

    static func of(_ track: PlayerTrack) -> String? {
        if let language = normalize(track.language) {
            return language
        }
        // Název stopy: první slovo, které je jazykem ("CZ titulky", "English (SDH)")
        let words = (track.title ?? "").lowercased().split { !$0.isLetter }
        return words.lazy.compactMap { normalize(String($0)) }.first
    }

    static func displayName(_ code: String) -> String {
        switch code {
        case "": String(localized: "settings.playback.language.keep")
        case "off": String(localized: "settings.playback.language.off")
        default: Locale.current.localizedString(forLanguageCode: code)?.capitalized ?? code
        }
    }
}

/// Které stopy vybrat po načtení videa
struct TrackSelection: Equatable {
    enum Subtitle: Equatable {
        case keep
        case off
        case track(Int)
    }

    var audioID: Int?
    var subtitle: Subtitle = .keep

    /// Zapamatovaná volba seriálu má přednost; jinak nastavení: zvuk v preferovaném jazyce → bez titulků,
    /// jinak titulky v preferovaném jazyce
    static func resolve(
        tracks: [PlayerTrack],
        remembered: TrackChoice?,
        preferredAudio: String,
        preferredSubtitle: String,
    ) -> TrackSelection {
        let audio = tracks.filter { $0.type == .audio }
        let subtitles = tracks.filter { $0.type == .subtitle }

        func find(_ list: [PlayerTrack], _ language: String) -> PlayerTrack? {
            list.first { TrackLanguage.of($0) == language }
        }

        var selection = TrackSelection()

        if let remembered {
            if let language = remembered.audioLanguage, let track = find(audio, language) {
                selection.audioID = track.id
            }
            if remembered.subtitlesOff {
                selection.subtitle = .off
            } else if let language = remembered.subtitleLanguage, let track = find(subtitles, language) {
                selection.subtitle = .track(track.id)
            }
            return selection
        }

        var audioMatches = false
        if !preferredAudio.isEmpty, let track = find(audio, preferredAudio) {
            selection.audioID = track.id
            audioMatches = true
        }

        switch preferredSubtitle {
        case "":
            break
        case "off":
            selection.subtitle = .off
        default:
            if audioMatches {
                selection.subtitle = .off
            } else if let track = find(subtitles, preferredSubtitle) {
                selection.subtitle = .track(track.id)
            }
        }
        return selection
    }
}
