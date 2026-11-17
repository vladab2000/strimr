import SwiftUI

/// Detail seriálu: "Pokračovat S02E05" / "Další díl S02E06"
struct SeriesContinueButton: View {
    let title: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Label(title, systemImage: "play.fill")
        }
        #if os(tvOS)
        .buttonStyle(.automatic)
        #else
        .buttonStyle(.borderedProminent)
        #endif
    }
}
