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
            coordinator.play(ApiClient.playbackURL(sessionId: viewModel.sessionId), metadata: makeMetadata())
            configureTransportBarActions()
            viewModel.onSeek = { [coordinator] position in
                coordinator.seek(to: position)
            }
            viewModel.startKeepalive()
        }
        .onDisappear {
            viewModel.stopKeepalive()
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
                viewModel.sessionId = next.sessionId
                viewModel.title = next.title
                let metadata = next.metadata
                coordinator.play(ApiClient.playbackURL(sessionId: next.sessionId), metadata: metadata)
                isLoadingNext = false
            } else {
                isLoadingNext = false
                onExit()
            }
        }
    }

    private func configureTransportBarActions() {
        coordinator.configureTransportBarActions(
            onPlayFromBeginning: viewModel.isLive ? nil : { [coordinator] in
                coordinator.seek(to: 0)
            },
            onGoToLive: viewModel.onGoToLive != nil ? { handleGoToLive() } : nil
        )
    }

    private func handleGoToLive() {
        guard let goToLiveProvider = viewModel.onGoToLive else { return }

        isLoadingNext = true
        Task {
            if let live = await goToLiveProvider() {
                awaitingMediaLoad = true
                viewModel.title = live.title
                viewModel.isLive = true
                coordinator.play(ApiClient.playbackURL(sessionId: live.sessionId), metadata: live.metadata)
                configureTransportBarActions()
                isLoadingNext = false
            } else {
                isLoadingNext = false
            }
        }
    }

    private func makeMetadata() -> AVPlayerMetadata {
        AVPlayerMetadata(
            channel: viewModel.channelName,
            title: viewModel.title,
            subtitle: viewModel.channelName,
            description: viewModel.mediaDescription,
            artworkURL: viewModel.artworkURL,
            startDate: viewModel.startDate,
            endDate: viewModel.endDate
        )
    }
}
