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
        case streamSelection(Media)
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
            showStreamSelection(media)
            return
        }
        appendRoute(.mediaDetail(media))
    }

    func showStreamSelection(_ media: Media) {
        appendRoute(.streamSelection(media))
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
