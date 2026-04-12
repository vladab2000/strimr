import SwiftUI

struct PlayerControlsMacView: View {
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
    var isLive: Bool

    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                PlayerControlsMacHeader(
                    title: title,
                    onDismiss: onDismiss,
                    onShowSettings: onShowSettings,
                )

                Spacer(minLength: 0)

                if !isLive {
                    PlayerTimelineView(
                        position: $position,
                        duration: duration,
                        bufferedAhead: bufferedAhead,
                        playbackPosition: bufferBasePosition,
                        onEditingChanged: onScrubbingChanged,
                    )
                    .padding(.horizontal, 20)
                    .padding(.bottom, 16)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)

            if !isLive {
                PrimaryControlsMac(
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
            PlayerControlsMacBackground()
        }
    }
}

private struct PlayerControlsMacHeader: View {
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
            .buttonStyle(.plain)

            Text(title)
                .font(.title3.weight(.semibold))
                .foregroundStyle(.white)
                .lineLimit(2)

            Spacer()

            PlayerSettingsMacButton(action: onShowSettings)
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 8)
    }
}

private struct PrimaryControlsMac: View {
    var isPaused: Bool
    var onSeekBackward: () -> Void
    var onPlayPause: () -> Void
    var onSeekForward: () -> Void
    var seekBackwardSeconds: Int
    var seekForwardSeconds: Int

    var body: some View {
        HStack(spacing: 26) {
            PlayerIconMacButton(
                systemName: iconName(prefix: "gobackward", seconds: seekBackwardSeconds),
                accessibilityLabel: String(localized: "player.controls.rewindSeconds \(seekBackwardSeconds)"),
                action: onSeekBackward,
            )

            PlayPauseMacButton(isPaused: isPaused, action: onPlayPause)

            PlayerIconMacButton(
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

private struct PlayerControlsMacBackground: View {
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

struct PlayerIconMacButton: View {
    let systemName: String
    var accessibilityLabel: String?
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.title3.weight(.bold))
                .foregroundStyle(.white)
                .frame(width: 58, height: 58)
                .background(
                    LinearGradient(
                        colors: [
                            .white.opacity(0.18),
                            .white.opacity(0.08),
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing,
                    ),
                    in: Circle(),
                )
                .overlay(
                    Circle()
                        .stroke(Color.white.opacity(0.25), lineWidth: 1),
                )
                .shadow(color: .black.opacity(0.35), radius: 18, x: 0, y: 12)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(accessibilityLabel ?? systemName)
    }
}

struct PlayPauseMacButton: View {
    var isPaused: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: isPaused ? "play.fill" : "pause.fill")
                .font(.title.weight(.black))
                .foregroundStyle(.black)
                .frame(width: 72, height: 72)
                .background(
                    LinearGradient(
                        colors: [
                            Color.white,
                            Color.white.opacity(0.85),
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing,
                    ),
                    in: Circle(),
                )
                .overlay(
                    Circle()
                        .stroke(Color.white.opacity(0.35), lineWidth: 1),
                )
                .shadow(color: .black.opacity(0.4), radius: 20, x: 0, y: 14)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(isPaused
            ? String(localized: "common.actions.play")
            : String(localized: "common.actions.pause"))
    }
}

struct PlayerSettingsMacButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "gearshape")
                .font(.headline.weight(.semibold))
                .foregroundStyle(.white)
                .frame(width: 42, height: 42)
                .background(.white.opacity(0.12), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(Color.white.opacity(0.18), lineWidth: 1),
                )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(String(localized: "settings.title"))
    }
}
