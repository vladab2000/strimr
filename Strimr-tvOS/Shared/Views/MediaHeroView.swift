import SwiftUI
import UIKit

struct MediaHeroBackgroundView: View {

    let media: Media

    @State private var imageURL: URL?

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                MediaBackdropGradient(colors: [])
                    .ignoresSafeArea()

                HeroImageView(imageURL: imageURL)
                    .frame(
                        width: (proxy.size.width + proxy.safeAreaInsets.leading + proxy.safeAreaInsets.trailing) * 0.66,
                        height: (proxy.size.height + proxy.safeAreaInsets.top + proxy.safeAreaInsets.bottom) * 0.66,
                    )
                    .clipped()
                    .overlay(Color.black.opacity(0.2))
                    .mask(HeroMaskView())
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                    .ignoresSafeArea()
            }
        }
        .task(id: media.id) {
            await loadImage()
        }
    }

    private func loadImage() async {
        imageURL = media.funartURL
            ?? media.thumbURL
    }
}

struct MediaHeroContentView: View {
    let media: Media
    private let summaryLineLimit = 3

    var body: some View {
        heroContent
    }

    private var heroContent: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let clearlogoURL = media.clearlogoURL {
                AsyncImage(url: clearlogoURL) { phase in
                    if case .success(let image) = phase {
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(maxWidth: 400, maxHeight: 120)
                    }
                    
                }
            }
            else {
                Text(media.primaryLabel)
                    .font(.title2.bold())
                    .lineLimit(2)
            }

            if let secondary = media.secondaryLabel, media.itemType != .movie, media.itemType != .tvshow {
                Text(secondary)
                    .font(.headline)
                    .foregroundStyle(.brandSecondary)
            }

            metadataLine
            genresLine

            if let summary = media.summary, !summary.isEmpty {
                Text(summary)
                    .font(.callout)
                    .foregroundStyle(.brandSecondary)
                    .lineLimit(summaryLineLimit)
                    .frame(minHeight: summaryLineHeight * CGFloat(summaryLineLimit), alignment: .top)
            }
        }
    }

    private var summaryLineHeight: CGFloat {
        UIFont.preferredFont(forTextStyle: .callout).lineHeight
    }

    @ViewBuilder
    private var metadataLine: some View {
        HStack(spacing: 16) {
    /*        if let tertiary = media.tertiaryLabel {
                items.append(tertiary)
            }*/
            if let year = yearText {
                Text(year)
            }
            if let runtime = runtimeText {
                Label(runtime, systemImage: "clock.fill")
            }
            if let contentRating = media.rating {
                Label(String(format: "%.1f", contentRating), systemImage: "star.fill")
            }
        }
        .font(.subheadline)
        .foregroundStyle(.brandSecondary)
    }

    @ViewBuilder
    private var genresLine: some View {
        if let genres = media.genres, !genres.isEmpty {
            HStack(spacing: 12) {
                ForEach(genres, id: \.self) { genre in
                    Text(genre)
                }
            }
            .font(.caption)
            .foregroundStyle(.brandSecondary)
            .lineLimit(1)
        }
    }

    private var runtimeText: String? {
        media.durationText
    }

    private var yearText: String? {
        media.year.map(String.init)
    }
}
