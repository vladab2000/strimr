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
            coordinator.drm = viewModel.drm
            // Televize přes playback session, filmy a díly (bez session) přímo z vyřešeného streamu
            let url = viewModel.sessionId.isEmpty ? viewModel.streamURL : ApiClient.playbackURL(sessionId: viewModel.sessionId)
            coordinator.play(url, seekPosition: viewModel.resumePosition, metadata: makeMetadata())
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
                viewModel.startDate = next.metadata.startDate
                viewModel.endDate = next.metadata.endDate
                let metadata = next.metadata
                coordinator.play(ApiClient.playbackURL(sessionId: next.sessionId), seekPosition: 0.0, metadata: metadata)
                // Další pořad může být právě vysílaný — pak se nabídne „Přejít na živé“
                configureTransportBarActions()
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
            onGoToLive: viewModel.onGoToLive != nil && isLiveOrAiring ? { handleGoToLive() } : nil
        )
    }

    /// „Přejít na živé“ jen u živého vysílání a právě vysílaného pořadu — odvysílaný archiv živé vysílání nemá
    private var isLiveOrAiring: Bool {
        viewModel.isLive || (viewModel.endDate ?? .distantPast) > Date.now
    }

    private func handleGoToLive() {
        guard let goToLiveProvider = viewModel.onGoToLive else { return }

        isLoadingNext = true
        Task {
            if let live = await goToLiveProvider() {
                awaitingMediaLoad = true
                viewModel.title = live.title
                viewModel.isLive = true
                coordinator.play(ApiClient.playbackURL(sessionId: live.sessionId), seekPosition: nil, metadata: live.metadata)
                configureTransportBarActions()
                isLoadingNext = false
            } else {
                isLoadingNext = false
            }
        }
    }

    private func makeMetadata() -> AVPlayerMetadata {
        AVPlayerMetadata(
            title: viewModel.title,
            subtitle: viewModel.channelName,
            description: viewModel.mediaDescription,
            artworkURL: viewModel.artworkURL,
            startDate: viewModel.startDate,
            endDate: viewModel.endDate
        )
    }
}
