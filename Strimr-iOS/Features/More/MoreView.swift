import SwiftUI

@MainActor
struct MoreView: View {
    var body: some View {
        List {
            Section {
                NavigationLink("settings.playback.title") {
                    SettingsPlaybackView()
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("tabs.more")
    }
}
