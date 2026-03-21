import Observation
import SwiftUI

struct MediaDetailTVView: View {
    @EnvironmentObject private var coordinator: MainCoordinator
    @State var viewModel: MediaDetailViewModel
    @State private var focusedMedia: MediaDisplayItem?
    private let onPlay: (MediaDisplayItem) -> Void
    private let onSelectMedia: (MediaDisplayItem) -> Void

    init(
        viewModel: MediaDetailViewModel,
        onPlay: @escaping (MediaDisplayItem) -> Void = { _ in },
        onSelectMedia: @escaping (MediaDisplayItem) -> Void = { _ in },
    ) {
        _viewModel = State(initialValue: viewModel)
        self.onPlay = onPlay
        self.onSelectMedia = onSelectMedia
    }

    var body: some View {
        @Bindable var bindableViewModel = viewModel

        GeometryReader { proxy in
            ZStack {
                MediaHeroBackgroundView(media: bindableViewModel.media)

                ScrollView {
                    VStack(alignment: .leading, spacing: 32) {
                        MediaHeroContentView(media: focusedMedia ?? bindableViewModel.media)
                            .frame(maxWidth: proxy.size.width * 0.60, alignment: .leading)

                        buttonsRow

                        if bindableViewModel.media.type == .tvshow {
                            seasonsSection
                        }
                    }
                }
            }
        }
        .task {
            await bindableViewModel.loadDetails()
        }
        .onChange(of: coordinator.isPresentingPlayer) { _, isPresenting in
            guard !isPresenting else { return }
            Task { await bindableViewModel.loadDetails() }
        }
        .onAppear {
            if focusedMedia == nil {
                focusedMedia = bindableViewModel.media
            }
        }
        .toolbar(.hidden, for: .tabBar)
    }

    private var playButton: some View {
        Button(action: { onPlay(viewModel.media) }) {
            HStack(spacing: 12) {
                Image(systemName: "play.fill")
                    .font(.title3.weight(.semibold))
                VStack(alignment: .leading, spacing: 2) {
                    Text("common.actions.play")
                        .font(.headline)
                        .fontWeight(.semibold)
                }
            }
            .frame(maxWidth: 520, alignment: .leading)
        }
        .buttonStyle(.borderedProminent)
        .controlSize(.large)
        .tint(.brandSecondary)
        .foregroundStyle(.brandSecondaryForeground)
    }

    private var buttonsRow: some View {
        HStack(spacing: 16) {
            playButton
        }
    }

    private var seasonsSection: some View {
        VStack(alignment: .leading, spacing: 20) {
            seasonSelector
            episodesRow
        }
    }

    @ViewBuilder
    private var seasonSelector: some View {
        if viewModel.isLoadingSeasons || viewModel.isLoading, viewModel.seasons.isEmpty {
            HStack(spacing: 8) {
                ProgressView()
                Text("media.detail.loadingSeasons")
                    .foregroundStyle(.secondary)
            }
        } else if viewModel.seasons.isEmpty {
            Text("media.detail.noSeasons")
                .foregroundStyle(.secondary)
        } else {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 16) {
                    ForEach(viewModel.seasons) { season in
                        SeasonPillButton(
                            title: season.title,
                            isSelected: season.id == viewModel.selectedSeasonId,
                            onSelect: {
                                Task { await viewModel.selectSeason(id: season.id) }
                            },
                            onFocus: {
                                focusedMedia = season
                            },
                            onBlur: {
                                if focusedMedia?.id == season.id {
                                    focusedMedia = nil
                                }
                            },
                        )
                    }
                }
                .padding(.vertical, 4)
            }
            .focusSection()
        }
    }

    @ViewBuilder
    private var episodesRow: some View {
        if viewModel.isLoadingEpisodes, viewModel.episodes.isEmpty {
            ProgressView("media.detail.loadingEpisodes")
        } else if viewModel.episodes.isEmpty {
            Text("media.detail.noEpisodes")
                .foregroundStyle(.secondary)
        } else {
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(alignment: .top, spacing: 36) {
                    ForEach(viewModel.episodes) { episode in
                        EpisodeArtworkCard(
                            episode: episode,
                            width: 460,
                            onPlay: {
                                onPlay(episode)
                            },
                            onFocus: {
                                focusedMedia = episode
                            },
                        )
                    }
                }
                .padding(.vertical, 12)
                .padding(.vertical, 4)
            }
            .focusSection()
        }
    }
}

private struct SeasonPillButton: View {
    let title: String
    let isSelected: Bool
    let onSelect: () -> Void
    let onFocus: () -> Void
    let onBlur: () -> Void

    @FocusState private var isFocused: Bool

    var body: some View {
        VStack {
            Text(title)
                .font(.headline)
                .fontWeight(.semibold)
                .padding(.horizontal, 18)
                .padding(.vertical, 10)
                .foregroundStyle(.brandSecondary)
                .background(
                    Capsule(style: .continuous)
                        .fill(isSelected ? Color.brandSecondary.opacity(0.5) : Color.gray.opacity(0.12)),
                )
                .overlay {
                    Capsule(style: .continuous)
                        .stroke(
                            isFocused ? Color.brandSecondary : Color.gray.opacity(0.25),
                            lineWidth: isFocused ? 3 : 1,
                        )
                }
        }
        .focusable()
        .focused($isFocused)
        .animation(.easeOut(duration: 0.15), value: isFocused)
        .onChange(of: isFocused) { _, focused in
            if focused {
                onFocus()
            } else {
                onBlur()
            }
        }
        .onPlayPauseCommand(perform: onSelect)
        .onTapGesture(perform: onSelect)
    }
}

private struct EpisodeArtworkCard: View {
    let episode: MediaDisplayItem
    let width: CGFloat
    let onPlay: () -> Void
    let onFocus: () -> Void

    @FocusState private var isFocused: Bool

    private let aspectRatio: CGFloat = 16 / 9

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ZStack(alignment: .topLeading) {
                AsyncImage(url: episode.thumbURL) { phase in
                    switch phase {
                    case let .success(image):
                        image
                            .resizable()
                            .scaledToFit()
                    case .empty:
                        Color.gray.opacity(0.15)
                    case .failure:
                        Color.gray.opacity(0.15)
                    @unknown default:
                        Color.gray.opacity(0.15)
                    }
                }
                .frame(width: width)
                .aspectRatio(aspectRatio, contentMode: .fit)
                .background(Color.black)

                if let duration = episode.duration {
                    let minutes = duration / 60
                    Label {
                        Text("\(minutes)m")
                            .font(.caption2)
                            .fontWeight(.semibold)
                    } icon: {
                        Image(systemName: "clock")
                            .font(.caption2)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(.ultraThinMaterial, in: Capsule())
                    .padding(10)
                }
            }
            .frame(width: width)
            .clipped()
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay {
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(.white.opacity(0.05))
            }

            Text(episode.title)
                .font(.callout.weight(.semibold))
                .lineLimit(2)

            if let summary = episode.summary {
                Text(summary)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(3)
            }
        }
        .frame(width: width)
        .focusable()
        .focused($isFocused)
        .scaleEffect(isFocused ? 1.12 : 1)
        .animation(.easeOut(duration: 0.15), value: isFocused)
        .onChange(of: isFocused) { _, focused in
            if focused {
                onFocus()
            }
        }
        .onPlayPauseCommand(perform: onPlay)
        .onTapGesture(perform: onPlay)
    }
}
