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

//TODO: Pamatovat si i HERO, pro jednotlivé stránky (když se mezi nimi přepíná zůstáva HERO z předchozí) - toto chování je způsobeno MediaFocusModel (globální pamatování Media přes celou aplikaci, asi by mělo být na stránku)
//TODO: lokalizace
//TODO: V HomeViewModel by mohlo být načítání MediaCarusel dynamicky, dle konfigurace
//TODO: Výběr kategorií kanálů

//TODO: Věci nutné upravit i na Serveru
//TODO: podpora stránkování - nový typ v Media, nebo jen url, která slouží k dočtění další/předchozí stránky


//TODO: Po probuzení a změně data je potřeba vylít programy, epg má totiž startovní osu nastavenou na Dnes - 7 dní, ne na konkrétní datum, aby fungovalo i zítra
	

