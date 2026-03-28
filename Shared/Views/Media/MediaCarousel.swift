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
        @Environment(MediaFocusModel.self) private var focusModel
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
            print("[MediaCarousel:\(layout)] onAppear — selectedID=\(String(describing: selectedID)), focusedID=\(String(describing: focusedID)), items=[\(items.map { "'\($0.primaryLabel)'" }.joined(separator: ", "))]")
            if focusedID == nil {
                let validID = selectedID.flatMap { id in items.first(where: { $0.id == id })?.id }
                focusedID = validID ?? items.first?.id
                print("[MediaCarousel:\(layout)] onAppear — setting focusedID=\(String(describing: focusedID)) (selectedID was valid: \(validID != nil))")
            }
        }
        .onChange(of: focusModel.focusedMedia?.id) { _, newID in
            let belongs = newID.map { id in items.contains(where: { $0.id == id }) } ?? false
            print("[MediaCarousel:\(layout)] focusModel.focusedMedia → '\(focusModel.focusedMedia?.primaryLabel ?? "nil")' (id: \(newID ?? "nil")) — belongs=\(belongs), selectedID=\(String(describing: selectedID))")
            if let newID, belongs {
                selectedID = newID
                print("[MediaCarousel:\(layout)] selectedID updated to \(newID)")
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
