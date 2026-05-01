import SwiftUI

@MainActor
struct LiveTVTVView: View {
    @Environment(ChannelManager.self) private var channelManager
    @Environment(\.scenePhase) private var scenePhase
    @EnvironmentObject private var coordinator: MainCoordinator

    @State private var viewModel: LiveTVViewModel?

    private var vm: LiveTVViewModel {
        viewModel ?? LiveTVViewModel(manager: channelManager)
    }

    var body: some View {
        ZStack {
            Color("Background")
                .ignoresSafeArea()

            VStack(spacing: 0) {
                if vm.isLoading, !vm.hasContent {
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if !vm.hasContent {
                    ContentUnavailableView(
                        String(localized: "channels.empty.title"),
                        systemImage: "tv",
                        description: Text("channels.empty.description")
                    )
                } else {
                    CombinedEPGView(viewModel: vm)
                        .edgesIgnoringSafeArea(.horizontal)
                        .focusSection()
                }
            }
        }
        .onAppear {
            if viewModel == nil {
                viewModel = LiveTVViewModel(manager: channelManager)
            }
            viewModel?.reloadIfProviderChanged()
        }
        .task {
            await viewModel?.load()
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active {
                viewModel?.refreshIfDayChanged()
            }
        }
        .overlay {
            if vm.isResolvingStream {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(.ultraThinMaterial)
            }
        }
    }
}
