import Foundation

struct PlaybackLauncher {
    let coordinator: MainCoordinator

    func play(stream: Stream) async {
        guard let urlPath = stream.url else { return }

        do {
            let response = try await ApiClient.fetchStream(urlPath: urlPath)
            guard let streamURL = URL(string: response.resolved) else { return }
            await MainActor.run {
                coordinator.showPlayer(streamURL: streamURL, title: stream.name)
            }
        } catch {
            debugPrint("Failed to resolve stream:", error)
        }
    }
}
