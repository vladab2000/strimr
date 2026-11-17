import SwiftUI

/// Štítek titulu OnePlay mimo plán — přehraje se jen z omezeného počtu přehrání zdarma (tituly v plánu štítek nemají)
struct LimitedPlayBadge: View {
    let media: Media

    var body: some View {
        if media.limitedPlay == true {
            Label("media.badge.limitedPlay", systemImage: "ticket.fill")
                .labelStyle(.titleAndIcon)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.white)
                .padding(.horizontal, 8)
                .padding(.vertical, 5)
                .background(Color.purple.opacity(0.85), in: Capsule(style: .continuous))
                .padding(8)
        }
    }
}
