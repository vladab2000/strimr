import SwiftUI

struct PlayerTimelineScrubberTVView: View {
    @Binding var position: Double
    var upperBound: Double
    var duration: Double?
    var bufferedProgress: Double
    var onEditingChanged: (Bool) -> Void
    var skipIntroStart: Double?
    var skipIntroEnd: Double?
    var skipTitlesStart: Double?
    var onSelect: (() -> Void)?

    @State private var consecutiveMoves = 0
    @State private var isScrubbing = false
    @State private var commitWorkItem: DispatchWorkItem?
    @FocusState private var isFocused: Bool

    private let scrubCommitDelay: TimeInterval = 0.4

    private var playbackProgress: Double {
        guard upperBound > 0 else { return 0 }
        return min(max(position / upperBound, 0), 1)
    }

    private var scrubStep: Double {
        guard let duration else { return 10 }
        return min(max(duration / 300, 5), 60)
    }

    var body: some View {
        GeometryReader { proxy in
            let width = proxy.size.width
            let progressWidth = width * playbackProgress
            let bufferedWidth = width * min(max(bufferedProgress, 0), 1)
            let thumbX = min(max(progressWidth, 0), width)

            let barHeight: CGFloat = isFocused ? 10 : 6

            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color.white.opacity(0.25))
                    .frame(height: barHeight, alignment: .center)

                Capsule()
                    .fill(Color.white.opacity(0.45))
                    .frame(width: bufferedWidth)
                    .frame(height: barHeight, alignment: .center)

                Capsule()
                    .fill(Color.white)
                    .frame(width: progressWidth)
                    .frame(height: barHeight, alignment: .center)

                // Intro region
                if let introEnd = skipIntroEnd, introEnd > 0, upperBound > 0 {
                    let introStart = skipIntroStart ?? 0
                    let x = width * (introStart / upperBound)
                    let w = width * ((introEnd - introStart) / upperBound)
                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                        .fill(Color.yellow.opacity(0.5))
                        .frame(width: max(w, 3), height: barHeight)
                        .offset(x: x)
                }

                // Titles region
                if let titlesStart = skipTitlesStart, titlesStart > 0, upperBound > 0 {
                    let x = width * (titlesStart / upperBound)
                    let w = width - x
                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                        .fill(Color.blue.opacity(0.4))
                        .frame(width: max(w, 3), height: barHeight)
                        .offset(x: x)
                }

                // Jezdec jen při fokusu (systémový přehrávač ho bez fokusu nezobrazuje)
                Capsule()
                    .fill(Color.white)
                    .frame(width: 6, height: 30)
                    .shadow(color: .black.opacity(0.45), radius: 8, x: 0, y: 4)
                    .offset(x: max(0, thumbX - 3))
                    .opacity(isFocused ? 1 : 0)

                // Čas nad jezdcem při posouvání
                if isScrubbing {
                    Text(Self.formatTime(position))
                        .font(.callout.monospacedDigit().weight(.semibold))
                        .foregroundStyle(.black)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(.white, in: Capsule())
                        .fixedSize()
                        .position(x: min(max(thumbX, 50), width - 50), y: -34)
                }
            }
            .frame(maxHeight: .infinity)
            .animation(.easeInOut(duration: 0.15), value: isFocused)
        }
        .contentShape(Rectangle())
        .frame(maxWidth: .infinity, maxHeight: 32)
        .focusable()
        .focused($isFocused)
        .onTapGesture {
            onSelect?()
        }
        .onMoveCommand { direction in
            guard isFocused else { return }

            startScrubbingIfNeeded()
            
            consecutiveMoves += 1
            let multiplier = min(Double(consecutiveMoves), 5)
            let delta = scrubStep * multiplier
            
            switch direction {
            case .left:
                position = max(0, position - delta)
            case .right:
                position = min(upperBound, position + delta)
            default:
                break
            }

            scheduleCommit()
        }
        .onChange(of: isFocused) { _, focused in
            if !focused {
                finishScrubbingIfNeeded()
            }
        }
        .onDisappear {
            commitWorkItem?.cancel()
        }
        .accessibilityHidden(true)
    }

    static func formatTime(_ seconds: Double) -> String {
        let total = max(Int(seconds.rounded()), 0)
        let hours = total / 3600, minutes = (total % 3600) / 60, secs = total % 60
        return hours > 0
            ? String(format: "%d:%02d:%02d", hours, minutes, secs)
            : String(format: "%02d:%02d", minutes, secs)
    }

    private func startScrubbingIfNeeded() {
        guard !isScrubbing else { return }
        isScrubbing = true
        onEditingChanged(true)
    }

    private func scheduleCommit() {
        commitWorkItem?.cancel()
        let workItem = DispatchWorkItem {
            isScrubbing = false
            consecutiveMoves = 0
            onEditingChanged(false)
        }
        commitWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + scrubCommitDelay, execute: workItem)
    }

    private func finishScrubbingIfNeeded() {
        consecutiveMoves = 0
        commitWorkItem?.cancel()
        commitWorkItem = nil

        guard isScrubbing else { return }
        isScrubbing = false
        onEditingChanged(false)
    }
}
