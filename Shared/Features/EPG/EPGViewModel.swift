import Foundation
import Observation

@MainActor
@Observable
final class EPGViewModel {
    var selectedDate: Date = .now
    var selectedProgram: Media?
    var isResolvingStream = false
    var errorMessage: String?

    private let manager: ChannelProgramManager

    init(manager: ChannelProgramManager) {
        self.manager = manager
    }

    // MARK: - Delegated state

    var channels: [Media] { manager.channels }
    var isLoading: Bool { manager.isLoadingChannels }
    var hasChannels: Bool { manager.hasChannels }
    var programsByChannel: [String: [Media]] { manager.programsByChannel }

    /// Dates available for EPG selection (today ± 3 days back)
    var availableDates: [Date] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: .now)
        return (-3...0).compactMap { calendar.date(byAdding: .day, value: $0, to: today) }
    }

    /// The "base" date for positioning — start of the selected day.
    var baseDate: Date {
        Calendar.current.startOfDay(for: selectedDate)
    }

    // MARK: - Lifecycle

    func load() async {
        await manager.loadChannels()
    }

    func reloadIfProviderChanged() {
        manager.reloadIfProviderChanged()
    }

    func dateChanged() {
        manager.resetAllPrograms()
        selectedProgram = nil
    }

    // MARK: - Program loading (delegates to manager)

    func loadProgramsIfNeeded(for channel: Media) {
        manager.loadProgramsIfNeeded(for: channel, on: selectedDate)
    }

    func loadNextDay(for channel: Media) {
        manager.loadNextDay(for: channel)
    }

    func loadPreviousDay(for channel: Media) {
        manager.loadPreviousDay(for: channel)
    }

    func currentProgram(for channel: Media) -> Media? {
        manager.currentProgram(for: channel)
    }

    // MARK: - Stream resolution

    func resolveArchiveStreamURL(channelId: String, program: Media) async -> URL? {
        isResolvingStream = true
        defer { isResolvingStream = false }

        guard let url = await manager.resolveArchiveStreamURL(channelId: channelId, program: program) else {
            errorMessage = String(localized: "epg.error.stream")
            return nil
        }
        return url
    }

    func resolveLiveStreamURL(for channel: Media) async -> URL? {
        isResolvingStream = true
        defer { isResolvingStream = false }

        guard let url = await manager.resolveLiveStreamURL(for: channel) else {
            errorMessage = String(localized: "epg.error.stream")
            return nil
        }
        return url
    }
}
