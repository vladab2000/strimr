import SwiftUI

/// Ovládání přehrávače ve stylu systémového přehrávače Apple TV: vlevo menší řádek (epizoda) a název,
/// vpravo kulatá tlačítka titulků, zvuku a rychlosti, pod nimi časová osa s časem u přehrávací hlavy.
/// Pozastavení/spuštění stiskem na časové ose nebo tlačítkem Play/Pause na ovladači.
struct PlayerControlsTVView: View {
    var title: String
    var subtitle: String?
    var isPaused: Bool
    var supportsHDR: Bool
    @Binding var position: Double
    var duration: Double?
    var bufferedAhead: Double
    var bufferBasePosition: Double
    var isScrubbing: Bool
    var onShowAudioSettings: () -> Void
    var onShowSubtitleSettings: () -> Void
    var onShowSpeedSettings: () -> Void
    var onPlayPause: () -> Void
    var onScrubbingChanged: (Bool) -> Void
    var onUserInteraction: () -> Void
    var isLive: Bool
    var skipIntroStart: Double?
    var skipIntroEnd: Double?
    var skipTitlesStart: Double?
    @FocusState private var focusedControl: FocusTarget?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Spacer()

            HStack(alignment: .bottom, spacing: 24) {
                VStack(alignment: .leading, spacing: 6) {
                    if let subtitle, !subtitle.isEmpty {
                        Text(subtitle)
                            .font(.callout.weight(.medium))
                            .foregroundStyle(.white.opacity(0.85))
                            .lineLimit(1)
                    }

                    HStack(alignment: .firstTextBaseline, spacing: 16) {
                        Text(title)
                            .font(.title2.weight(.bold))
                            .foregroundStyle(.white)
                            .lineLimit(1)

                        if supportsHDR {
                            PlayerBadge(String(localized: "player.badge.hdr"), systemImage: "sparkles")
                        }

                        if isLive {
                            Text("LIVE")
                                .font(.caption.weight(.bold))
                                .padding(.horizontal, 10)
                                .padding(.vertical, 4)
                                .background(.red, in: Capsule())
                                .foregroundStyle(.white)
                        }
                    }
                }

                Spacer()

                HStack(spacing: 20) {
                    PlayerRoundButton(
                        systemImage: "captions.bubble",
                        accessibilityLabel: "player.settings.subtitles",
                        action: onShowSubtitleSettings,
                    )

                    PlayerRoundButton(
                        systemImage: "waveform",
                        accessibilityLabel: "player.settings.audio",
                        action: onShowAudioSettings,
                    )
                    .focused($focusedControl, equals: .audio)

                    if !isLive {
                        PlayerRoundButton(
                            systemImage: "gauge.with.dots.needle.67percent",
                            accessibilityLabel: "player.settings.speed",
                            action: onShowSpeedSettings,
                        )
                    }
                }
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 16)

            if !isLive {
                PlayerTimelineView(
                    position: $position,
                    duration: duration,
                    bufferedAhead: bufferedAhead,
                    playbackPosition: bufferBasePosition,
                    onEditingChanged: onScrubbingChanged,
                    skipIntroStart: skipIntroStart,
                    skipIntroEnd: skipIntroEnd,
                    skipTitlesStart: skipTitlesStart,
                    onSelect: onPlayPause,
                    isPaused: isPaused,
                )
                .focused($focusedControl, equals: .timeline)
            }
        }
        .padding(.horizontal, 60)
        .padding(.bottom, 50)
        .background {
            PlayerControlsTVBackground()
        }
        .onAppear {
            // Jako systémový přehrávač: fokus na časové ose (vlevo/vpravo posun, stisk = pauza)
            focusedControl = isLive ? .audio : .timeline
        }
        .onMoveCommand { _ in
            onUserInteraction()
        }
    }
}

private enum FocusTarget: Hashable {
    case timeline
    case audio
}

private struct PlayerControlsTVBackground: View {
    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            LinearGradient(
                colors: [
                    .clear,
                    .black.opacity(0.45),
                    .black.opacity(0.8),
                ],
                startPoint: .top,
                endPoint: .bottom,
            )
            .frame(height: 440)
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
    }
}
