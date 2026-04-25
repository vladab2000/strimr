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
    var selectedCategory: ChannelCategory?
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

    var categories: [ChannelCategory] { manager.categories }

    var filteredChannels: [Media] { channels }

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
        async let categoriesLoad: () = manager.loadCategories()
        async let channelsLoad: () = manager.loadChannels(categoryId: selectedCategory?.id)
        _ = await (categoriesLoad, channelsLoad)
    }

    func reload() async {
        await manager.reloadChannels(categoryId: selectedCategory?.id)
    }

    func selectCategory(_ category: ChannelCategory?) {
        guard selectedCategory?.id != category?.id else { return }
        selectedCategory = category
        selectedChannel = nil
        selectedProgram = nil
        manager.resetAllPrograms()
        Task {
            await manager.reloadChannels(categoryId: category?.id)
            selectFirstChannelIfNeeded()
        }
    }

    func reloadIfProviderChanged() {
        manager.reloadIfProviderChanged(categoryId: selectedCategory?.id)
    }

    /// Refreshes programs if the calendar day has changed (e.g. after device sleep).
    func refreshIfDayChanged() {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: .now)
        let selectedDay = calendar.startOfDay(for: selectedDate)

        guard today != selectedDay else { return }

        selectedDate = .now
        selectedProgram = nil
        manager.resetAllPrograms()

        // Reload programs for all visible channels
        if let channel = selectedChannel {
            loadProgramsIfNeeded(for: channel)
            selectedProgram = nil
        }
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

    func resolveLivePlayback(for channel: Media) async -> Playback? {
        isResolvingStream = true
        defer { isResolvingStream = false }

        guard let result = await manager.resolveLivePlayback(for: channel) else {
            errorMessage = String(localized: "channels.error.stream")
            return nil
        }
        return result
    }

    func resolveArchivePlayback(program: Media) async -> Playback? {
        isResolvingStream = true
        defer { isResolvingStream = false }

        guard let result = await manager.resolveArchivePlayback(channelId: program.channelId!, program: program) else {
            errorMessage = String(localized: "epg.error.stream")
            return nil
        }
        return result
    }
    
    func findTargetID(midTime: Date, inChannel channelID: String) -> String? {
        guard let channel = channels.first(where: { $0.id == channelID }) else { return nil }
        return programsByChannel[channel.id]?.first { midTime >= $0.programStart! && midTime <= $0.programEnd! }?.id
    }
    
    func loadMoreData() {
        manager.loadNextDay()
    }
}
