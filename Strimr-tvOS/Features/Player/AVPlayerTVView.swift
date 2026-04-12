import AVKit
import SwiftUI

struct AVPlayerTVView: View {
    @State var viewModel: PlayerViewModel
    let onExit: () -> Void

    @State private var coordinator = AVPlayerCoordinator()
    @State private var awaitingMediaLoad = false

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            AVPlayerSwiftUIView(coordinator: coordinator)
                .onPropertyChange { property, data in
                    viewModel.handlePropertyChange(
                        property: property,
                        data: data,
                        isScrubbing: false
                    )
                }
                .onPlaybackEnded {
                    onExit()
                }
                .onMediaLoaded {
                    handleMediaLoaded()
                }
                .ignoresSafeArea()
        }
        .onAppear {
            awaitingMediaLoad = true
            coordinator.play(viewModel.streamURL)
            viewModel.onSeek = { [coordinator] position in
                coordinator.seek(to: position)
            }
        }
        .onDisappear {
            viewModel.handleStop()
            coordinator.destruct()
        }
        .onExitCommand {
            onExit()
        }
    }

    private func handleMediaLoaded() {
        guard awaitingMediaLoad else { return }
        awaitingMediaLoad = false

        if let resume = viewModel.resumePosition, resume > 0 {
            coordinator.seek(to: resume)
            viewModel.resumePosition = nil
        }
    }
}
