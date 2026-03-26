import Combine
import SwiftUI

@MainActor
final class MainCoordinator: ObservableObject {
    enum Tab: Hashable {
        case home
        case search
        case more
    }

    enum Route: Hashable {
        case mediaDetail(Media)
        case streamSelection(media: Media, streams: [Stream])
    }

    @Published var tab: Tab = .home
    @Published var homePath = NavigationPath()
    @Published var searchPath = NavigationPath()
    @Published var morePath = NavigationPath()

    @Published var selectedStreamURL: URL?
    @Published var selectedStreamTitle: String = ""
    @Published var selectedMediaUrl: String?
    @Published var selectedSeasonNumber: Int?
    @Published var selectedEpisodeNumber: Int?
    @Published var selectedResumePosition: Double?
    @Published var isPresentingPlayer = false

    @Published var isLoadingStreams = false

    var playbackLauncher: PlaybackLauncher?

    func pathBinding(for tab: Tab) -> Binding<NavigationPath> {
        Binding(
            get: {
                switch tab {
                case .home:
                    self.homePath
                case .search:
                    self.searchPath
                case .more:
                    self.morePath
                }
            },
            set: { newValue in
                switch tab {
                case .home:
                    self.homePath = newValue
                case .search:
                    self.searchPath = newValue
                case .more:
                    self.morePath = newValue
                }
            },
        )
    }

    func showMediaDetail(_ media: Media) {
        if media.itemType == .movie || media.itemType == .episode {
            Task { await loadStreamsAndNavigate(media) }
            return
        }
        appendRoute(.mediaDetail(media))
    }

    private func loadStreamsAndNavigate(_ media: Media) async {
        isLoadingStreams = true
        defer { isLoadingStreams = false }

        let streams = await fetchStreams(for: media)

        // Resume from saved position on first stream
        if media.watchCompleted != true,
           let position = media.watchPosition, position > 0,
           let stream = streams.first {
            await playbackLauncher?.play(
                stream: stream,
                media: media,
                resumePosition: Double(position)
            )
            return
        }

        // Single stream → play directly
        if streams.count == 1, let stream = streams.first {
            await playbackLauncher?.play(stream: stream, media: media)
            return
        }

        // Multiple streams → show selection screen with pre-loaded streams
        appendRoute(.streamSelection(media: media, streams: streams))
    }

    private func fetchStreams(for media: Media) async -> [Stream] {
        // Try inline streams first
        if let inlineStreams = media.streams, !inlineStreams.isEmpty {
            return StreamSorter.sorted(inlineStreams)
        }

        guard let urlPath = media.url else { return [] }
        do {
            let items = try await ApiClient.fetchMenu(urlPath: urlPath)
            let allStreams = items.flatMap { $0.streams ?? [] }
            return StreamSorter.sorted(allStreams)
        } catch {
            debugPrint("Failed to fetch streams:", error)
            return []
        }
    }

    private func appendRoute(_ route: Route) {
        switch tab {
        case .home:
            homePath.append(route)
        case .search:
            searchPath.append(route)
        case .more:
            break
        }
    }

    func showPlayer(
        streamURL: URL,
        title: String,
        mediaUrl: String? = nil,
        seasonNumber: Int? = nil,
        episodeNumber: Int? = nil,
        resumePosition: Double? = nil
    ) {
        selectedStreamURL = streamURL
        selectedStreamTitle = title
        selectedMediaUrl = mediaUrl
        selectedSeasonNumber = seasonNumber
        selectedEpisodeNumber = episodeNumber
        selectedResumePosition = resumePosition
        isPresentingPlayer = true
    }

    func resetPlayer() {
        selectedStreamURL = nil
        selectedStreamTitle = ""
        selectedMediaUrl = nil
        selectedSeasonNumber = nil
        selectedEpisodeNumber = nil
        selectedResumePosition = nil
        isPresentingPlayer = false
    }
}
