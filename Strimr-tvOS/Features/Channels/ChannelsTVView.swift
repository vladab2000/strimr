import SwiftUI

@MainActor
struct ChannelsTVView: View {
    @Environment(MediaFocusModel.self) private var focusModel
    @Environment(ChannelProgramManager.self) private var channelManager
    @EnvironmentObject private var coordinator: MainCoordinator
    @State private var viewModel: ChannelsViewModel?

    private var vm: ChannelsViewModel {
        viewModel ?? ChannelsViewModel(manager: channelManager)
    }

    var body: some View {
        ZStack {
            Color("Background")
                .ignoresSafeArea()

            if let heroMedia {
                GeometryReader { proxy in
                    ZStack(alignment: .bottom) {
                        // Hero area
                        ZStack(alignment: .topLeading) {
                            MediaHeroBackgroundView(media: focusModel.focusedMedia ?? heroMedia)
                            MediaHeroContentView(media: focusModel.focusedMedia ?? heroMedia)
                                .frame(maxWidth: proxy.size.width * 0.60, alignment: .topLeading)
                        }
                        
                        // Channel grid
                        channelGrid
                            .frame(height: proxy.size.height * 0.60)
                    }
                }
            } else {
                emptyState
            }
        }
        .onAppear {
            focusModel.focusedMedia = nil
            if viewModel == nil {
                viewModel = ChannelsViewModel(manager: channelManager)
            }
            viewModel?.reloadIfProviderChanged()
        }
        .task { await viewModel?.load() }
        .overlay {
            if vm.isResolvingStream {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(.ultraThinMaterial)
            }
        }
    }

    private var channelGrid: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 32) {
                if vm.hasContent {
                    MediaHubSection(title: String(localized: "channels.title")) {
                        MediaCarousel(
                            layout: .landscape,
                            items: vm.channels,
                            showsLabels: false,
                            onSelectMedia: { channel in
                                Task { await playChannel(channel) }
                            }
                        )
                    }
                }
            }
        }
        .onChange(of: heroMedia?.id) { _, _ in
            updateInitialFocus()
        }
        .onAppear {
            updateInitialFocus()
        }
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            if vm.isLoading, !vm.hasContent {
                ProgressView()
                    .frame(maxWidth: .infinity, minHeight: 200)
            } else if !vm.hasContent {
                ContentUnavailableView(
                    String(localized: "channels.empty.title"),
                    systemImage: "tv",
                    description: Text("channels.empty.description")
                )
            } else {
                Text("common.empty.nothingToShow")
                    .foregroundStyle(.secondary)
            }
        }
    }
    
    private var heroMedia: Media? {
        vm.channels.first
    }

    
    private func updateInitialFocus() {
        guard focusModel.focusedMedia == nil, let heroMedia else { return }
        focusModel.focusedMedia = heroMedia
    }
    
    private func playChannel(_ channel: Media) async {
        guard let url = await viewModel?.resolveStreamURL(for: channel) else { return }
        coordinator.showPlayer(streamURL: url, media: channel)
    }
}

/*private struct ChannelCardTV: View {
    @Environment(MediaFocusModel.self) private var focusModel
    @FocusState private var isFocused: Bool

    let channel: Media
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 12) {
                channelImage
                    .frame(width: 120, height: 120)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))

                Text(channel.title)
                    .font(.callout)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
            }
        }
        .buttonStyle(.card)
        .focused($isFocused)
        .onChange(of: isFocused) { _, focused in
            if focused {
                focusModel.focusedMedia = channel
            }
        }
    }

    @ViewBuilder
    private var channelImage: some View {
        let imageURL = channel.logoURL ?? channel.posterURL ?? channel.thumbURL
        if let imageURL {
            AsyncImage(url: imageURL) { phase in
                if case .success(let image) = phase {
                    image.resizable().scaledToFit()
                } else {
                    channelPlaceholder
                }
            }
        } else {
            channelPlaceholder
        }
    }

    private var channelPlaceholder: some View {
        RoundedRectangle(cornerRadius: 16, style: .continuous)
            .fill(Color.gray.opacity(0.15))
            .overlay {
                Image(systemName: "tv")
                    .font(.largeTitle)
                    .foregroundStyle(.secondary)
            }
    }
}
*/
