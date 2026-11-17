import SwiftUI

@MainActor
struct SettingsView: View {
    @Environment(SettingsManager.self) private var settingsManager

    var body: some View {
        List {
            Section {
                NavigationLink("settings.tv.section") {
                    SettingsTelevisionView()
                }

                NavigationLink("settings.playback.title") {
                    SettingsPlaybackView()
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("settings.title")
    }
}
