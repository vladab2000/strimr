import SwiftUI

/// Načítání videa, obnovování po výpadku a chyba přehrávání (uprostřed obrazovky)
struct PlayerStatusOverlay: View {
    let status: PlayerViewModel.PlaybackStatus
    let onRetry: () -> Void
    let onClose: () -> Void

    #if os(tvOS)
    @FocusState private var isRetryFocused: Bool
    #endif

    var body: some View {
        switch status {
        case .playing:
            EmptyView()
        case .loading:
            progress(Text("player.status.loading"))
        case let .recovering(attempt):
            progress(
                attempt > 0
                    ? Text(String(format: String(localized: "player.status.recovering"), attempt, PlayerViewModel.maxRecoveryAttempts))
                    : Text("player.status.loading")
            )
        case let .failed(message):
            failed(message)
        }
    }

    private func progress(_ text: Text) -> some View {
        VStack(spacing: 16) {
            ProgressView()
                .controlSize(.large)
                .tint(.white)
            text
                .font(.callout.weight(.semibold))
                .foregroundStyle(.white.opacity(0.9))
        }
        .padding(28)
        .background(.black.opacity(0.45), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .allowsHitTesting(false)
    }

    private func failed(_ message: String?) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.largeTitle)
                .foregroundStyle(.yellow)
            Text("player.status.failed")
                .font(.headline)
            if let message, !message.isEmpty {
                Text(message)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            HStack(spacing: 16) {
                Button(action: onRetry) {
                    Label("player.status.retry", systemImage: "arrow.clockwise")
                }
                #if os(tvOS)
                .focused($isRetryFocused)
                #else
                .buttonStyle(.borderedProminent)
                #endif

                Button("common.actions.close", action: onClose)
                #if !os(tvOS)
                    .buttonStyle(.bordered)
                #endif
            }
        }
        .padding(32)
        .frame(maxWidth: 640)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        #if os(tvOS)
        .onAppear { isRetryFocused = true }
        #endif
    }
}
