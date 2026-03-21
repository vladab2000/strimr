import SwiftUI

enum MoreTVRoute: Hashable {
    case settings
}

@MainActor
struct MoreTVView: View {

    var body: some View {
        ZStack {
            Color("Background").ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    Text("tabs.more")
                        .font(.largeTitle.bold())

                    NavigationLink(value: MoreTVRoute.settings) {
                        Label("settings.title", systemImage: "gearshape.fill")
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding()
                    }
                    .buttonStyle(.borderedProminent)

                    Spacer()
                }
                .padding(48)
            }
        }
    }
}
