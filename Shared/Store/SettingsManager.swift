import Foundation
import Observation

@MainActor
@Observable
final class SettingsManager {
    @ObservationIgnored private let defaults: UserDefaults
    @ObservationIgnored private let storageKey = "strimr.settings"

    private(set) var settings: AppSettings

    init(userDefaults: UserDefaults = .standard) {
        defaults = userDefaults
        if let data = defaults.data(forKey: storageKey),
           let stored = try? JSONDecoder().decode(AppSettings.self, from: data)
        {
            settings = stored
        } else {
            settings = AppSettings()
        }
    }

    var playback: PlaybackSettings {
        settings.playback
    }

    var tvProvider: ProviderType {
        settings.tvProvider
    }

    var contentSource: ContentSource {
        settings.contentSource
    }

    var catalogFilter: CatalogFilter {
        settings.catalogFilter
    }

    func setTvProvider(_ provider: ProviderType) {
        settings.tvProvider = provider
        persist()
    }

    // MARK: - Oblíbené kanály

    var favoriteChannels: [FavoriteChannel] {
        settings.favoriteChannels
    }

    func favorite(channelId: String) -> FavoriteChannel? {
        settings.favoriteChannels.first { $0.channelId == channelId }
    }

    /// Přidá kanál do oblíbených od daného poskytovatele, je-li tam od jiného, změní poskytovatele;
    /// je-li tam od stejného, odebere ho
    func toggleFavorite(channel: Media, provider: ProviderType) {
        if let index = settings.favoriteChannels.firstIndex(where: { $0.channelId == channel.id }) {
            if settings.favoriteChannels[index].provider == provider {
                settings.favoriteChannels.remove(at: index)
            } else {
                settings.favoriteChannels[index].provider = provider
            }
        } else {
            settings.favoriteChannels.append(FavoriteChannel(channelId: channel.id, provider: provider, name: channel.name))
        }
        persist()
    }

    func removeFavorite(channelId: String) {
        settings.favoriteChannels.removeAll { $0.channelId == channelId }
        persist()
    }

    /// Posune oblíbený kanál o `offset` míst (záporné = nahoru)
    func moveFavorite(channelId: String, by offset: Int) {
        guard let index = settings.favoriteChannels.firstIndex(where: { $0.channelId == channelId }) else { return }
        let target = index + offset
        guard settings.favoriteChannels.indices.contains(target) else { return }
        settings.favoriteChannels.swapAt(index, target)
        persist()
    }

    func setContentSource(_ source: ContentSource) {
        settings.contentSource = source
        persist()
    }

    func setCatalogFilter(_ filter: CatalogFilter) {
        settings.catalogFilter = filter
        persist()
    }

    func setAutoPlayNextEpisode(_ enabled: Bool) {
        settings.playback.autoPlayNextEpisode = enabled
        persist()
    }

    func setAutoSkipIntro(_ enabled: Bool) {
        settings.playback.autoSkipIntro = enabled
        persist()
    }

    func setSeekBackwardSeconds(_ seconds: Int) {
        settings.playback.seekBackwardSeconds = seconds
        persist()
    }

    func setSeekForwardSeconds(_ seconds: Int) {
        settings.playback.seekForwardSeconds = seconds
        persist()
    }

    func setPlaybackPlayer(_ player: PlaybackPlayer) {
        settings.playback.player = player
        persist()
    }

    func setSubtitleScale(_ scale: Int) {
        settings.playback.subtitleScale = scale
        persist()
    }

    func setPreferredAudioLanguage(_ language: String) {
        settings.playback.preferredAudioLanguage = language
        persist()
    }

    func setPreferredSubtitleLanguage(_ language: String) {
        settings.playback.preferredSubtitleLanguage = language
        persist()
    }

    func seriesTrackChoice(for seriesId: String) -> TrackChoice? {
        settings.seriesTracks[seriesId]
    }

    func setSeriesTrackChoice(_ choice: TrackChoice, for seriesId: String) {
        guard settings.seriesTracks[seriesId] != choice else { return }
        settings.seriesTracks[seriesId] = choice
        persist()
    }

    func updatePlayback(_ transform: (inout PlaybackSettings) -> Void) {
        transform(&settings.playback)
        persist()
    }

    private func persist() {
        guard let data = try? JSONEncoder().encode(settings) else { return }
        defaults.set(data, forKey: storageKey)
    }
}
