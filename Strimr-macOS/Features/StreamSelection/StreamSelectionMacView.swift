import SwiftUI

struct StreamSelectionMacView: View {
    @EnvironmentObject private var coordinator: MainCoordinator
    @State var viewModel: StreamSelectionViewModel
    @State private var isSummaryExpanded = false
    private let heroHeight: CGFloat = 320
    private let onPlay: (Stream, Double?) -> Void

    init(
        viewModel: StreamSelectionViewModel,
        onPlay: @escaping (Stream, Double?) -> Void = { _, _ in }
    ) {
        _viewModel = State(initialValue: viewModel)
        self.onPlay = onPlay
    }

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 16) {
                heroSection

                VStack(alignment: .leading, spacing: 12) {
                    Text(viewModel.media.title)
                        .font(.title2.bold())
                        .padding(.horizontal, 16)

                    metadataBadges
                        .padding(.horizontal, 16)

                    if let summary = viewModel.media.summary, !summary.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text(summary)
                                .font(.body)
                                .foregroundStyle(.secondary)
                                .lineLimit(isSummaryExpanded ? nil : 3)

                            Button(isSummaryExpanded
                                ? String(localized: "common.actions.showLess")
                                : String(localized: "common.actions.showMore"))
                            {
                                withAnimation { isSummaryExpanded.toggle() }
                            }
                            .font(.callout.weight(.semibold))
                            .foregroundStyle(.brandPrimary)
                        }
                        .padding(.horizontal, 16)
                    }
                }

                streamsSection
            }
        }
    }

    // MARK: - Hero

    private var heroSection: some View {
        ZStack(alignment: .bottomLeading) {
            if let url = viewModel.heroImageURL {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case let .success(image):
                        image
                            .resizable()
                            .scaledToFill()
                    case .failure:
                        Color.gray.opacity(0.3)
                    default:
                        Color.gray.opacity(0.15)
                    }
                }
                .frame(height: heroHeight)
                .clipped()
            } else {
                Color.gray.opacity(0.15)
                    .frame(height: heroHeight)
            }

            LinearGradient(
                colors: [.clear, Color("Background")],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: heroHeight / 2)
            .frame(maxHeight: .infinity, alignment: .bottom)
        }
        .frame(height: heroHeight)
    }

    // MARK: - Metadata Badges

    private var metadataBadges: some View {
        HStack(spacing: 12) {
            if let year = viewModel.yearText {
                Text(year)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            if let rating = viewModel.ratingText {
                HStack(spacing: 4) {
                    Image(systemName: "star.fill")
                        .font(.caption)
                        .foregroundStyle(.yellow)
                    Text(rating)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }

            if let runtime = viewModel.runtimeText {
                Text(runtime)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            if let genres = viewModel.genresText {
                Text(genres)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
    }

    // MARK: - Streams Section

    @ViewBuilder
    private var streamsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("streamSelection.title")
                .font(.headline)
                .padding(.horizontal, 16)

            if viewModel.streams.isEmpty {
                Text("streamSelection.noStreams")
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 16)
            } else {
                LazyVStack(spacing: 8) {
                    ForEach(viewModel.streams, id: \.id) { stream in
                        streamRow(stream)
                    }
                }
                .padding(.horizontal, 16)
            }
        }

        if viewModel.isResolvingStream {
            ProgressView("streamSelection.resolving")
                .frame(maxWidth: .infinity)
                .padding()
        }
    }

    private func streamRow(_ stream: Stream) -> some View {
        Button {
            onPlay(stream, nil)
        } label: {
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 8) {
                    Image(systemName: "play.circle.fill")
                        .font(.title2)
                        .foregroundStyle(.brandPrimary)

                    if let quality = stream.quality {
                        Text(quality)
                            .font(.subheadline.weight(.semibold))
                    }

                    if let size = stream.size {
                        Text("·")
                            .foregroundStyle(.secondary)
                        Text(size)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }

                    if let langs = stream.langs, !langs.isEmpty {
                        Text("·")
                            .foregroundStyle(.secondary)
                        Text(langs.joined(separator: ", "))
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()
                }

                HStack(spacing: 8) {
                    if let videoInfo = stream.videoInfo {
                        Text(videoInfo)
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }

                    if let audioInfo = stream.audioInfo, !audioInfo.isEmpty {
                        Text(audioInfo.joined(separator: ", "))
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }

                    if let bitrate = stream.bitrate {
                        Text(bitrate)
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                }
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color.gray.opacity(0.1))
            )
        }
        .buttonStyle(.plain)
    }
}
