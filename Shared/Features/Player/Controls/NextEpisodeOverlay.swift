import SwiftUI

/// Odpočet do dalšího dílu v pravém dolním rohu přehrávače
struct NextEpisodeOverlay: View {
    let label: String
    let secondsLeft: Int
    let onPlayNow: () -> Void
    let onCancel: () -> Void

    #if os(tvOS)
    @FocusState private var isPlayFocused: Bool
    #endif

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(String(format: String(localized: "player.nextEpisode.countdown"), secondsLeft))
                .font(.callout)
                .foregroundStyle(.secondary)
            Text(label)
                .font(.headline)
                .lineLimit(2)

            HStack(spacing: 16) {
                Button(action: onPlayNow) {
                    Label("player.nextEpisode.playNow", systemImage: "play.fill")
                }
                #if os(tvOS)
                .focused($isPlayFocused)
                #else
                .buttonStyle(.borderedProminent)
                #endif

                Button("common.actions.cancel", action: onCancel)
                #if !os(tvOS)
                    .buttonStyle(.bordered)
                #endif
            }
        }
        .padding(24)
        .frame(maxWidth: 560, alignment: .leading)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        #if os(tvOS)
        .onAppear { isPlayFocused = true }
        #endif
    }
}
