import SwiftUI

struct ContentView: View {

    init() {
        ErrorReporter.start()
    }

    var body: some View {
        ZStack {
            Color("Background").ignoresSafeArea()

            MainTabTVView(homeViewModel: HomeViewModel())
        }
    }
}
