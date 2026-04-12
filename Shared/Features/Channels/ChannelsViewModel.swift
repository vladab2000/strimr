import Foundation
import Observation

@MainActor
@Observable
final class ChannelsViewModel {
    var isResolvingStream = false
    var errorMessage: String?

    private let manager: ChannelProgramManager

    init(manager: ChannelProgramManager) {
        self.manager = manager
    }

    // MARK: - Delegated state

    var channels: [Media] { manager.channels }
    var isLoading: Bool { manager.isLoadingChannels }
    var hasContent: Bool { manager.hasChannels }

    // MARK: - Lifecycle

    func load() async {
        await manager.loadChannels()
    }

    func reload() async {
        await manager.reloadChannels()
    }

    func reloadIfProviderChanged() {
        manager.reloadIfProviderChanged()
    }

    // MARK: - Stream resolution

    func resolveStreamURL(for channel: Media) async -> URL? {
        isResolvingStream = true
        defer { isResolvingStream = false }

        guard let url = await manager.resolveLiveStreamURL(for: channel) else {
            errorMessage = String(localized: "channels.error.stream")
            return nil
        }
        return url
    }
}
