import Foundation
import SwiftUI

enum PlayerFactory {
    static func makeCoordinator(
        for selection: InternalPlaybackPlayer,
        options: PlayerOptions,
    ) -> any PlayerCoordinating {
        switch selection {
        case .mpv:
            #if os(macOS)
            let coordinator = MPVPlayerViewMac.Coordinator()
            coordinator.options = options
            return coordinator
            #else
            let coordinator = MPVPlayerView.Coordinator()
            coordinator.options = options
            return coordinator
            #endif
        case .vlc:
            #if canImport(UIKit)
            let coordinator = VLCPlayerView.Coordinator()
            coordinator.options = options
            return coordinator
            #else
            let coordinator = MPVPlayerViewMac.Coordinator()
            coordinator.options = options
            return coordinator
            #endif
        case .avPlayer:
            #if canImport(UIKit)
            let coordinator = AVPlayerCoordinator()
            coordinator.options = options
            return coordinator
            #else
            let coordinator = MPVPlayerViewMac.Coordinator()
            coordinator.options = options
            return coordinator
            #endif
        }
    }

    static func makeView(
        selection: InternalPlaybackPlayer,
        coordinator: any PlayerCoordinating,
        onPropertyChange: @escaping (PlayerProperty, Any?) -> Void,
        onPlaybackEnded: @escaping () -> Void,
        onMediaLoaded: @escaping () -> Void,
    ) -> AnyView {
        switch selection {
        case .mpv:
            #if os(macOS)
            guard let mpvCoordinator = coordinator as? MPVPlayerViewMac.Coordinator else {
                assertionFailure("MPV coordinator expected")
                return AnyView(EmptyView())
            }
            return AnyView(
                MPVPlayerViewMac(coordinator: mpvCoordinator)
                    .onPropertyChange { _, property, data in
                        onPropertyChange(property, data)
                    }
                    .onPlaybackEnded(onPlaybackEnded)
                    .onMediaLoaded(onMediaLoaded),
            )
            #else
            guard let mpvCoordinator = coordinator as? MPVPlayerView.Coordinator else {
                assertionFailure("MPV coordinator expected")
                return AnyView(EmptyView())
            }
            return AnyView(
                MPVPlayerView(coordinator: mpvCoordinator)
                    .onPropertyChange { _, property, data in
                        onPropertyChange(property, data)
                    }
                    .onPlaybackEnded(onPlaybackEnded)
                    .onMediaLoaded(onMediaLoaded),
            )
            #endif
        case .vlc:
            #if canImport(UIKit)
            guard let vlcCoordinator = coordinator as? VLCPlayerView.Coordinator else {
                assertionFailure("VLC coordinator expected")
                return AnyView(EmptyView())
            }
            return AnyView(
                VLCPlayerView(coordinator: vlcCoordinator)
                    .onPropertyChange { _, property, data in
                        onPropertyChange(property, data)
                    }
                    .onPlaybackEnded(onPlaybackEnded)
                    .onMediaLoaded(onMediaLoaded),
            )
            #else
            guard let mpvCoordinator = coordinator as? MPVPlayerViewMac.Coordinator else {
                assertionFailure("MPV coordinator expected for VLC fallback on macOS")
                return AnyView(EmptyView())
            }
            return AnyView(
                MPVPlayerViewMac(coordinator: mpvCoordinator)
                    .onPropertyChange { _, property, data in
                        onPropertyChange(property, data)
                    }
                    .onPlaybackEnded(onPlaybackEnded)
                    .onMediaLoaded(onMediaLoaded),
            )
            #endif
        case .avPlayer:
            #if canImport(UIKit)
            guard let avCoordinator = coordinator as? AVPlayerCoordinator else {
                assertionFailure("AVPlayer coordinator expected")
                return AnyView(EmptyView())
            }
            return AnyView(
                AVPlayerSwiftUIView(coordinator: avCoordinator)
                    .onPropertyChange { property, data in
                        onPropertyChange(property, data)
                    }
                    .onPlaybackEnded(onPlaybackEnded)
                    .onMediaLoaded(onMediaLoaded),
            )
            #else
            guard let mpvCoordinator = coordinator as? MPVPlayerViewMac.Coordinator else {
                assertionFailure("MPV coordinator expected for AVPlayer fallback on macOS")
                return AnyView(EmptyView())
            }
            return AnyView(
                MPVPlayerViewMac(coordinator: mpvCoordinator)
                    .onPropertyChange { _, property, data in
                        onPropertyChange(property, data)
                    }
                    .onPlaybackEnded(onPlaybackEnded)
                    .onMediaLoaded(onMediaLoaded),
            )
            #endif
        }
    }
}
