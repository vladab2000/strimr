import SwiftUI

/// Nastavení → Televize → Oblíbené kanály: výběr kanálů od různých poskytovatelů a jejich pořadí.
/// Oblíbené se pak zobrazí jako poskytovatel „Oblíbené“.
@MainActor
struct FavoriteChannelsView: View {
    @Environment(SettingsManager.self) private var settingsManager

    @State private var provider: ProviderType = ProviderType.serverProviders.first ?? .onePlay
    @State private var channels: [Media] = []
    @State private var isLoading = false
    @State private var loadError: String?

    var body: some View {
        List {
            Section {
                if settingsManager.favoriteChannels.isEmpty {
                    Text("settings.favorites.empty")
                        .foregroundStyle(.secondary)
                }
                ForEach(Array(settingsManager.favoriteChannels.enumerated()), id: \.element.id) { index, favorite in
                    favoriteRow(favorite, index: index)
                }
            } header: {
                Text("settings.favorites.selected")
            } footer: {
                Text("settings.favorites.orderHint")
            }

            Section {
                Picker("settings.favorites.provider", selection: $provider) {
                    ForEach(ProviderType.serverProviders) { provider in
                        Text(provider.displayName).tag(provider)
                    }
                }
                #if !os(macOS)
                .pickerStyle(.navigationLink)
                #endif

                if isLoading {
                    ProgressView()
                } else if let loadError {
                    Text(loadError).foregroundStyle(.red)
                }
                ForEach(channels) { channel in
                    channelRow(channel)
                }
            } header: {
                Text("settings.favorites.add")
            }
        }
        .navigationTitle("settings.favorites.title")
        .task(id: provider) { await loadChannels() }
    }

    // MARK: - Rows

    private func favoriteRow(_ favorite: FavoriteChannel, index: Int) -> some View {
        Button {
            settingsManager.removeFavorite(channelId: favorite.channelId)
        } label: {
            HStack {
                Text("\(index + 1).").foregroundStyle(.secondary).monospacedDigit()
                Text(favorite.name)
                Spacer()
                Text(favorite.provider.displayName).foregroundStyle(.secondary)
            }
        }
        .contextMenu {
            Button("settings.favorites.moveUp", systemImage: "arrow.up") {
                settingsManager.moveFavorite(channelId: favorite.channelId, by: -1)
            }
            .disabled(index == 0)
            Button("settings.favorites.moveDown", systemImage: "arrow.down") {
                settingsManager.moveFavorite(channelId: favorite.channelId, by: 1)
            }
            .disabled(index == settingsManager.favoriteChannels.count - 1)
            Button("settings.favorites.remove", systemImage: "star.slash", role: .destructive) {
                settingsManager.removeFavorite(channelId: favorite.channelId)
            }
        }
    }

    private func channelRow(_ channel: Media) -> some View {
        let favorite = settingsManager.favorite(channelId: channel.id)
        let isSelected = favorite?.provider == provider
        return Button {
            settingsManager.toggleFavorite(channel: channel, provider: provider)
        } label: {
            HStack {
                Image(systemName: isSelected ? "star.fill" : "star")
                    .foregroundStyle(isSelected ? .yellow : .secondary)
                Text(channel.name)
                Spacer()
                // V oblíbených od jiného poskytovatele — výběrem se přepne na tohoto
                if let favorite, !isSelected {
                    Text(favorite.provider.displayName).foregroundStyle(.secondary)
                }
            }
        }
    }

    // MARK: - Loading

    private func loadChannels() async {
        isLoading = true
        loadError = nil
        defer { isLoading = false }
        do {
            channels = try await ApiClient.fetchChannels(providerType: provider)
        } catch {
            guard !Task.isCancelled else { return }
            channels = []
            loadError = error.localizedDescription
        }
    }
}
