import Foundation
import Observation

/// Centralized manager for TV channels.
@MainActor
@Observable
final class ChannelManager {

    // MARK: - Public state

    /// Available channel categories from the server.
    var categories: [ChannelCategory] = []

    /// Channels for the currently active provider.
    var channels: [Media] = []
    var isLoadingChannels = false
    var channelsError: String?

    /// Merged programs across all loaded days, deduplicated by programStart.
    var programsByChannel: [String: [Media]] = [:]

    /// Sequential EPG per channel. Index `todayIndexOffset` = start of today.
    var sequentialEPGByChannel: [String: [Media?]] = [:]
    
    // MARK: - Dependencies

    @ObservationIgnored private let settingsManager: SettingsManager
    @ObservationIgnored private var loadChannelTask: Task<Void, Never>?
    @ObservationIgnored private var lastProvider: ProviderType?

    // MARK: - Init

    init(settingsManager: SettingsManager) {
        self.settingsManager = settingsManager
    }

    var provider: ProviderType { settingsManager.tvProvider }
    var hasChannels: Bool { !channels.isEmpty }

    // MARK: - Categories

    /// Load categories from the server.
    func loadCategories() async {
        do {
            let result = try await ApiClient.fetchCategories()
            categories = result
        } catch {
            debugPrint("Failed to load categories:", error)
            categories = []
        }
    }

    // MARK: - Channels

    /// Load channels if not already loaded.
    func loadChannels(categoryId: Int? = nil) async {
        guard channels.isEmpty else { return }
        await reloadChannels(categoryId: categoryId)
    }

    /// Reload channels (e.g. after provider or category change).
    func reloadChannels(categoryId: Int? = nil) async {
        loadChannelTask?.cancel()
        lastProvider = provider

        let task = Task { [weak self] in
            guard let self else { return }
            isLoadingChannels = true
            channelsError = nil
            defer { isLoadingChannels = false }

            do {
                let result = try await ApiClient.fetchChannels(providerType: provider, categoryId: categoryId)
                guard !Task.isCancelled else { return }
                channels = result
            } catch {
                guard !Task.isCancelled else { return }
                channels = []
                channelsError = error.localizedDescription
            }
        }
        loadChannelTask = task
        await task.value
    }

    /// Call on view appear — reloads only if provider changed since last load.
    func reloadIfProviderChanged(categoryId: Int? = nil) {
        let current = settingsManager.tvProvider
        guard lastProvider != current else { return }
        lastProvider = current
        loadChannelTask?.cancel()
        channels = []
        Task { await reloadChannels(categoryId: categoryId) }
    }

    // MARK: - Programs
    
    /// Cache: [ChannelID: [Datum: [Programy]]]
    private var epgCache: [String: [Date: [Media]]] = [:]

    /// Per-channel loading tasks to avoid duplicate concurrent fetches.
    @ObservationIgnored private var programTasks: [String: Task<Void, Never>] = [:]
    
    /// Ensure programs are loaded for a channel on a specific day.
    /// Call from `onAppear` of channel rows in EPG.
    func loadProgramsForDateIfNeeded(for channel: Media, on date: Date, completion: (() -> Void)? = nil) {
        let channelId = channel.id

        var calendar = Calendar.current
        calendar.timeZone = TimeZone(abbreviation: "UTC")!
        let dayStart = calendar.startOfDay(for: date)

        if epgCache[channel.id] == nil { epgCache[channel.id] = [:] }

        if epgCache[channelId]?[dayStart] != nil || programTasks[channelId] != nil {
            return
        }
        epgCache[channel.id]?[dayStart] = []

        let task = Task { [weak self] in
            guard let self else { return }
            defer { self.programTasks[channelId] = nil }

            do {
                let programs = try await ApiClient.fetchProgramsForDate(
                    channelId: channelId,
                    date: dayStart
                )
                guard !Task.isCancelled else { return }

                epgCache[channel.id]?[dayStart] = programs
                mergeProgramsSafely(programs, for: channelId)
                rebuildSequentialEPG(for: channelId)
                completion?()

            } catch {
                guard !Task.isCancelled else { return }
            }
        }

        programTasks[channelId] = task
    }

    /// Merges new programs into programsByChannel, deduplicating by programStart.
    /// Handles programs that span day boundaries (appear at end of day N and start of day N+1).
    private func mergeProgramsSafely(_ newPrograms: [Media], for channelId: String) {
        var currentPrograms = programsByChannel[channelId] ?? []
        var seenStarts = Set(currentPrograms.compactMap(\.programStart))

        for program in newPrograms {
            guard let start = program.programStart else { continue }
            if seenStarts.insert(start).inserted {
                currentPrograms.append(program)
            }
        }

        programsByChannel[channelId] = currentPrograms.sorted {
            ($0.programStart ?? .distantPast) < ($1.programStart ?? .distantPast)
        }
    }

    
    /// Konstanta pro offset dnešního dne v poli pro UICollectionView.
    /// Index `todayIndexOffset` v `sequentialEPGByChannel` odpovídá začátku dnešního dne.
    let todayIndexOffset = 250

    /// Přepočítá sekvenční EPG pro daný kanál z `epgCache` a uloží do `sequentialEPGByChannel`.
    /// Volá se automaticky po každém načtení nového dne.
    private func rebuildSequentialEPG(for channelId: String) {
        var calendar = Calendar.current
        calendar.timeZone = TimeZone(abbreviation: "UTC")!
        let today = calendar.startOfDay(for: Date())
        let dayRange = -10...10
        let totalCapacity = 1000

        var sequence = [Media?](repeating: nil, count: totalCapacity)

        guard let channelCache = epgCache[channelId] else {
            sequentialEPGByChannel[channelId] = sequence
            return
        }

        var seenProgramStarts = Set<Date>()

        // Dnešek a budoucí dny (od indexu todayIndexOffset dopředu)
        var currentWriteIndex = todayIndexOffset
        for dayOffset in 0...dayRange.upperBound {
            if let date = calendar.date(byAdding: .day, value: dayOffset, to: today),
               let programs = channelCache[date] {
                for program in programs {
                    guard let startTime = program.programStart else { continue }
                    if seenProgramStarts.insert(startTime).inserted, currentWriteIndex < sequence.count {
                        sequence[currentWriteIndex] = program
                        currentWriteIndex += 1
                    }
                }
            }
        }

        // Historie (zpětně od indexu todayIndexOffset - 1)
        var historyWriteIndex = todayIndexOffset - 1
        for dayOffset in stride(from: -1, through: dayRange.lowerBound, by: -1) {
            if let date = calendar.date(byAdding: .day, value: dayOffset, to: today),
               let programs = channelCache[date] {
                for program in programs.reversed() {
                    guard let startTime = program.programStart else { continue }
                    if seenProgramStarts.insert(startTime).inserted, historyWriteIndex >= 0 {
                        sequence[historyWriteIndex] = program
                        historyWriteIndex -= 1
                    }
                }
            }
        }

        sequentialEPGByChannel[channelId] = sequence
    }
    
    /// Vrátí aktuálně vysílaný pořad pro daný kanál.
    func currentProgram(for channel: Media) -> Media? {
        let now = Date()
        let calendar = Calendar.current
        
        // Získáme start dne v UTC (aby to sedělo na tvůj klíč v epgCache)
        var utcCalendar = calendar
        utcCalendar.timeZone = TimeZone(abbreviation: "UTC")!
        let todayStart = utcCalendar.startOfDay(for: now)
        
        // 1. Zkusíme najít program v dnešním listu
        if let todaysPrograms = epgCache[channel.id]?[todayStart] {
            if let current = findActive(in: todaysPrograms, at: now) {
                return current
            }
        }
        
        // 2. Pokud jsme nenašli, zkusíme včerejšek (pro pořady začínající před půlnocí)
        let yesterdayStart = utcCalendar.date(byAdding: .day, value: -1, to: todayStart)!
        if let yesterdaysPrograms = epgCache[channel.id]?[yesterdayStart] {
            return findActive(in: yesterdaysPrograms, at: now)
        }
        
        return nil
    }
    
    /// Pomocná funkce pro vyhledání v poli
    private func findActive(in programs: [Media], at time: Date) -> Media? {
        return programs.first { program in
            guard let start = program.programStart,
                  let end = program.programEnd else { return false }
            return time >= start && time < end
        }
    }
    
    /// Clear all program data (e.g. when changing date or provider).
    func resetAllPrograms() {
        epgCache = [:]
        programsByChannel = [:]
        sequentialEPGByChannel = [:]
        programTasks.values.forEach { $0.cancel() }
        programTasks = [:]
    }
    
    // MARK: - Stream resolution

    /// Resolves a live stream URL for a channel.
    func resolveLivePlayback(for channel: Media) async -> Playback? {
        do {
            return try await ApiClient.fetchLiveStream(
                channelId: channel.id,
                providerType: provider
            )
        } catch {
            debugPrint("Failed to resolve live stream:", error)
            return nil
        }
    }
    
    /// Resolves a stream URL for an archive program.
    func resolveArchivePlayback(channelId: String, program: Media) async -> Playback? {
        do {
            return try await ApiClient.fetchArchiveStream(
                channelId: channelId,
                programId: program.id
            )
        } catch {
            debugPrint("Failed to resolve archive stream:", error)
            return nil
        }
    }
}

struct TimeRange: Hashable {
    let start: Date
    let end: Date
    
    func contains(_ date: Date) -> Bool {
        return date >= start && date < end
    }
}
