import Foundation

struct PlaybackSettings: Codable, Equatable {
    var autoPlayNextEpisode = true
    var autoSkipIntro = false
    var seekBackwardSeconds = 10
    var seekForwardSeconds = 10
    var player = PlaybackPlayer.mpv
    var subtitleScale = 100
    /// Preferovaný jazyk zvuku a titulků (TrackLanguage: "" = neměnit, "off" = titulky vypnout)
    var preferredAudioLanguage = "cs"
    var preferredSubtitleLanguage = "cs"

    init() {}

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        autoPlayNextEpisode = try container.decodeIfPresent(Bool.self, forKey: .autoPlayNextEpisode) ?? true
        autoSkipIntro = try container.decodeIfPresent(Bool.self, forKey: .autoSkipIntro) ?? false
        seekBackwardSeconds = try container.decodeIfPresent(Int.self, forKey: .seekBackwardSeconds) ?? 10
        seekForwardSeconds = try container.decodeIfPresent(Int.self, forKey: .seekForwardSeconds) ?? 10
        player = try container.decodeIfPresent(PlaybackPlayer.self, forKey: .player) ?? .mpv
        subtitleScale = try container.decodeIfPresent(Int.self, forKey: .subtitleScale) ?? 100
        preferredAudioLanguage = try container.decodeIfPresent(String.self, forKey: .preferredAudioLanguage) ?? "cs"
        preferredSubtitleLanguage = try container.decodeIfPresent(String.self, forKey: .preferredSubtitleLanguage) ?? "cs"
    }
}

struct AppSettings: Codable, Equatable {
    var playback = PlaybackSettings()
    var tvProvider: ProviderType = ProviderType.selectableCases.first ?? .sweetTV
    /// Oblíbené kanály v pořadí zobrazení (poskytovatel „Oblíbené“)
    var favoriteChannels: [FavoriteChannel] = []
    var contentSource: ContentSource = .streamCinema
    var catalogFilter = CatalogFilter()
    /// Zvuk a titulky naposledy zvolené u seriálu (klíč = id seriálu)
    var seriesTracks: [String: TrackChoice] = [:]

    init() {}

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        playback = try container.decodeIfPresent(PlaybackSettings.self, forKey: .playback) ?? PlaybackSettings()
        tvProvider = try container.decodeIfPresent(ProviderType.self, forKey: .tvProvider)
            .flatMap { ProviderType.selectableCases.contains($0) ? $0 : nil } ?? ProviderType.selectableCases.first ?? .sweetTV
        favoriteChannels = try container.decodeIfPresent([FavoriteChannel].self, forKey: .favoriteChannels) ?? []
        contentSource = try container.decodeIfPresent(ContentSource.self, forKey: .contentSource) ?? .streamCinema
        catalogFilter = try container.decodeIfPresent(CatalogFilter.self, forKey: .catalogFilter) ?? CatalogFilter()
        seriesTracks = try container.decodeIfPresent([String: TrackChoice].self, forKey: .seriesTracks) ?? [:]
    }
}
