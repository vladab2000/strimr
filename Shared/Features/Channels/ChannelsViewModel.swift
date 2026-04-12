import Foundation
import Observation

@MainActor
@Observable
final class ChannelsViewModel {
    var channels: [Media] = []
    var isLoading = false
    var isResolvingStream = false
    var errorMessage: String?

    @ObservationIgnored private var loadTask: Task<Void, Never>?
    @ObservationIgnored private var lastProvider: ProviderType?
    private let settingsManager: SettingsManager

    var provider: ProviderType { settingsManager.tvProvider }
    var hasContent: Bool { !channels.isEmpty }

    init(settingsManager: SettingsManager) {
        self.settingsManager = settingsManager
    }

    func load() async {
        guard channels.isEmpty else { return }
        await reload()
    }

    /// Call when provider may have changed (e.g. on appear).
    func reloadIfProviderChanged() {
        let current = settingsManager.tvProvider
        guard lastProvider != current else { return }
        lastProvider = current
        loadTask?.cancel()
        channels = []
        Task { await reload() }
    }

    func reload() async {
        loadTask?.cancel()
        lastProvider = settingsManager.tvProvider
        let task = Task { [weak self] in
            guard let self else { return }
            await fetchChannels()
        }
        loadTask = task
        await task.value
    }

    private func fetchChannels() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            let result = try await ApiClient.fetchChannels(providerType: provider)
            guard !Task.isCancelled else { return }
            channels = result
        } catch {
            guard !Task.isCancelled else { return }
            channels = []
            errorMessage = error.localizedDescription
        }
    }

    /// Resolves a channel's live stream URL, handling the decode step if needed.
    func resolveStreamURL(for channel: Media) async -> URL? {
        isResolvingStream = true
        defer { isResolvingStream = false }

        do {
            let stream = try await ApiClient.fetchLiveStream(
                channelId: channel.id,
                providerType: provider
            )

            let urlString: String
            if stream.isEncoded == true {
                urlString = ApiClient.decodeStream(stream: stream)
            } else {
                guard let rawURL = stream.url else { return nil }
                urlString = rawURL
            }

            return URL(string: urlString)
        } catch {
            debugPrint("Failed to resolve live stream:", error)
            errorMessage = error.localizedDescription
            return nil
        }
    }
}
