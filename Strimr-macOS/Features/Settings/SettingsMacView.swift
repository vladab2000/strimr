import SwiftUI

@MainActor
struct SettingsMacView: View {
    @Environment(SettingsManager.self) private var settingsManager

    var body: some View {
        List {
            Section {
                NavigationLink("settings.tv.section") {
                    SettingsTelevisionView()
                }

                NavigationLink("settings.playback.title") {
                    SettingsPlaybackMacView()
                }
            }
        }
        .navigationTitle("settings.title")
    }
}
