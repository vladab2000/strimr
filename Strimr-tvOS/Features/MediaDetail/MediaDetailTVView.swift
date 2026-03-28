import Observation
import SwiftUI

struct MediaDetailTVView: View {
    @EnvironmentObject private var coordinator: MainCoordinator
    @Environment(FavoritesManager.self) private var favoritesManager
    @State var viewModel: MediaDetailViewModel
    @State private var focusedMedia: Media?
    private let onSelectMedia: (Media) -> Void

    init(
        viewModel: MediaDetailViewModel,
        onSelectMedia: @escaping (Media) -> Void = { _ in }
    ) {
        _viewModel = State(initialValue: viewModel)
        self.onSelectMedia = onSelectMedia
    }

    var body: some View {
        @Bindable var bindableViewModel = viewModel

        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                MediaHeroBackgroundView(media: bindableViewModel.media)

                ScrollView {
                    VStack(alignment: .leading, spacing: 32) {
                        MediaHeroContentView(media: focusedMedia ?? bindableViewModel.media)
                            .frame(maxWidth: proxy.size.width * 0.60, alignment: .leading)

                        if bindableViewModel.media.itemType == .movie || bindableViewModel.media.itemType == .tvshow {
                            favoriteButton
                        }

                        if bindableViewModel.media.itemType == .tvshow {
                            seasonsSection
                        }
                        
/*                        CastSection(viewModel: bindableViewModel)
                        RelatedHubsSection(viewModel: bindableViewModel, onSelectMedia: onSelectMedia)
*/
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
/*        .onChange(of: bindableViewModel.media) { oldValue, newValue in
            if focusedMedia == nil || focusedMedia?.id == oldValue.id {
                focusedMedia = newValue.mediaItem
            }
        }*/
        .toolbar(.hidden, for: .tabBar)
    }

    // MARK: - Favorite Button

    private var favoriteButton: some View {
        let isFav = favoritesManager.isFavorite(viewModel.media)
        return Button {
            Task {
                if isFav {
                    await favoritesManager.remove(viewModel.media)
                } else {
                    await favoritesManager.add(viewModel.media)
                }
            }
        } label: {
            Label(
                isFav
                    ? String(localized: "library.removeFromLibrary")
                    : String(localized: "library.addToLibrary"),
                systemImage: isFav ? "heart.fill" : "heart"
            )
            .font(.headline)
            .foregroundStyle(isFav ? .red : .brandSecondary)
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(
                Capsule(style: .continuous)
                    .fill((isFav ? Color.red : Color.brandSecondary).opacity(0.15))
            )
        }
        .buttonStyle(.plain)
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
                            title: season.seasonTitle ?? season.title,
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
                            imageURL: episode.thumbURL,
                            runtime: viewModel.runtimeText,
                            progress: viewModel.progressFraction(for: episode),
                            width: 460,
                            onPlay: {
                                onSelectMedia(episode)
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
    let episode: Media
    let imageURL: URL?
    let runtime: String?
    let progress: Double?
    let width: CGFloat
    let onPlay: () -> Void
    let onFocus: () -> Void

    @FocusState private var isFocused: Bool

    private let aspectRatio: CGFloat = 16 / 9

    var body: some View {
        EpisodeArtworkView(
            episode: episode,
            imageURL: imageURL,
            width: width,
            runtime: runtime,
            progress: progress,
        )
        .overlay {
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(Color.brandPrimary, lineWidth: isFocused ? 4 : 0)
        }
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
