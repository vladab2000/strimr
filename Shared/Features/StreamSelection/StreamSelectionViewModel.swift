import Foundation
import Observation

@MainActor
@Observable
final class StreamSelectionViewModel {
    enum AutoPlayResult: Equatable {
        case none
        case autoPlay(stream: Stream, resumePosition: Double?)
    }

    let media: Media
    var streams: [Stream] = []
    var isLoading = false
    var isResolvingStream = false
    var errorMessage: String?
    var autoPlayResult: AutoPlayResult = .none

    init(media: Media) {
        self.media = media
    }

    var heroImageURL: URL? {
        media.bannerURL ?? media.funartURL ?? media.posterURL
    }

    var yearText: String? {
        media.year.map(String.init)
    }

    var ratingText: String? {
        media.rating.map { String(format: "%.1f", $0) }
    }

    var runtimeText: String? {
        media.durationText
    }

    var genresText: String? {
        guard let genres = media.genres, !genres.isEmpty else { return nil }
        return genres.joined(separator: ", ")
    }

    func loadStreams() async {
        // First try inline streams from media
        if let inlineStreams = media.streams, !inlineStreams.isEmpty {
            streams = sortedStreams(inlineStreams)
            checkAutoPlay()
            return
        }

        guard let urlPath = media.url else { return }
        isLoading = true
        defer { isLoading = false }
        do {
            let items = try await ApiClient.fetchMenu(urlPath: urlPath)
            
            let allStreams = items.flatMap { $0.streams ?? [] }
            streams = sortedStreams(allStreams)
            checkAutoPlay()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func resolveStream(_ stream: Stream) async -> URL? {
        guard let urlPath = stream.url else { return nil }
        isResolvingStream = true
        defer { isResolvingStream = false }
        do {
            let response = try await ApiClient.fetchStream(urlPath: urlPath)
            let urlStr = response.resolved.isEmpty ? response.input : response.resolved
            return URL(string: urlStr)
        } catch {
            errorMessage = error.localizedDescription
            return nil
        }
    }

    private func sortedStreams(_ allStreams: [Stream]) -> [Stream] {
        let groupedByLang = Dictionary(grouping: allStreams) { (stream: Stream) in
            (stream.langs?.first { $0.range(of: "cz", options: .caseInsensitive) != nil } != nil) ? "CZ" : (stream.langs?.first ?? "")
        }
                                        
        func filteredAndSorted(_ streams: [Stream]) -> [Stream] {
            let hasLowerRes = streams.contains { $0.qualityRank == 1 || $0.qualityRank == 2 }
            let filtered = hasLowerRes ? streams.filter { $0.qualityRank != 3 } : streams
            return filtered.sorted { (lhs, rhs) in
                if lhs.qualityRank != rhs.qualityRank { return lhs.qualityRank < rhs.qualityRank }
                return lhs.sizeMb < rhs.sizeMb
            }
        }
        
        let czStreams = filteredAndSorted(groupedByLang["CZ"] ?? [])
        let otherLangStreams = groupedByLang.filter { $0.key != "CZ" }.flatMap { filteredAndSorted($0.value) }
        return czStreams + otherLangStreams
    }

    private func checkAutoPlay() {
        // Auto-play: resume from saved position on first stream
        if media.watchCompleted != true,
           let position = media.watchPosition, position > 0,
           let stream = streams.first {
            autoPlayResult = .autoPlay(stream: stream, resumePosition: Double(position))
            return
        }

        // Auto-play: single stream
        if streams.count == 1, let stream = streams.first {
            autoPlayResult = .autoPlay(stream: stream, resumePosition: nil)
            return
        }
    }
}
