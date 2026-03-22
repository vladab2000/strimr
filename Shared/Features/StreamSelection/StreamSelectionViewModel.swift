import Foundation
import Observation

@MainActor
@Observable
final class StreamSelectionViewModel {
    let media: MediaDisplayItem
    var streams: [Stream] = []
    var isLoading = false
    var isResolvingStream = false
    var errorMessage: String?

    init(media: MediaDisplayItem) {
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
        guard let duration = media.duration else { return nil }
        return TimeInterval(duration).mediaDurationText()
    }

    var genresText: String? {
        guard let genres = media.genres, !genres.isEmpty else { return nil }
        return genres.joined(separator: ", ")
    }

    func loadStreams() async {
        guard let urlPath = media.url else { return }
        isLoading = true
        defer { isLoading = false }
        do {
            let response = try await ApiClient.fetchMenu(urlPath: urlPath)
            
            let allStreams = response.items.compactMap { $0 as? Stream }
            
            // Rozdělení podle jazyků
            let groupedByLang = Dictionary(grouping: allStreams) { (stream: Stream) in
                (stream.langs?.first { $0.range(of: "cz", options: .caseInsensitive) != nil } != nil) ? "CZ" : (stream.langs?.first ?? "")
            }
                                    
            func filteredAndSorted(_ streams: [Stream]) -> [Stream] {
                // odstraníme 4K pokud existuje 1080p nebo 720p stejného jazyka
                let hasLowerRes = streams.contains { $0.qualityRank == 1 || $0.qualityRank == 2 }
                let filtered = hasLowerRes ? streams.filter { $0.qualityRank != 3 } : streams
                return filtered.sorted { (lhs, rhs) in
                    if lhs.qualityRank != rhs.qualityRank { return lhs.qualityRank < rhs.qualityRank }
                    return lhs.sizeMb < rhs.sizeMb
                }
            }
            
            let czStreams = filteredAndSorted(groupedByLang["CZ"] ?? [])
            let otherLangStreams = groupedByLang.filter { $0.key != "CZ" }.flatMap { filteredAndSorted($0.value) }
            streams = czStreams + otherLangStreams
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
}
