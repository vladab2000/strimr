import Combine
import SwiftUI

@MainActor
final class MainCoordinator: ObservableObject {
    enum Tab: Hashable {
        case home
        case library
        case search
        case more
    }

    enum Route: Hashable {
        case mediaDetail(Media)
        case streamSelection(media: Media, streams: [Stream])
    }

    @Published var tab: Tab = .home
    @Published var homePath = NavigationPath()
    @Published var libraryPath = NavigationPath()
    @Published var searchPath = NavigationPath()
    @Published var morePath = NavigationPath()

    @Published var selectedStreamURL: URL?
    @Published var selectedMedia: Media?
    @Published var selectedResumePosition: Double?
    @Published var selectedSkipIntroStart: Double?
    @Published var selectedSkipIntroEnd: Double?
    @Published var selectedSkipTitlesStart: Double?
    @Published var isPresentingPlayer = false

    @Published var isLoadingStreams = false

    var playbackLauncher: PlaybackLauncher?

    func pathBinding(for tab: Tab) -> Binding<NavigationPath> {
        Binding(
            get: {
                switch tab {
                case .home:
                    self.homePath
                case .library:
                    self.libraryPath
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
                case .library:
                    self.libraryPath = newValue
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
        case .library:
            libraryPath.append(route)
        case .search:
            searchPath.append(route)
        case .more:
            break
        }
    }

    func showPlayer(
        streamURL: URL,
        media: Media? = nil,
        resumePosition: Double? = nil,
        skipIntroStart: Double? = nil,
        skipIntroEnd: Double? = nil,
        skipTitlesStart: Double? = nil
    ) {
        selectedStreamURL = streamURL
        selectedMedia = media
        selectedResumePosition = resumePosition
        selectedSkipIntroStart = skipIntroStart
        selectedSkipIntroEnd = skipIntroEnd
        selectedSkipTitlesStart = skipTitlesStart
        isPresentingPlayer = true
    }

    func resetPlayer() {
        selectedStreamURL = nil
        selectedMedia = nil
        selectedResumePosition = nil
        selectedSkipIntroStart = nil
        selectedSkipIntroEnd = nil
        selectedSkipTitlesStart = nil
        isPresentingPlayer = false
    }
}
