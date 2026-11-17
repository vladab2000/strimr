import SwiftUI

struct MediaCarousel: View {
    enum Layout { case portrait, landscape }

    let layout: Layout
    let items: [Media]
    let showsLabels: Bool
    let onSelectMedia: (Media) -> Void
    /// Volá se, když se při rolování objeví některá z posledních dlaždic (dočtení další stránky)
    var onReachEnd: (() -> Void)? = nil
    var isLoadingMore = false

    #if os(tvOS)
    @FocusState private var focusedID: Media.ID?
    @State private var lastFocusedID: Media.ID?
        @Namespace private var carouselScope
    #endif

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            LazyHStack(alignment: .top, spacing: spacing(for: layout)) {
                ForEach(items) { item in
                    card(for: item)
                    #if os(tvOS)
                        .focused($focusedID, equals: item.id)
                        .id(item.id)
                    #endif
                        .onAppear {
                            reachEndIfNeeded(item)
                        }
                }

                if isLoadingMore {
                    ProgressView()
                        .frame(maxHeight: .infinity)
                        .padding(.horizontal, 24)
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
        .onAppear() {
            if lastFocusedID == nil {
                lastFocusedID = items.first?.id
            }
        }
        .focusScope(carouselScope)
//        .defaultFocus($focusedID, lastFocusedID ?? items.first?.id)
        .onChange(of: focusedID) { oldValue, newValue in
            if oldValue == nil, let newValue, let saved = lastFocusedID, newValue != saved,
               items.contains(where: { $0.id == saved }) {
                focusedID = saved
            }
            if let newValue {
                lastFocusedID = newValue
            }
        }
        #endif
    }

    private func reachEndIfNeeded(_ item: Media) {
        guard let onReachEnd,
              let index = items.firstIndex(where: { $0.id == item.id }),
              index >= items.count - Self.reachEndThreshold else { return }
        onReachEnd()
    }

    private static let reachEndThreshold = 6

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
