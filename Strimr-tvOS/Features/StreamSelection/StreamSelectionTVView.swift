import SwiftUI

struct StreamSelectionTVView: View {
    @EnvironmentObject private var coordinator: MainCoordinator
    @State var viewModel: StreamSelectionViewModel
    private let onPlay: (Stream, Double?) -> Void
    
    init(
        viewModel: StreamSelectionViewModel,
        onPlay: @escaping (Stream, Double?) -> Void = { _, _ in }
    ) {
        _viewModel =  State(initialValue: viewModel)
        self.onPlay = onPlay
    }

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                MediaHeroBackgroundView(media: viewModel.media)

                ScrollView {
                    VStack(alignment: .leading, spacing: 32) {
                        MediaHeroContentView(media: viewModel.media)
                            .frame(maxWidth: proxy.size.width * 0.60, alignment: .leading)

                        streamsSection
                    }
                }
            }
        }
        .toolbar(.hidden, for: .tabBar)
    }

    // MARK: - Streams

    @ViewBuilder
    private var streamsSection: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("streamSelection.title")
                .font(.title3.weight(.semibold))
                .focusable()

            if viewModel.streams.isEmpty {
                Text("streamSelection.noStreams")
                    .foregroundStyle(.secondary)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    LazyHStack(spacing: 36) {
                        ForEach(viewModel.streams, id: \.id) { stream in
                            StreamCard(
                                stream: stream,
                                isResolving: viewModel.isResolvingStream,
                                onSelect: {
                                    onPlay(stream, nil)
                                }
                            )
                        }
                    }
                    .padding(.vertical, 12)
                }
                .focusSection()
            }
        }

        if viewModel.isResolvingStream {
            ProgressView("streamSelection.resolving")
        }
    }
}

// MARK: - Stream Card

private struct StreamCard: View {
    let stream: Stream
    let isResolving: Bool
    let onSelect: () -> Void

    @FocusState private var isFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let quality = stream.quality {
                Text(quality)
                    .font(.title3.weight(.bold))
            }

            VStack(alignment: .leading, spacing: 6) {
                if let langs = stream.langString {
                    Label(langs, systemImage: "globe")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .foregroundColor(stream.isCZLang ? .green : .primary)
                        .bold(stream.isCZLang)
                }

                if let size = stream.size {
                    Label(size, systemImage: "doc.fill")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }

/*                if let videoInfo = stream.videoInfo {
                    Label(videoInfo, systemImage: "film")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }

                if let audioInfo = stream.audioInfo, !audioInfo.isEmpty {
                    Label(audioInfo.joined(separator: ", "), systemImage: "speaker.wave.2")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }

                if let size = stream.bitrate {
                    Label(bitrate, systemImage: "speedometer")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }*/
            }
        }
        .frame(width: 320, alignment: .leading)
        .padding(24)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(isFocused ? Color.brandSecondary.opacity(0.3) : Color.gray.opacity(0.12))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(isFocused ? Color.brandSecondary : Color.clear, lineWidth: 3)
        )
        .scaleEffect(isFocused ? 1.05 : 1.0)
        .animation(.easeOut(duration: 0.15), value: isFocused)
        .focusable()
        .focused($isFocused)
        .onPlayPauseCommand(perform: onSelect)
        .onTapGesture(perform: onSelect)
    }
}


