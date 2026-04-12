import SwiftUI

struct PlayerWrapper: View {
    @Environment(SettingsManager.self) private var settingsManager
    let viewModel: PlayerViewModel

    var body: some View {
        if let internalPlayer = InternalPlaybackPlayer(player: settingsManager.playback.player) {
            if internalPlayer == .avPlayer {
                AVPlayerIOSView(viewModel: viewModel)
                    .transition(.opacity)
            } else {
                PlayerView(
                    viewModel: viewModel,
                    initialPlayer: internalPlayer,
                    options: PlayerOptions(subtitleScale: settingsManager.playback.subtitleScale),
                )
                .transition(.opacity)
            }
        } else {
            ProgressView()
                .tint(.white)
        }
    }
}
