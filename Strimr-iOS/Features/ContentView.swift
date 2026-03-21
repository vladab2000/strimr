import SwiftUI

struct ContentView: View {
    var body: some View {
        ZStack {
            Color("Background").ignoresSafeArea()
            MainTabView(homeViewModel: HomeViewModel())
        }
    }
}
