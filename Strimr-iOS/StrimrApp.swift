import SwiftUI

@main
struct StrimrApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate: AppDelegate

    @State private var settingsManager: SettingsManager

    init() {
        _settingsManager = State(initialValue: SettingsManager())
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(settingsManager)
                .preferredColorScheme(.dark)
        }
    }
}
