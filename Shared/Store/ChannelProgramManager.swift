import Foundation
import Observation

/// Centralized manager for TV channels and their programs.
/// Shared across EPG and Channels views via `@Environment`.
@MainActor
@Observable
final class ChannelProgramManager {

    // MARK: - Public state

    /// Channels for the currently active provider.
    var channels: [Media] = []
    var isLoadingChannels = false
    var channelsError: String?

    /// Programs keyed by channel ID — may span multiple days.
    var programsByChannel: [String: [Media]] = [:]

    // MARK: - Dependencies

    @ObservationIgnored private let settingsManager: SettingsManager
    @ObservationIgnored private var loadTask: Task<Void, Never>?
    @ObservationIgnored private var lastProvider: ProviderType?

    /// Tracks which (channelID, dateFrom–dateTo) ranges have been requested.
    @ObservationIgnored private var loadedRanges: [String: Set<String>] = [:]
    /// Per-channel loading tasks to avoid duplicate concurrent fetches.
    @ObservationIgnored private var programTasks: [String: Task<Void, Never>] = [:]

    /// The earliest date loaded per channel.
    @ObservationIgnored private var earliestLoadedDate: [String: Date] = [:]
    /// The latest date loaded per channel.
    @ObservationIgnored private var latestLoadedDate: [String: Date] = [:]

    // MARK: - Init

    init(settingsManager: SettingsManager) {
        self.settingsManager = settingsManager
    }

    var provider: ProviderType { settingsManager.tvProvider }
    var hasChannels: Bool { !channels.isEmpty }

    // MARK: - Date helpers

    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.locale = Locale(identifier: "en_US_POSIX")
        //f.timeZone = TimeZone(identifier: "UTC")
        return f
    }()

    private func dateString(for date: Date) -> String {
        Self.dateFormatter.string(from: date)
    }

    // MARK: - Channels

    /// Load channels if not already loaded.
    func loadChannels() async {
        guard channels.isEmpty else { return }
        await reloadChannels()
    }

    /// Reload channels (e.g. after provider change).
    func reloadChannels() async {
        loadTask?.cancel()
        lastProvider = provider

        let task = Task { [weak self] in
            guard let self else { return }
            isLoadingChannels = true
            channelsError = nil
            defer { isLoadingChannels = false }

            do {
                let result = try await ApiClient.fetchChannels(providerType: provider)
                guard !Task.isCancelled else { return }
                channels = result
            } catch {
                guard !Task.isCancelled else { return }
                channels = []
                channelsError = error.localizedDescription
            }
        }
        loadTask = task
        await task.value
    }

    /// Call on view appear — reloads only if provider changed since last load.
    func reloadIfProviderChanged() {
        let current = settingsManager.tvProvider
        guard lastProvider != current else { return }
        lastProvider = current
        loadTask?.cancel()
        channels = []
        resetAllPrograms()
        Task { await reloadChannels() }
    }

    // MARK: - Programs

    /// Ensure programs are loaded for a channel on a specific day.
    /// Call from `onAppear` of channel rows in EPG.
    func loadProgramsIfNeeded(for channel: Media, on date: Date) {
        let channelId = channel.id
        let dayStart = Calendar.current.startOfDay(for: date)
        let fromStr = dateString(for: dayStart)

        // Already loaded or loading this range for this channel
        if loadedRanges[channelId]?.contains(fromStr) == true { return }

        // Mark as loading
        if loadedRanges[channelId] == nil {
            loadedRanges[channelId] = []
        }
        loadedRanges[channelId]?.insert(fromStr)

        programTasks[channelId]?.cancel()
        programTasks[channelId] = Task { [weak self] in
            guard let self else { return }
            do {
                let programs = try await ApiClient.fetchPrograms(
                    channelId: channelId,
                    date: fromStr
                )
                guard !Task.isCancelled else { return }
                mergePrograms(programs, for: channelId)
                updateDateBounds(channelId: channelId, dayStart: dayStart)
            } catch {
                guard !Task.isCancelled else { return }
                // Ensure at least an empty entry so the UI doesn't keep retrying
                if programsByChannel[channelId] == nil {
                    programsByChannel[channelId] = []
                }
            }
        }
    }

    /// Load programs for the next day after the latest loaded day.
    func loadNextDay(for channel: Media) {
        let channelId = channel.id
        guard let latest = latestLoadedDate[channelId] else { return }
        guard let nextDay = Calendar.current.date(byAdding: .day, value: 1, to: latest) else { return }
        loadProgramsIfNeeded(for: channel, on: nextDay)
    }

    /// Load programs for the day before the earliest loaded day.
    func loadPreviousDay(for channel: Media) {
        let channelId = channel.id
        guard let earliest = earliestLoadedDate[channelId] else { return }
        guard let prevDay = Calendar.current.date(byAdding: .day, value: -1, to: earliest) else { return }
        loadProgramsIfNeeded(for: channel, on: prevDay)
    }

    /// Returns the program currently airing for a given channel.
    func currentProgram(for channel: Media) -> Media? {
        let now = Date.now
        return programsByChannel[channel.id]?.first { program in
            guard let start = program.programStart, let end = program.programEnd else { return false }
            return start <= now && now < end
        }
    }

    /// The earliest loaded date for a channel, or nil if none loaded.
    func earliestDate(for channelId: String) -> Date? {
        earliestLoadedDate[channelId]
    }

    /// The latest loaded date for a channel, or nil if none loaded.
    func latestDate(for channelId: String) -> Date? {
        latestLoadedDate[channelId]
    }

    /// Clear all program data (e.g. when changing date or provider).
    func resetAllPrograms() {
        programsByChannel = [:]
        loadedRanges = [:]
        earliestLoadedDate = [:]
        latestLoadedDate = [:]
        programTasks.values.forEach { $0.cancel() }
        programTasks = [:]
    }

    // MARK: - Stream resolution

    /// Resolves a live stream URL for a channel.
    func resolveLiveStreamURL(for channel: Media) async -> URL? {
        do {
            let stream = try await ApiClient.fetchLiveStream(
                channelId: channel.id,
                providerType: provider
            )
            return streamURL(from: stream)
        } catch {
            debugPrint("Failed to resolve live stream:", error)
            return nil
        }
    }

    /// Resolves a stream URL for an archive program.
    func resolveArchiveStreamURL(channelId: String, program: Media) async -> URL? {
        do {
            let stream = try await ApiClient.fetchArchiveStream(
                channelId: channelId,
                programId: program.id
            )
            return streamURL(from: stream)
        } catch {
            debugPrint("Failed to resolve archive stream:", error)
            return nil
        }
    }

    // MARK: - Private

    private func streamURL(from stream: Stream) -> URL? {
        let urlString: String
        if stream.isEncoded == true {
            urlString = ApiClient.decodeStream(stream: stream)
        } else {
            guard let rawURL = stream.url else { return nil }
            urlString = rawURL
        }
        return URL(string: urlString)
    }

    /// Merge fetched programs into the existing list, deduplicating by ID and sorting by start time.
    private func mergePrograms(_ newPrograms: [Media], for channelId: String) {
        let existing = programsByChannel[channelId] ?? []
        let existingIDs = Set(existing.map(\.id))
        let unique = newPrograms.filter { !existingIDs.contains($0.id) }
        let merged = (existing + unique).sorted {
            ($0.programStart ?? .distantPast) < ($1.programStart ?? .distantPast)
        }
        programsByChannel[channelId] = merged
    }

    /// Update the earliest/latest loaded date for a channel.
    private func updateDateBounds(channelId: String, dayStart: Date) {
        if let current = earliestLoadedDate[channelId] {
            if dayStart < current { earliestLoadedDate[channelId] = dayStart }
        } else {
            earliestLoadedDate[channelId] = dayStart
        }

        if let current = latestLoadedDate[channelId] {
            if dayStart > current { latestLoadedDate[channelId] = dayStart }
        } else {
            latestLoadedDate[channelId] = dayStart
        }
    }
}
