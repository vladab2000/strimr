import SwiftUI

struct PlayerTVWrapper: View {
    @Environment(SettingsManager.self) private var settingsManager
    let viewModel: PlayerViewModel
    let onExit: () -> Void

    var body: some View {
        if let internalPlayer = InternalPlaybackPlayer(player: settingsManager.playback.player) {
            if internalPlayer == .avPlayer {
                AVPlayerTVView(viewModel: viewModel, onExit: onExit)
            } else {
                PlayerTVView(
                    viewModel: viewModel,
                    initialPlayer: internalPlayer,
                    options: PlayerOptions(subtitleScale: settingsManager.playback.subtitleScale),
                    onExit: onExit,
                )
            }
        } else {
            ProgressView()
        }
    }
}
