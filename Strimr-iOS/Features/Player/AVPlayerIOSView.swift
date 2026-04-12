import AVKit
import SwiftUI

struct AVPlayerIOSView: View {
    @Environment(\.dismiss) private var dismiss
    @State var viewModel: PlayerViewModel

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
                    dismiss()
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
        .statusBarHidden()
        .persistentSystemOverlays(.hidden)
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
