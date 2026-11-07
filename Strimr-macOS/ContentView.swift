import SwiftUI

struct ContentView: View {
    @Environment(SettingsManager.self) private var settingsManager

    var body: some View {
        ZStack {
            Color("Background").ignoresSafeArea()
            MainTabMacView(
                homeViewModel: HomeViewModel(),
                moviesViewModel: CatalogViewModel(kind: .movies, settingsManager: settingsManager),
                showsViewModel: CatalogViewModel(kind: .shows, settingsManager: settingsManager),
            )
        }
    }
}
