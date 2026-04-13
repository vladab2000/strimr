import AVKit
import SwiftUI

struct AVPlayerTVView: View {
    @State var viewModel: PlayerViewModel
    let onExit: () -> Void

    @State private var coordinator = AVPlayerCoordinator()
    @State private var awaitingMediaLoad = false
    @State private var isLoadingNext = false

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
                    handlePlaybackEnded()
                }
                .onMediaLoaded {
                    handleMediaLoaded()
                }
                .ignoresSafeArea()

            if isLoadingNext {
                ProgressView()
                    .scaleEffect(1.5)
            }
        }
        .onAppear {
            awaitingMediaLoad = true
            coordinator.play(viewModel.streamURL, metadata: makeMetadata())
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

    private func handlePlaybackEnded() {
        guard let nextProvider = viewModel.onPlayNextProgram else {
            onExit()
            return
        }

        isLoadingNext = true
        Task {
            if let next = await nextProvider() {
                awaitingMediaLoad = true
                viewModel.title = next.title
                let metadata = next.metadata
                coordinator.play(next.url, metadata: metadata)
                isLoadingNext = false
            } else {
                isLoadingNext = false
                onExit()
            }
        }
    }

    private func makeMetadata() -> AVPlayerMetadata {
        AVPlayerMetadata(
            title: viewModel.title,
            subtitle: viewModel.channelName,
            description: viewModel.mediaDescription,
            artworkURL: viewModel.artworkURL
        )
    }
}
