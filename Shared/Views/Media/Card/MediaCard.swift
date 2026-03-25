import SwiftUI

struct MediaCard: View {
    #if os(tvOS)
        @Environment(MediaFocusModel.self) private var focusModel
        @FocusState private var isFocused: Bool
    #endif

    let size: CGSize
    let media: Media
    let artworkKind: MediaImageViewModel.ArtworkKind
    let showsLabels: Bool
    let onTap: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: labelSpacing) {
            artwork
            #if os(tvOS)
            .scaleEffect(isFocused ? 1.12 : 1)
            .animation(.easeOut(duration: 0.15), value: isFocused)
            #endif

            if showsLabels {
                VStack(alignment: .leading, spacing: 4) {
                    Text(media.primaryLabel)
                        .font(primaryLabelFont)
                        .lineLimit(1)
                    Text(media.secondaryLabel ?? "")
                        .font(secondaryLabelFont)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
        }
        .frame(width: size.width, alignment: .leading)
        #if os(tvOS)
            .focusable()
            .focused($isFocused)
            .onChange(of: isFocused) { _, focused in
                            if focused {
                                focusModel.focusedMedia = media
                            }
                        }
            .onPlayPauseCommand(perform: onTap)
        #endif
            .onTapGesture(perform: onTap)
    }

    private var artwork: some View {
        MediaImageView(
            viewModel: MediaImageViewModel(
                artworkKind: artworkKind,
                media: media,
            ),
        )
        .frame(width: size.width, height: size.height)
        .clipShape(
            RoundedRectangle(cornerRadius: 14, style: .continuous),
        )
        .overlay(alignment: .bottom) {
            if let progress = media.progressFraction {
                GeometryReader { geo in
                    VStack {
                        Spacer()
                        ZStack(alignment: .leading) {
                            Rectangle()
                                .fill(Color.gray.opacity(0.4))
                                .frame(height: 4)
                            Rectangle()
                                .fill(Color.brandPrimary)
                                .frame(width: geo.size.width * progress, height: 4)
                        }
                    }
                }
                .clipShape(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                )
            }
        }
    }

    private var labelSpacing: CGFloat {
        #if os(tvOS)
            20
        #else
            8
        #endif
    }

    private var primaryLabelFont: Font {
        #if os(tvOS)
            size.width < 180 ? .footnote : .subheadline
        #else
            .subheadline
        #endif
    }

    private var secondaryLabelFont: Font {
        #if os(tvOS)
            size.width < 180 ? .caption2 : .footnote
        #else
            .footnote
        #endif
    }
}
