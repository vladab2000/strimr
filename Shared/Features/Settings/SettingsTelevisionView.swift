import SwiftUI

/// Nastavení → Televize: poskytovatel živého vysílání a archivu
@MainActor
struct SettingsTelevisionView: View {
    @Environment(SettingsManager.self) private var settingsManager

    private var viewModel: SettingsViewModel {
        SettingsViewModel(settingsManager: settingsManager)
    }

    var body: some View {
        List {
            Section {
                Picker("settings.tv.provider", selection: viewModel.tvProviderBinding) {
                    ForEach(ProviderType.selectableCases) { provider in
                        Text(provider.displayName).tag(provider)
                    }
                }
                #if !os(macOS)
                .pickerStyle(.navigationLink)
                #endif
            }
        }
        .navigationTitle("settings.tv.section")
    }
}
