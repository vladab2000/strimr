import SwiftUI

@MainActor
struct SettingsMacView: View {
    @Environment(SettingsManager.self) private var settingsManager

    var body: some View {
        let viewModel = SettingsViewModel(settingsManager: settingsManager)
        List {
            Section("Hledání") {
                Picker("Poskytovatel pro hledání", selection: viewModel.contentSourceBinding) {
                    ForEach(ContentSource.allCases) { source in
                        Text(source.displayName).tag(source)
                    }
                }
            }

            Section("settings.tv.section") {
                Picker("settings.tv.provider", selection: viewModel.tvProviderBinding) {
                    ForEach(ProviderType.selectableCases) { provider in
                        Text(provider.displayName).tag(provider)
                    }
                }
            }

            Section {
                NavigationLink("settings.playback.title") {
                    SettingsPlaybackMacView()
                }
            }
        }
        .navigationTitle("settings.title")
    }
}
