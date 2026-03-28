import SwiftUI

struct MediaCarousel: View {
    enum Layout { case portrait, landscape }

    let layout: Layout
    let items: [Media]
    let showsLabels: Bool
    let onSelectMedia: (Media) -> Void

    #if os(tvOS)
        @Binding var selectedID: Media.ID?
        @FocusState private var focusedID: Media.ID?
    #endif

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            LazyHStack(alignment: .top, spacing: spacing(for: layout)) {
                ForEach(items, id: \.id) { item in
                    card(for: item)
                    #if os(tvOS)
                        .focused($focusedID, equals: item.id)
                    #endif
                }
            }
            #if os(tvOS)
            .padding(.vertical, 18)
            .padding(.horizontal, 12)
            #else
            .padding(.horizontal, 2)
            #endif
        }
        #if os(tvOS)
        .focusSection()
        .onAppear {
            if focusedID == nil {
                focusedID = selectedID ?? items.first?.id
            }
        }
        .onChange(of: focusedID) { _, newValue in
            if let newValue {
                selectedID = newValue
            }
        }
        #endif
    }

    @ViewBuilder
    private func card(for media: Media) -> some View {
        switch layout {
        case .portrait:
            PortraitMediaCard(media: media, showsLabels: showsLabels) {
                onSelectMedia(media)
            }
        case .landscape:
            LandscapeMediaCard(media: media, showsLabels: showsLabels) {
                onSelectMedia(media)
            }
        }
    }

    private func spacing(for layout: Layout) -> CGFloat {
        switch layout {
        case .portrait:
            #if os(tvOS)
                28
            #else
                12
            #endif
        case .landscape:
            #if os(tvOS)
                32
            #else
                16
            #endif
        }
    }
}
