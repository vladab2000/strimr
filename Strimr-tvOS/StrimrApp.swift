import SwiftUI

@main
struct StrimrApp: App {
    @State private var settingsManager: SettingsManager
    @State private var mediaFocusModel: MediaFocusModel
    @State private var watchHistoryManager = WatchHistoryManager()

    init() {
        let defaults: UserDefaults
        if ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PLAYGROUNDS"] == "1" {
            defaults = UserDefaults(suiteName: "strimr.preview") ?? .init()
        } else {
            defaults = .standard
        }
        _settingsManager = State(initialValue: SettingsManager(userDefaults: defaults))
        _mediaFocusModel = State(initialValue: MediaFocusModel())
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(settingsManager)
                .environment(mediaFocusModel)
                .environment(watchHistoryManager)
                .preferredColorScheme(.dark)
                .task { await watchHistoryManager.load() }
        }
    }
}
