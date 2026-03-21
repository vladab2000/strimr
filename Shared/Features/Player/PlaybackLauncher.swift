import Foundation

struct PlaybackLauncher {
    let coordinator: MainCoordinator

    func play(item: MediaDisplayItem) async {
        guard let urlPath = item.url else { return }

        do {
            let response = try await ApiClient.fetchStream(urlPath: urlPath)
            guard let streamURL = URL(string: response.resolved) else { return }
            await MainActor.run {
                coordinator.showPlayer(streamURL: streamURL, title: item.title)
            }
        } catch {
            debugPrint("Failed to resolve stream:", error)
        }
    }
}
