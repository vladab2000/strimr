import SwiftUI

struct StreamCinemaSearchResultCard: View {
    let item: any MediaItem

    var body: some View {
        HStack(spacing: 12) {
            artwork
            details
            Spacer()
        }
        .contentShape(Rectangle())
    }

    private var artwork: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color.gray.opacity(0.2))

            if let url = item.posterURL {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case let .success(image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    default:
                        placeholderIcon
                    }
                }
            } else {
                placeholderIcon
            }
        }
        .frame(width: 60, height: 90)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    private var placeholderIcon: some View {
        Image(systemName: "film")
            .font(.system(size: 20))
            .foregroundStyle(.gray)
    }

    private var details: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(item.name)
                .font(.subheadline)
                .fontWeight(.semibold)
                .lineLimit(2)

            if let info = item as? any MediaInfo {
                if let year = info.year {
                    Text(String(year))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                if let genreString = info.genreString {
                    Text(genreString)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                if let duration = info.durationString {
                    Text(duration)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
}
