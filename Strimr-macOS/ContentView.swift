import SwiftUI

struct ContentView: View {
    var body: some View {
        ZStack {
            Color("Background").ignoresSafeArea()
            MainTabMacView(homeViewModel: HomeViewModel())
        }
    }
}
