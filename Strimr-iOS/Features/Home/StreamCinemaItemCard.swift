import SwiftUI

struct StreamCinemaItemCard: View {
    let item: any MediaItem
    let onTap: () -> Void

    @Environment(\.horizontalSizeClass) private var sizeClass

    private let aspectRatio: CGFloat = 2 / 3

    private var cardHeight: CGFloat {
        sizeClass == .compact ? 180 : 240
    }

    private var cardWidth: CGFloat {
        cardHeight * aspectRatio
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            artwork
            labels
        }
        .frame(width: cardWidth, alignment: .leading)
        .onTapGesture(perform: onTap)
    }

    private var artwork: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.gray.opacity(0.2))

            if let url = item.posterURL {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case let .success(image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    case .failure:
                        placeholderIcon
                    case .empty:
                        ProgressView()
                    @unknown default:
                        placeholderIcon
                    }
                }
            } else {
                placeholderIcon
            }
        }
        .frame(width: cardWidth, height: cardHeight)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private var placeholderIcon: some View {
        Image(systemName: "film")
            .font(.system(size: 28, weight: .semibold))
            .foregroundStyle(.gray)
    }

    private var labels: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(item.name)
                .font(.subheadline)
                .lineLimit(2)
                .foregroundStyle(.primary)

            if let info = item as? any MediaInfo, let year = info.year {
                Text(String(year))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}
