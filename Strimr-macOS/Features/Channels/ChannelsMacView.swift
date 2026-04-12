import SwiftUI

@MainActor
struct ChannelsMacView: View {
    @Environment(ChannelProgramManager.self) private var channelManager
    @EnvironmentObject private var coordinator: MainCoordinator
    @State private var viewModel: ChannelsViewModel?

    private var vm: ChannelsViewModel {
        viewModel ?? ChannelsViewModel(manager: channelManager)
    }

    private let columns = [
        GridItem(.adaptive(minimum: 120, maximum: 180), spacing: 16),
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                if vm.isLoading, !vm.hasContent {
                    ProgressView()
                        .frame(maxWidth: .infinity, minHeight: 200)
                } else if let error = vm.errorMessage, !vm.hasContent {
                    ContentUnavailableView(
                        String(localized: "channels.error.title"),
                        systemImage: "exclamationmark.triangle.fill",
                        description: Text(error)
                    )
                } else if !vm.hasContent {
                    ContentUnavailableView(
                        String(localized: "channels.empty.title"),
                        systemImage: "tv",
                        description: Text("channels.empty.description")
                    )
                } else {
                    LazyVGrid(columns: columns, spacing: 16) {
                        ForEach(vm.channels) { channel in
                            channelCard(channel)
                        }
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 20)
        }
        .navigationTitle("tabs.channels")
        .onAppear {
            if viewModel == nil {
                viewModel = ChannelsViewModel(manager: channelManager)
            }
            viewModel?.reloadIfProviderChanged()
        }
        .task { await viewModel?.load() }
        .refreshable { await viewModel?.reload() }
        .overlay {
            if vm.isResolvingStream {
                ProgressView()
                    .controlSize(.large)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(.ultraThinMaterial)
            }
        }
    }

    private func channelCard(_ channel: Media) -> some View {
        Button {
            Task { await playChannel(channel) }
        } label: {
            VStack(spacing: 8) {
                channelImage(channel)
                    .frame(width: 100, height: 100)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .strokeBorder(Color.primary.opacity(0.08))
                    }

                Text(channel.title)
                    .font(.caption)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private func channelImage(_ channel: Media) -> some View {
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
        RoundedRectangle(cornerRadius: 12, style: .continuous)
            .fill(Color.gray.opacity(0.15))
            .overlay {
                Image(systemName: "tv")
                    .font(.title2)
                    .foregroundStyle(.secondary)
            }
    }

    private func playChannel(_ channel: Media) async {
        guard let url = await viewModel?.resolveStreamURL(for: channel) else { return }
        coordinator.showPlayer(streamURL: url, media: channel)
    }
}
