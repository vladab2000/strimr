import SwiftUI

struct MediaDetailMacView: View {
    @EnvironmentObject private var coordinator: MainCoordinator
    @Environment(FavoritesManager.self) private var favoritesManager
    @State var viewModel: MediaDetailViewModel
    @State private var isSummaryExpanded = false
    private let heroHeight: CGFloat = 320
    private let onSelectMedia: (Media) -> Void

    init(
        viewModel: MediaDetailViewModel,
        onSelectMedia: @escaping (Media) -> Void = { _ in }
    ) {
        _viewModel = State(initialValue: viewModel)
        self.onSelectMedia = onSelectMedia
    }

    var body: some View {
        @Bindable var vm = viewModel

        ScrollView {
            LazyVStack(alignment: .leading, spacing: 16) {
                heroSection

                VStack(alignment: .leading, spacing: 12) {
                    Text(vm.media.title)
                        .font(.title2.bold())
                        .padding(.horizontal, 16)

                    metadataBadges
                        .padding(.horizontal, 16)

                    if vm.media.itemType == .movie || vm.media.itemType == .tvshow {
                        favoriteButton
                            .padding(.horizontal, 16)
                    }

                    if let summary = vm.media.summary, !summary.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text(summary)
                                .font(.body)
                                .foregroundStyle(.secondary)
                                .lineLimit(isSummaryExpanded ? nil : 4)

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

                if vm.media.itemType == .tvshow {
                    seasonsSection
                }
            }
        }
        .task {
            await vm.loadDetails()
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
                endPoint: .bottom,
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
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(isFav ? .red : .brandPrimary)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(
                Capsule(style: .continuous)
                    .fill((isFav ? Color.red : Color.brandPrimary).opacity(0.15))
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Seasons Section

    @ViewBuilder
    private var seasonsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            if !viewModel.seasons.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(viewModel.seasons) { season in
                            let isSelected = viewModel.selectedSeasonId == season.id
                            Button {
                                Task { await viewModel.selectSeason(id: season.id) }
                            } label: {
                                Text(season.title)
                                    .font(.subheadline.weight(.semibold))
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 8)
                                    .background(
                                        Capsule(style: .continuous)
                                            .fill(isSelected ? Color.brandPrimary.opacity(0.2) : Color.gray.opacity(0.12)),
                                    )
                                    .overlay {
                                        Capsule(style: .continuous)
                                            .stroke(isSelected ? Color.brandPrimary : Color.gray.opacity(0.25), lineWidth: 1)
                                    }
                                    .foregroundStyle(isSelected ? .brandPrimary : .primary)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 16)
                }
            }

            if viewModel.isLoadingEpisodes {
                ProgressView()
                    .frame(maxWidth: .infinity)
                    .padding()
            } else {
                ScrollViewReader { proxy in
                    LazyVStack(alignment: .leading, spacing: 8) {
                        ForEach(viewModel.episodes) { episode in
                            episodeRow(episode)
                                .id(episode.id)
                        }
                    }
                    .padding(.horizontal, 16)
                    .onChange(of: viewModel.episodes.map(\.id)) {
                        if let targetId = viewModel.firstUnwatchedEpisodeId {
                            withAnimation {
                                proxy.scrollTo(targetId, anchor: .top)
                            }
                        }
                    }
                }
            }
        }
    }

    private func episodeRow(_ episode: Media) -> some View {
        Button {
            onSelectMedia(episode)
        } label: {
            HStack(alignment: .top, spacing: 12) {
                if let url = episode.thumbURL {
                    AsyncImage(url: url) { phase in
                        switch phase {
                        case let .success(image):
                            image
                                .resizable()
                                .scaledToFill()
                        default:
                            Color.gray.opacity(0.15)
                        }
                    }
                    .frame(width: 120, height: 68)
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                }

                VStack(alignment: .leading, spacing: 4) {
                    if let secondaryLabel = episode.secondaryLabel {
                        Text(secondaryLabel)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.brandPrimary)
                    }

                    Text(episode.title)
                        .font(.subheadline.weight(.medium))
                        .lineLimit(2)

                    if let summary = episode.summary {
                        Text(summary)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                Image(systemName: "play.circle.fill")
                    .font(.title2)
                    .foregroundStyle(.brandPrimary)
            }
            .padding(.vertical, 8)
        }
        .buttonStyle(.plain)
    }
}
