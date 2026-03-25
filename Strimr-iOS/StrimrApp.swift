import SwiftUI

@main
struct StrimrApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate: AppDelegate

    @State private var settingsManager = SettingsManager()
    @State private var watchHistoryManager = WatchHistoryManager()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(settingsManager)
                .environment(watchHistoryManager)
                .preferredColorScheme(.dark)
                .task { await watchHistoryManager.load() }
        }
    }
}
