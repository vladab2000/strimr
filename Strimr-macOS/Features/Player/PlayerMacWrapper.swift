import SwiftUI

struct PlayerMacWrapper: View {
    @Environment(SettingsManager.self) private var settingsManager
    let viewModel: PlayerViewModel

    var body: some View {
        if let internalPlayer = InternalPlaybackPlayer(player: settingsManager.playback.player) {
            PlayerMacView(
                viewModel: viewModel,
                initialPlayer: internalPlayer,
                options: PlayerOptions(subtitleScale: settingsManager.playback.subtitleScale),
            )
        } else {
            ProgressView()
                .tint(.white)
        }
    }
}
