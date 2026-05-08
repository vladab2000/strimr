import SwiftUI

struct PlayerControlsView: View {
    var title: String
    var isPaused: Bool
    var isBuffering: Bool
    @Binding var position: Double
    var duration: Double?
    var bufferedAhead: Double
    var bufferBasePosition: Double
    var isScrubbing: Bool
    var onDismiss: () -> Void
    var onShowSettings: () -> Void
    var onSeekBackward: () -> Void
    var onPlayPause: () -> Void
    var onSeekForward: () -> Void
    var seekBackwardSeconds: Int
    var seekForwardSeconds: Int
    var onScrubbingChanged: (Bool) -> Void
    var isRotationLocked: Bool
    var onToggleRotationLock: () -> Void
    var isLive: Bool
    var skipIntroStart: Double?
    var skipIntroEnd: Double?
    var skipTitlesStart: Double?

    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                PlayerControlsHeader(
                    title: title,
                    onDismiss: onDismiss,
                    onShowSettings: onShowSettings,
                )

                Spacer(minLength: 0)

                if !isLive {
                    VStack(spacing: 18) {
                        HStack {
                            RotationLockButton(isLocked: isRotationLocked, action: onToggleRotationLock)
                            Spacer()
                        }
                        .padding(.horizontal, 24)
                        .opacity(isScrubbing ? 0 : 1)
                        .allowsHitTesting(!isScrubbing)

                        PlayerTimelineView(
                            position: $position,
                            duration: duration,
                            bufferedAhead: bufferedAhead,
                            playbackPosition: bufferBasePosition,
                            onEditingChanged: onScrubbingChanged,
                            skipIntroStart: skipIntroStart,
                            skipIntroEnd: skipIntroEnd,
                            skipTitlesStart: skipTitlesStart,
                            isPaused: isPaused
                        )
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .padding(.horizontal, 20)
            .padding(.vertical, 16)

            if !isLive {
                PrimaryControls(
                    isPaused: isPaused,
                    onSeekBackward: onSeekBackward,
                    onPlayPause: onPlayPause,
                    onSeekForward: onSeekForward,
                    seekBackwardSeconds: seekBackwardSeconds,
                    seekForwardSeconds: seekForwardSeconds,
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
            }
        }
        .background {
            PlayerControlsBackground()
        }
    }
}

private struct PlayerControlsHeader: View {
    var title: String
    var onDismiss: () -> Void
    var onShowSettings: () -> Void

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            Button(action: onDismiss) {
                Image(systemName: "chevron.backward")
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(.white)
                    .frame(width: 42, height: 42)
                    .background(.white.opacity(0.12), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .stroke(Color.white.opacity(0.18), lineWidth: 1),
                    )
            }

            Text(title)
                .font(.title3.weight(.semibold))
                .foregroundStyle(.white)
                .lineLimit(2)

            Spacer()

            PlayerSettingsButton(action: onShowSettings)
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 8)
    }
}

private struct PrimaryControls: View {
    var isPaused: Bool
    var onSeekBackward: () -> Void
    var onPlayPause: () -> Void
    var onSeekForward: () -> Void
    var seekBackwardSeconds: Int
    var seekForwardSeconds: Int

    var body: some View {
        HStack(spacing: 26) {
            PlayerIconButton(
                systemName: iconName(prefix: "gobackward", seconds: seekBackwardSeconds),
                accessibilityLabel: String(localized: "player.controls.rewindSeconds \(seekBackwardSeconds)"),
                action: onSeekBackward,
            )

            PlayPauseButton(isPaused: isPaused, action: onPlayPause)

            PlayerIconButton(
                systemName: iconName(prefix: "goforward", seconds: seekForwardSeconds),
                accessibilityLabel: String(localized: "player.controls.skipForwardSeconds \(seekForwardSeconds)"),
                action: onSeekForward,
            )
        }
        .padding(.bottom, 4)
    }

    private func iconName(prefix: String, seconds: Int) -> String {
        let supported = [5, 10, 15, 30, 45, 60]
        guard supported.contains(seconds) else { return prefix }
        return "\(prefix).\(seconds)"
    }
}

private struct PlayerControlsBackground: View {
    var body: some View {
        VStack(spacing: 0) {
            LinearGradient(
                colors: [
                    .black.opacity(0.55),
                    .clear,
                ],
                startPoint: .top,
                endPoint: .bottom,
            )
            .frame(height: 180)

            Spacer()

            LinearGradient(
                colors: [
                    .clear,
                    .black.opacity(0.7),
                ],
                startPoint: .top,
                endPoint: .bottom,
            )
            .frame(height: 260)
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
    }
}
