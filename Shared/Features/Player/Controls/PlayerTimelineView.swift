import SwiftUI

struct PlayerTimelineView: View {
    @Binding var position: Double
    var duration: Double?
    var bufferedAhead: Double
    var playbackPosition: Double
    var onEditingChanged: (Bool) -> Void
    var skipIntroStart: Double?
    var skipIntroEnd: Double?
    var skipTitlesStart: Double?

    private var sliderUpperBound: Double {
        max(duration ?? 0, position, playbackPosition, 1)
    }

    private var bufferedEnd: Double {
        let bufferedPosition = playbackPosition + bufferedAhead
        guard let duration else { return bufferedPosition }
        return min(bufferedPosition, duration)
    }

    private var bufferedProgress: Double {
        guard sliderUpperBound > 0 else { return 0 }
        return min(max(bufferedEnd / sliderUpperBound, 0), 1)
    }

    private var sliderBinding: Binding<Double> {
        Binding(
            get: {
                min(position, sliderUpperBound)
            },
            set: { newValue in
                position = newValue
            },
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            #if os(tvOS)
                PlayerTimelineScrubberTVView(
                    position: $position,
                    upperBound: sliderUpperBound,
                    duration: duration,
                    bufferedProgress: bufferedProgress,
                    onEditingChanged: onEditingChanged,
                    skipIntroStart: skipIntroStart,
                    skipIntroEnd: skipIntroEnd,
                    skipTitlesStart: skipTitlesStart,
                )
            #else
                ZStack {
                    bufferTrack
                    Slider(value: sliderBinding, in: 0 ... sliderUpperBound, onEditingChanged: onEditingChanged)
                        .tint(.white)
                        .shadow(color: .black.opacity(0.25), radius: 12, x: 0, y: 8)
                }
            #endif

            HStack {
                Text(elapsedText)
                Spacer()
                Text(remainingText)
            }
            .font(.footnote.monospacedDigit())
            .foregroundStyle(.white.opacity(0.9))
            .shadow(color: .black.opacity(0.3), radius: 4, x: 0, y: 2)
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 8)
    }

    private var elapsedText: String {
        formatTime(position)
    }

    private var remainingText: String {
        guard let duration else { return "--:--" }
        let remaining = max(duration - position, 0)
        return "-\(formatTime(remaining))"
    }

    private var bufferTrack: some View {
        GeometryReader { proxy in
            let width = proxy.size.width
            let bufferWidth = width * bufferedProgress
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color.white.opacity(0.35))
                Capsule()
                    .fill(Color.white.opacity(0.65))
                    .frame(width: bufferWidth)

                // Intro region
                if let introEnd = skipIntroEnd, introEnd > 0, sliderUpperBound > 0 {
                    let introStart = skipIntroStart ?? 0
                    let x = width * (introStart / sliderUpperBound)
                    let w = width * ((introEnd - introStart) / sliderUpperBound)
                    RoundedRectangle(cornerRadius: 2, style: .continuous)
                        .fill(Color.yellow.opacity(0.5))
                        .frame(width: max(w, 2))
                        .offset(x: x)
                }

                // Titles region
                if let titlesStart = skipTitlesStart, titlesStart > 0, sliderUpperBound > 0 {
                    let x = width * (titlesStart / sliderUpperBound)
                    let w = width - x
                    RoundedRectangle(cornerRadius: 2, style: .continuous)
                        .fill(Color.blue.opacity(0.4))
                        .frame(width: max(w, 2))
                        .offset(x: x)
                }
            }
            .frame(height: 4)
            .frame(maxHeight: .infinity, alignment: .center)
            .allowsHitTesting(false)
        }
        .frame(maxWidth: .infinity, maxHeight: 28)
        .accessibilityHidden(true)
    }

    private func formatTime(_ seconds: Double) -> String {
        let totalSeconds = max(Int(seconds.rounded()), 0)
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        let secs = totalSeconds % 60

        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, secs)
        } else {
            return String(format: "%02d:%02d", minutes, secs)
        }
    }
}
