import AVKit
import SwiftUI

#if canImport(UIKit)

struct AVPlayerSwiftUIView: UIViewControllerRepresentable {
    let coordinator: AVPlayerCoordinator

    func makeUIViewController(context: Context) -> AVPlayerViewController {
        let vc = AVPlayerViewController()
        vc.player = context.coordinator.player
        context.coordinator.playerViewController = vc
        return vc
    }

    func updateUIViewController(_ vc: AVPlayerViewController, context: Context) {
        if vc.player !== context.coordinator.player {
            vc.player = context.coordinator.player
        }
    }

    func makeCoordinator() -> AVPlayerCoordinator {
        coordinator
    }

    func onPropertyChange(_ handler: @escaping (PlayerProperty, Any?) -> Void) -> Self {
        coordinator.onPropertyChange = handler
        return self
    }

    func onPlaybackEnded(_ handler: @escaping () -> Void) -> Self {
        coordinator.onPlaybackEnded = handler
        return self
    }

    func onMediaLoaded(_ handler: @escaping () -> Void) -> Self {
        coordinator.onMediaLoaded = handler
        return self
    }
}

#endif
