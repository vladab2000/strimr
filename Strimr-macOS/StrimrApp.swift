import SwiftUI

@main
struct StrimrApp: App {
    @State private var settingsManager = SettingsManager()
    @State private var watchHistoryManager = WatchHistoryManager()
    @State private var favoritesManager = FavoritesManager()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(settingsManager)
                .environment(watchHistoryManager)
                .environment(favoritesManager)
                .preferredColorScheme(.dark)
                .task { await watchHistoryManager.load() }
                .task { await favoritesManager.load() }
        }
        .windowStyle(.hiddenTitleBar)
        .defaultSize(width: 1200, height: 800)
    }
}
