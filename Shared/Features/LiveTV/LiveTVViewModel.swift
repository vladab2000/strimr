import Foundation
import Observation

@MainActor
@Observable
final class LiveTVViewModel {
    var isResolvingStream = false
    var errorMessage: String?

    private let manager: ChannelManager

    init(manager: ChannelManager) {
        self.manager = manager
    }

    // MARK: - Delegated state

    var channels: [Media] { manager.channels }
    var isLoading: Bool { manager.isLoadingChannels }
    var hasContent: Bool { manager.hasChannels }
    var programsByChannel: [String: [Media]] { manager.programsByChannel }
    var sequentialEPGByChannel: [String: [Media?]] { manager.sequentialEPGByChannel }

    // MARK: - Categories

    var categories: [ChannelCategory] { manager.categories }
    var provider: ProviderType { manager.provider }

    var filteredChannels: [Media] { channels }

    func currentProgram(for channel: Media) -> Media? {
        manager.currentProgram(for: channel)
    }

    // MARK: - UI state (iOS / macOS)

    var mode: LiveTVMode = .channels
    var selectedDate: Date = .now
    var selectedProgram: Media? = nil
    var selectedChannel: Media? = nil {
        didSet {
            if let id = selectedChannel?.id { AppStateStore.lastChannelId = id }
        }
    }
    var selectedCategory: ChannelCategory? = nil

    var baseDate: Date {
        var cal = Calendar.current
        cal.timeZone = TimeZone(abbreviation: "UTC")!
        return cal.startOfDay(for: selectedDate)
    }

    var selectedChannelPrograms: [Media] {
        guard let channel = selectedChannel else { return [] }
        return programsByChannel[channel.id] ?? []
    }

    func selectChannel(_ channel: Media) {
        selectedChannel = channel
        loadProgramsIfNeeded(for: channel, on: selectedDate) { _ in }
    }

    func selectCategory(_ category: ChannelCategory?) {
        selectedCategory = category
    }

    func loadProgramsIfNeeded(for channel: Media) {
        loadProgramsIfNeeded(for: channel, on: selectedDate) { _ in }
    }

    // MARK: - EPG dates

    var availableDates: [Date] {
        var calendar = Calendar.current
        calendar.timeZone = TimeZone(abbreviation: "UTC")!
        let today = calendar.startOfDay(for: .now)
        return (-6...0).compactMap { calendar.date(byAdding: .day, value: $0, to: today) }
    }

    // MARK: - Lifecycle

    func load() async {
        async let categoriesLoad: () = manager.loadCategories()
        async let channelsLoad: () = manager.loadChannels()
        _ = await (categoriesLoad, channelsLoad)
        restoreSelectedChannel()
    }

    /// Po novém spuštění vybere kanál z minula (iOS / macOS; tvOS EPG si ho obnoví sám)
    private func restoreSelectedChannel() {
        guard selectedChannel == nil, let id = AppStateStore.lastChannelId,
              let channel = channels.first(where: { $0.id == id }) else { return }
        selectChannel(channel)
    }

    func reload() async {
        await manager.reloadChannels()
    }

    func reloadIfProviderChanged() {
        manager.reloadIfProviderChanged()
    }

    /// Den (UTC), ke kterému jsou načtené programy. Časová osa EPG začíná na "dnes − 7 dní" a programy
    /// jsou uložené vůči dnešku — po probuzení v jiný den by nesouhlasily, proto se načtou znovu.
    @ObservationIgnored private var programsDay = LiveTVViewModel.utcToday()

    /// Po probuzení zařízení: změnil-li se den, zahodí programy (načtou se znovu pro viditelnou oblast)
    @discardableResult
    func refreshIfDayChanged() -> Bool {
        let today = Self.utcToday()
        guard today != programsDay else { return false }
        programsDay = today

        selectedDate = .now
        selectedProgram = nil
        manager.resetAllPrograms()
        if let channel = selectedChannel {
            loadProgramsIfNeeded(for: channel)
        }
        return true
    }

    private static func utcToday() -> Date {
        var calendar = Calendar.current
        calendar.timeZone = TimeZone(abbreviation: "UTC")!
        return calendar.startOfDay(for: .now)
    }

    func dateChanged() {
        manager.resetAllPrograms()
    }

    // MARK: - Program loading
    
    func loadProgramsIfNeeded(for channel: Media, on date: Date, completion: @escaping (ProgramLoadStatus) -> Void) {
        manager.loadProgramsForDateIfNeeded(for: channel, on: date, completion: {state in
//            print("loadProgramsIfNeeded \(channel.name) \(date) \(state)")
            completion(state)
        })
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
}
