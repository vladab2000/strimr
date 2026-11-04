import SwiftUI

struct ContentView: View {
    @Environment(SettingsManager.self) private var settingsManager

    init() {
        ErrorReporter.start()
    }

    var body: some View {
        ZStack {
            Color("Background").ignoresSafeArea()

            MainTabTVView(homeViewModel: HomeViewModel(settingsManager: settingsManager))
        }
    }
}
