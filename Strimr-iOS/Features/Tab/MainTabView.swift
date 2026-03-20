import SwiftUI

struct MainTabView: View {
    @StateObject var coordinator = MainCoordinator()
    @State private var homeViewModel = HomeViewModel()

    var body: some View {
        TabView(selection: $coordinator.tab) {
            Tab("tabs.home", systemImage: "house.fill", value: MainCoordinator.Tab.home) {
                NavigationStack(path: coordinator.pathBinding(for: .home)) {
                    HomeView(viewModel: homeViewModel)
                }
            }

            Tab("tabs.search", systemImage: "magnifyingglass", value: MainCoordinator.Tab.search, role: .search) {
                NavigationStack(path: coordinator.pathBinding(for: .search)) {
                    StreamCinemaSearchView()
                }
            }

            Tab("tabs.more", systemImage: "ellipsis", value: MainCoordinator.Tab.more) {
                NavigationStack(path: coordinator.pathBinding(for: .more)) {
                    MoreView()
                }
            }
        }
        .environmentObject(coordinator)
    }
}
