import SwiftUI

@MainActor
struct SettingsView: View {
    @Environment(SettingsManager.self) private var settingsManager

    var body: some View {
        let viewModel = SettingsViewModel(settingsManager: settingsManager)
        List {
            Section("settings.tv.section") {
                Picker("settings.tv.provider", selection: viewModel.tvProviderBinding) {
                    ForEach(ProviderType.selectableCases) { provider in
                        Text(provider.displayName).tag(provider)
                    }
                }
            }

            Section {
                NavigationLink("settings.playback.title") {
                    SettingsPlaybackView()
                }
            }
        }
        .navigationTitle("settings.title")
    }
}
