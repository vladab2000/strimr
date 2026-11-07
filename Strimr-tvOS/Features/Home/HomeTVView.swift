import SwiftUI

/// Domovská stránka: náhled a popis vybrané dlaždice + pokračovat ve sledování
@MainActor
struct HomeTVView: View {
    @Environment(MediaFocusModel.self) private var focusModel
    @Environment(WatchHistoryManager.self) private var watchHistoryManager
    @Environment(\.scenePhase) private var scenePhase

    @State var viewModel: HomeViewModel
    let onSelectMedia: (Media) -> Void

    init(
        viewModel: HomeViewModel,
        onSelectMedia: @escaping (Media) -> Void = { _ in },
    ) {
        _viewModel = State(initialValue: viewModel)
        self.onSelectMedia = onSelectMedia
    }

    var body: some View {
        MediaHeroPageTVView(heroMedia: viewModel.continueWatching.first, pageMedia: viewModel.continueWatching) {
            ScrollView {
                VStack(alignment: .leading, spacing: 32) {
                    if !viewModel.continueWatching.isEmpty {
                        MediaHubSection(title: String(localized: "home.continueWatching")) {
                            MediaCarousel(
                                layout: .landscape,
                                items: viewModel.continueWatching,
                                showsLabels: false,
                                onSelectMedia: onSelectMedia,
                            )
                        }
                    }
                }
                .padding(.trailing, 24)
            }
        } emptyState: {
            if viewModel.isLoading {
                ProgressView("home.loading")
            } else {
                Text("common.empty.nothingToShow")
                    .foregroundStyle(.secondary)
            }
        }
        .task {
            viewModel.watchHistoryManager = watchHistoryManager
            await viewModel.load()
        }
        .onAppear {
            viewModel.refreshWatchStatus()
        }
        .onChange(of: watchHistoryManager.changeCounter) {
            viewModel.refreshWatchStatus()
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active {
                Task { await viewModel.reload() }
            }
        }
    }
}

/// Stránka s náhledem a popisem vybrané dlaždice nahoře (pozadí přes celou obrazovku) a obsahem ve spodních 60 %
struct MediaHeroPageTVView<Content: View, EmptyState: View>: View {
    @Environment(MediaFocusModel.self) private var focusModel

    let heroMedia: Media?
    /// Dlaždice této stránky — náhled patří fokusované dlaždici, jen pokud je odsud (fokus mohl zůstat z jiné záložky)
    let pageMedia: [Media]
    @ViewBuilder let content: () -> Content
    @ViewBuilder let emptyState: () -> EmptyState

    init(
        heroMedia: Media?,
        pageMedia: [Media],
        @ViewBuilder content: @escaping () -> Content,
        @ViewBuilder emptyState: @escaping () -> EmptyState,
    ) {
        self.heroMedia = heroMedia
        self.pageMedia = pageMedia
        self.content = content
        self.emptyState = emptyState
    }

    var body: some View {
        ZStack {
            Color("Background")
                .ignoresSafeArea()

            if let heroMedia {
                let shown = focusedOnPage ?? heroMedia
                GeometryReader { proxy in
                    ZStack(alignment: .bottom) {
                        ZStack(alignment: .topLeading) {
                            MediaHeroBackgroundView(media: shown)
                            MediaHeroContentView(media: shown)
                                .frame(maxWidth: proxy.size.width * 0.60, maxHeight: .infinity, alignment: .topLeading)
                        }

                        content()
                            .frame(height: proxy.size.height * 0.60)
                    }
                }
            } else {
                VStack(spacing: 16) {
                    emptyState()
                }
            }
        }
        .onAppear {
            guard let heroMedia, focusedOnPage == nil else { return }
            focusModel.focusedMedia = heroMedia
        }
        .onChange(of: heroMedia?.id) { _, _ in
            guard let heroMedia, focusedOnPage == nil else { return }
            focusModel.focusedMedia = heroMedia
        }
    }

    private var focusedOnPage: Media? {
        guard let focused = focusModel.focusedMedia,
              pageMedia.contains(where: { $0.id == focused.id }) else { return nil }
        return focused
    }
}
