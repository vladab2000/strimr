import Foundation
import Observation

@MainActor
@Observable
final class EPGViewModel {
    var channels: [Media] = []
    var selectedDate: Date = .now
    var selectedProgram: Media?
    var isLoading = false
    var isResolvingStream = false
    var errorMessage: String?

    /// Programs keyed by channel ID
    var programsByChannel: [String: [Media]] = [:]

    @ObservationIgnored private var loadTask: Task<Void, Never>?
    @ObservationIgnored private var loadingChannelIDs: Set<String> = []
    @ObservationIgnored private var lastProvider: ProviderType?
    private let settingsManager: SettingsManager

    var provider: ProviderType { settingsManager.tvProvider }
    var hasChannels: Bool { !channels.isEmpty }

    init(settingsManager: SettingsManager) {
        self.settingsManager = settingsManager
    }

    /// Dates available for EPG selection (today ± 3 days back)
    var availableDates: [Date] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: .now)
        return (-3...0).compactMap { calendar.date(byAdding: .day, value: $0, to: today) }
    }

    var selectedDateString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: selectedDate)
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
        programsByChannel = [:]
        loadingChannelIDs = []
        selectedProgram = nil
        Task { await reload() }
    }

    func dateChanged() {
        programsByChannel = [:]
        loadingChannelIDs = []
        selectedProgram = nil
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

    /// Call from each channel row's onAppear to lazily load programs.
    func loadProgramsIfNeeded(for channel: Media) {
        let channelId = channel.id
        guard programsByChannel[channelId] == nil,
              !loadingChannelIDs.contains(channelId) else { return }

        loadingChannelIDs.insert(channelId)
        let dateStr = selectedDateString

        Task { [weak self] in
            guard let self else { return }
            do {
                let programs = try await ApiClient.fetchPrograms(
                    channelId: channelId,
                    date: dateStr
                )
                guard !Task.isCancelled else { return }
                programsByChannel[channelId] = programs
            } catch {
                guard !Task.isCancelled else { return }
                // Store empty array so we don't retry endlessly
                programsByChannel[channelId] = []
            }
            loadingChannelIDs.remove(channelId)
        }
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

    /// Returns the program currently airing for a given channel.
    func currentProgram(for channel: Media) -> Media? {
        let now = Date.now
        return programsByChannel[channel.id]?.first { program in
            guard let start = program.programStart, let end = program.programEnd else { return false }
            return start <= now && now < end
        }
    }

    /// Resolves a stream URL for an archive program.
    func resolveArchiveStreamURL(channelId: String, program: Media) async -> URL? {
        isResolvingStream = true
        defer { isResolvingStream = false }

        do {
            let stream = try await ApiClient.fetchArchiveStream(
                channelId: channelId,
                programId: program.id
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
            debugPrint("Failed to resolve archive stream:", error)
            errorMessage = error.localizedDescription
            return nil
        }
    }

    /// Resolves a live stream URL for a channel.
    func resolveLiveStreamURL(for channel: Media) async -> URL? {
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
