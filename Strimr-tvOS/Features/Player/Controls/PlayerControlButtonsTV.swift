import SwiftUI

struct PlayerIconButton: View {
    let systemName: String
    var accessibilityLabel: String?
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.title2.weight(.semibold))
                .foregroundStyle(.foreground)
                .frame(width: 88, height: 88)
        }
        .accessibilityLabel(accessibilityLabel ?? systemName)
    }
}

struct PlayPauseButton: View {
    var isPaused: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: isPaused ? "play.fill" : "pause.fill")
                .font(.largeTitle.weight(.black))
                .foregroundStyle(.foreground)
                .frame(width: 108, height: 108)
        }
        .accessibilityLabel(
            isPaused
                ? String(localized: "common.actions.play")
                : String(localized: "common.actions.pause"),
        )
    }
}

struct SkipMarkerButton: View {
    let title: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Text(title)
                    .font(.headline.weight(.semibold))
                Image(systemName: "chevron.right")
                    .font(.body.weight(.bold))
            }
            .foregroundStyle(.foreground)
            .padding(.horizontal, 22)
            .padding(.vertical, 14)
        }
        .accessibilityLabel(title)
    }
}

/// Kulaté ikonové tlačítko vpravo od názvu (titulky, zvuk) jako v systémovém přehrávači
struct PlayerRoundButton: View {
    var systemImage: String
    var accessibilityLabel: LocalizedStringKey
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.body.weight(.semibold))
                .frame(width: 36, height: 36)
        }
        .buttonStyle(.glass)
        .buttonBorderShape(.circle)
        .accessibilityLabel(Text(accessibilityLabel))
    }
}
