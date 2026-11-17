import SwiftUI

@main
struct StrimrApp: App {
    @State private var settingsManager: SettingsManager
    @State private var mediaFocusModel: MediaFocusModel
    @State private var channelManager: ChannelManager
    @State private var watchHistoryManager = WatchHistoryManager()
    @State private var favoritesManager = FavoritesManager()

    init() {
        let defaults: UserDefaults
        if ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PLAYGROUNDS"] == "1" {
            defaults = UserDefaults(suiteName: "strimr.preview") ?? .init()
        } else {
            defaults = .standard
        }
        let settings = SettingsManager(userDefaults: defaults)
        _settingsManager = State(initialValue: settings)
        _mediaFocusModel = State(initialValue: MediaFocusModel())
        _channelManager = State(initialValue: ChannelManager(settingsManager: settings))
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(settingsManager)
                .environment(mediaFocusModel)
                .environment(channelManager)
                .environment(watchHistoryManager)
                .environment(favoritesManager)
                .preferredColorScheme(.dark)
                .task { await watchHistoryManager.load() }
                .task { await favoritesManager.load() }
        }
    }
}

//TODO: V HomeViewModel by mohlo být načítání MediaCarusel dynamicky, dle konfigurace
//TODO: Výběr kategorií kanálů
