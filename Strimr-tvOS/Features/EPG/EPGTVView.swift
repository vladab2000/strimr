import SwiftUI

@MainActor
struct EPGTVView: View {
    @Environment(MediaFocusModel.self) private var focusModel
    @Environment(ChannelProgramManager.self) private var channelManager
    @EnvironmentObject private var coordinator: MainCoordinator
    @State private var viewModel: EPGViewModel?

    private var vm: EPGViewModel { viewModel ?? EPGViewModel(manager: channelManager) }

    private let channelColumnWidth: CGFloat = 200
    private let rowHeight: CGFloat = 100
    private let pixelsPerMinute: CGFloat = 6.66 // ~400px per hour
    private let spacing: CGFloat = 2

    var body: some View {
        ZStack {
            Color("Background")
                .ignoresSafeArea()

            GeometryReader { proxy in
                ZStack(alignment: .bottom) {
                    ZStack(alignment: .topLeading) {
                        MediaHeroBackgroundView(media: focusModel.focusedMedia ?? Media.empty)
                        MediaHeroContentView(media: focusModel.focusedMedia ?? Media.empty)
                            .frame(maxWidth: proxy.size.width * 0.60, maxHeight: .infinity, alignment: .topLeading)
                    }
                    
                    VStack(spacing: 0) {
                        //            headerBar
                        //                .focusSection()
                        
                        if vm.isLoading, !vm.hasChannels {
                            ProgressView()
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                        } else if !vm.hasChannels {
                            ContentUnavailableView(
                                String(localized: "epg.empty.title"),
                                systemImage: "tv",
                                description: Text("epg.empty.description")
                            )
                        } else {
                            epgGrid
                                .focusSection()
                        }
                    }
                    .onAppear {
                        focusModel.focusedMedia = nil
                        if viewModel == nil {
                            viewModel = EPGViewModel(manager: channelManager)
                        }
                        vm.reloadIfProviderChanged()
                    }
                    .task { await vm.load() }
                    .overlay {
                        if vm.isResolvingStream {
                            ProgressView()
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                                .background(.ultraThinMaterial)
                        }
                    }
                    .frame(height: proxy.size.height * 0.65)
                }
            }
        }
    }

    // MARK: - Header

/*    private var headerBar: some View {
        HStack(spacing: 12) {
            ForEach(vm.availableDates, id: \.self) { date in
                EPGDateButtonTV(
                    date: date,
                    isSelected: Calendar.current.isDate(date, inSameDayAs: vm.selectedDate)
                ) {
                    vm.selectedDate = date
                    vm.dateChanged()
                }
            }
        }
        .padding(.horizontal, 48)
        .padding(.vertical, 16)
    }*/

    private let timeHeaderHeight: CGFloat = 36

    // MARK: - EPG Grid (channels pinned left, programs scroll horizontally, both scroll vertically together)

    private var epgGrid: some View {
        ScrollView(.vertical, showsIndicators: false) {
            HStack(alignment: .top, spacing: 4) {
                // Fixed channel column (does not scroll horizontally)
                VStack(spacing: 0) {
                    Color.clear
                        .frame(width: channelColumnWidth, height: timeHeaderHeight)
                    LazyVStack(alignment: .leading, spacing: spacing) {
                        ForEach(vm.channels) { channel in
                            channelCell(channel)
                                .frame(width: channelColumnWidth, height: rowHeight)
                                .onAppear { vm.loadProgramsIfNeeded(for: channel) }
                        }
                    }
                    .frame(width: channelColumnWidth)
                }

                // Horizontally scrollable program area
                ScrollView(.horizontal, showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 0) {
                        timeHeader
                            .frame(height: timeHeaderHeight)
                        LazyVStack(alignment: .leading, spacing: spacing) {
                            ForEach(vm.channels) { channel in
                                programRow(for: channel)
                                    .frame(height: rowHeight)
                            }
                        }
                    }
                }
            }
        }
        .edgesIgnoringSafeArea(.horizontal)
    }

    // MARK: - Time Header

    private var timeHeader: some View {
        HStack(spacing: 0) {
            ForEach(0..<24, id: \.self) { hour in
                Text(String(format: "%02d:00", hour))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(width: pixelsPerMinute * 60, alignment: .leading)
                    .padding(.leading, 4)
            }
        }
    }

    // MARK: - Channel Cell

    private func channelCell(_ channel: Media) -> some View {
        VStack(spacing: 6) {
            channelLogo(channel)
                .frame(width: 56, height: 56)
                .clipShape(RoundedRectangle(cornerRadius: 8))

            Text(channel.title)
                .font(.caption2)
                .lineLimit(1)
                .foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private func channelLogo(_ channel: Media) -> some View {
        let imageURL = channel.logoURL ?? channel.posterURL ?? channel.thumbURL
        if let imageURL {
            AsyncImage(url: imageURL) { phase in
                if case .success(let image) = phase {
                    image.resizable().scaledToFit()
                } else {
                    Image(systemName: "tv")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                }
            }
        } else {
            Image(systemName: "tv")
                .font(.title3)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Program Row

    private func programRow(for channel: Media) -> some View {
        let programs = vm.programsByChannel[channel.id] ?? []
        let offset = leadingOffset(for: programs)
        return LazyHStack(alignment: .top, spacing: spacing) {
            if offset > 0 {
                Color.clear
                    .frame(width: offset, height: rowHeight)
            }
            ForEach(Array(programs.enumerated()), id: \.element.id) { index, program in
                EPGProgramCellTV(
                    program: program,
                    width: programWidth(program),
                    height: rowHeight - spacing,
                    isNow: isProgramNow(program),
                    onTap: {
                        Task { await handleProgramTap(program: program, channel: channel) }
                    },
                    onLoadNext: index == programs.count - 1 ? { vm.loadNextDay(for: channel) } : nil,
                    onLoadPrevious: index == 0 ? { vm.loadPreviousDay(for: channel) } : nil
                )
            }
        }
        .onAppear { vm.loadProgramsIfNeeded(for: channel) }
    }

    // MARK: - Helpers

    /// Computes the pixel offset from 00:00 of the selected day to the first program's start.
    private func leadingOffset(for programs: [Media]) -> CGFloat {
        guard let firstStart = programs.first?.programStart else { return 0 }
        let dayStart = vm.baseDate
        let offsetMinutes = firstStart.timeIntervalSince(dayStart) / 60
        guard offsetMinutes > 0 else { return 0 }
        return CGFloat(offsetMinutes) * pixelsPerMinute
    }

    private func programWidth(_ program: Media) -> CGFloat {
        guard let start = program.programStart, let end = program.programEnd else {
            return 50
        }
        let durationMinutes = end.timeIntervalSince(start) / 60
        return CGFloat(durationMinutes) * pixelsPerMinute
    }

    private func isProgramNow(_ program: Media) -> Bool {
        guard let start = program.programStart, let end = program.programEnd else { return false }
        let now = Date.now
        return start <= now && now < end
    }

    private func handleProgramTap(program: Media, channel: Media) async {
        let isNow = isProgramNow(program)
        let isPast = (program.programEnd ?? .distantFuture) < Date.now

        if isNow {
            guard let url = await vm.resolveLiveStreamURL(for: channel) else { return }
            coordinator.showPlayer(streamURL: url, media: channel)
        } else if isPast {
            guard let url = await vm.resolveArchiveStreamURL(channelId: channel.id, program: program) else { return }
            coordinator.showPlayer(streamURL: url, media: program)
        }
    }
}

// MARK: - Date Button

/*private struct EPGDateButtonTV: View {
    let date: Date
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(date, format: .dateTime.weekday(.abbreviated).day())
                .font(.callout)
                .fontWeight(isSelected ? .bold : .regular)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
        }
        .buttonStyle(.card)
    }
}*/

// MARK: - Program Cell

private struct EPGProgramCellTV: View {
    @Environment(MediaFocusModel.self) private var focusModel
    @FocusState private var isFocused: Bool

    let program: Media
    let width: CGFloat
    let height: CGFloat
    let isNow: Bool
    let onTap: () -> Void
    var onLoadNext: (() -> Void)?
    var onLoadPrevious: (() -> Void)?

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 4) {
                Text(program.title)
                    .font(.caption)
                    .fontWeight(isNow ? .bold : .regular)
                    .lineLimit(2)

                if let start = program.programStart, let end = program.programEnd {
                    Text("\(start.formatted(.dateTime.hour().minute())) – \(end.formatted(.dateTime.hour().minute()))")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(8)
            .frame(width: width, height: height, alignment: .topLeading)
            .background(
                RoundedRectangle(cornerRadius: 5)
                    .fill(isNow ? Color.brandPrimary.opacity(0.25) : Color.gray.opacity(0.1))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 5)
                    .strokeBorder(isNow ? Color.brandPrimary : Color.clear, lineWidth: 2)
            )
        }
        .buttonStyle(.card)
        .focused($isFocused)
        .onChange(of: isFocused) { _, focused in
            if focused {
                focusModel.focusedMedia = program
            }
        }
        .onMoveCommand { direction in
            if direction == .right, let onLoadNext {
                onLoadNext()
            } else if direction == .left, let onLoadPrevious {
                onLoadPrevious()
            }
        }
    }
}
