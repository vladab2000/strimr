import SwiftUI

@main
struct StrimrApp: App {
    @State private var settingsManager: SettingsManager
    @State private var mediaFocusModel: MediaFocusModel

    init() {
        _settingsManager = State(initialValue: SettingsManager())
        _mediaFocusModel = State(initialValue: MediaFocusModel())
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(settingsManager)
                .environment(mediaFocusModel)
                .preferredColorScheme(.dark)
        }
    }
}
