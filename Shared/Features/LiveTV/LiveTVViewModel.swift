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

    var filteredChannels: [Media] { channels }

    func currentProgram(for channel: Media) -> Media? {
        manager.currentProgram(for: channel)
    }

    // MARK: - EPG dates

    var availableDates: [Date] {
        var calendar = Calendar.current
        calendar.timeZone = TimeZone(abbreviation: "UTC")!
        let today = calendar.startOfDay(for: .now)
        return (-3...0).compactMap { calendar.date(byAdding: .day, value: $0, to: today) }
    }

    // MARK: - Lifecycle

    func load() async {
        async let categoriesLoad: () = manager.loadCategories()
        async let channelsLoad: () = manager.loadChannels()
        _ = await (categoriesLoad, channelsLoad)
    }

    func reload() async {
        await manager.reloadChannels()
    }

    func reloadIfProviderChanged() {
        manager.reloadIfProviderChanged()
    }

    /// Refreshes programs if the calendar day has changed (e.g. after device sleep).
    func refreshIfDayChanged() {
        //TODO: Doplnění chybějích dnů do programu, aby bylo vždy načteno 14 dní epg
/*        var calendar = Calendar.current
        calendar.timeZone = TimeZone(abbreviation: "UTC")!
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
        }*/
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
