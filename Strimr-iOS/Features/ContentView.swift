import SwiftUI

struct ContentView: View {
    @Environment(SettingsManager.self) private var settingsManager

    var body: some View {
        ZStack {
            Color("Background").ignoresSafeArea()
            MainTabView(homeViewModel: HomeViewModel(settingsManager: settingsManager))
        }
    }
}
