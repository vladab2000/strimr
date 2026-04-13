import Foundation
import Observation

enum LiveTVMode: String, CaseIterable, Identifiable {
    case channels
    case tvGuide

    var id: String { rawValue }

    var titleKey: String {
        switch self {
        case .channels: "livetv.mode.channels"
        case .tvGuide: "livetv.mode.tvGuide"
        }
    }
}

@MainActor
@Observable
final class LiveTVViewModel {
    var mode: LiveTVMode = .channels
    var selectedCategory: String?
    var selectedChannel: Media?
    var isResolvingStream = false
    var errorMessage: String?

    // EPG state
    var selectedDate: Date = .now
    var selectedProgram: Media?

    private let manager: ChannelProgramManager

    init(manager: ChannelProgramManager) {
        self.manager = manager
    }

    // MARK: - Delegated state

    var channels: [Media] { manager.channels }
    var isLoading: Bool { manager.isLoadingChannels }
    var hasContent: Bool { manager.hasChannels }
    var programsByChannel: [String: [Media]] { manager.programsByChannel }

    // MARK: - Categories

    var categories: [String] {
        var seen = Set<String>()
        var result: [String] = []
        for channel in channels {
            for genre in channel.genres ?? [] {
                if seen.insert(genre).inserted {
                    result.append(genre)
                }
            }
        }
        return result.sorted()
    }

    var filteredChannels: [Media] {
        guard let category = selectedCategory else { return channels }
        return channels.filter { ($0.genres ?? []).contains(category) }
    }

    // MARK: - Selected channel programs

    var selectedChannelPrograms: [Media] {
        guard let channel = selectedChannel else { return [] }
        return programsByChannel[channel.id] ?? []
    }

    func currentProgram(for channel: Media) -> Media? {
        manager.currentProgram(for: channel)
    }

    // MARK: - EPG dates

    var availableDates: [Date] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: .now)
        return (-3...0).compactMap { calendar.date(byAdding: .day, value: $0, to: today) }
    }

    var baseDate: Date {
        Calendar.current.startOfDay(for: selectedDate)
    }

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

    func dateChanged() {
        manager.resetAllPrograms()
        selectedProgram = nil
    }

    // MARK: - Program loading

    func loadProgramsIfNeeded(for channel: Media) {
        manager.loadProgramsIfNeeded(for: channel, on: selectedDate)
    }

    func loadNextDay(for channel: Media) {
        manager.loadNextDay(for: channel)
    }

    func loadPreviousDay(for channel: Media) {
        manager.loadPreviousDay(for: channel)
    }

    func selectChannel(_ channel: Media) {
        selectedChannel = channel
        loadProgramsIfNeeded(for: channel)
        selectedProgram = currentProgram(for: channel)
    }

    /// Auto-selects the first channel if none is selected yet.
    func selectFirstChannelIfNeeded() {
        guard selectedChannel == nil, let first = filteredChannels.first else { return }
        selectChannel(first)
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

    func resolveLiveStreamURL(for channel: Media) async -> URL? {
        isResolvingStream = true
        defer { isResolvingStream = false }

        guard let url = await manager.resolveLiveStreamURL(for: channel) else {
            errorMessage = String(localized: "epg.error.stream")
            return nil
        }
        return url
    }

    func resolveArchiveStreamURL(channelId: String, program: Media) async -> URL? {
        isResolvingStream = true
        defer { isResolvingStream = false }

        guard let url = await manager.resolveArchiveStreamURL(channelId: channelId, program: program) else {
            errorMessage = String(localized: "epg.error.stream")
            return nil
        }
        return url
    }
}
