import SwiftUI

@MainActor
struct LiveTVTVView: View {
    @Environment(ChannelProgramManager.self) private var channelManager
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
                modePicker
                    .focusSection()

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
                    switch vm.mode {
                    case .channels:
                        channelsLayout
                            .focusSection()
                    case .tvGuide:
                        epgLayout
                            .focusSection()
                    }
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
            viewModel?.selectFirstChannelIfNeeded()
        }
        .onChange(of: vm.channels.count) { _, _ in
            viewModel?.selectFirstChannelIfNeeded()
        }
        .onChange(of: vm.selectedChannelPrograms.count) { _, newCount in
            if newCount > 0, vm.selectedProgram == nil {
                viewModel?.selectedProgram = vm.selectedChannel.flatMap { vm.currentProgram(for: $0) }
            }
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

    // MARK: - Mode Picker

    private var modePicker: some View {
        Picker(selection: Bindable(vm).mode) {
            ForEach(LiveTVMode.allCases) { mode in
                Text(String(localized: String.LocalizationValue(mode.titleKey)))
                    .tag(mode)
            }
        } label: {
            EmptyView()
        }
        .pickerStyle(.segmented)
        .frame(maxWidth: 400)
        .padding(.vertical, 16)
    }

    // MARK: - Channels 3-Column Layout

    private var channelsLayout: some View {
        HStack(spacing: 10) {
            // Column 1: Categories
            categoriesColumn
                .frame(width: 220)
                .focusSection()

            Divider()

            // Column 2: Channels
            channelsColumn
                .frame(width: 600)
                .focusSection()

            Divider()

            // Column 3: Program detail
            programDetailColumn
                .focusSection()
        }
    }

    // MARK: - Column 1: Categories

    private var categoriesColumn: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 0) {
                ForEach(vm.categories) { category in
                    CategoryRowTV(
                        title: category.name,
                        isSelected: vm.selectedCategory?.id == category.id
                    ) {
                        viewModel?.selectCategory(category)
                    }
                }
            }
        }
    }

    // MARK: - Column 2: Channels

    private var channelsColumn: some View {
        ScrollView {
            LazyVStack(spacing: 2) {
                ForEach(vm.filteredChannels) { channel in
                    ChannelRowTV(
                        channel: channel,
                        currentProgram: vm.currentProgram(for: channel),
                        isSelected: vm.selectedChannel?.id == channel.id
                    ) {
                        viewModel?.selectChannel(channel)
                    } onPlay: {
                        Task { await playChannel(channel) }
                    }
                    .onAppear {
                        viewModel?.loadProgramsIfNeeded(for: channel)
                    }
                }
            }
        }
    }

    // MARK: - Column 3: Program Detail

    private var programDetailColumn: some View {
        Group {
            if let channel = vm.selectedChannel {
                VStack(spacing: 0) {
                    // Current program image
                    programImageHeader

                    // Programs list
                    ScrollViewReader { proxy in
                        ScrollView {
                            LazyVStack(alignment: .leading, spacing: 2) {
                                ForEach(vm.selectedChannelPrograms) { program in
                                    ProgramRowTV(
                                        program: program,
                                        isNow: isProgramNow(program),
                                        isSelected: vm.selectedProgram?.id == program.id
                                    ) {
                                        viewModel?.selectedProgram = program
                                    } onPlay: {
                                        Task { await handleProgramTap(program: program, channel: channel) }
                                    }
                                    .id(program.id)
                                }
                            }
                        }
                        .onChange(of: vm.selectedProgram?.id) { _, newId in
                            if let newId {
                                proxy.scrollTo(newId, anchor: .center)
                            }
                        }
                    }
                }
            } else {
                ContentUnavailableView(
                    String(localized: "livetv.selectChannel"),
                    systemImage: "tv",
                    description: Text("")
                )
            }
        }
    }

    @ViewBuilder
    private var programImageHeader: some View {
        let displayProgram = vm.selectedProgram
            ?? vm.selectedChannel.flatMap { vm.currentProgram(for: $0) }

        if let imageURL = displayProgram?.thumbURL ?? displayProgram?.posterURL {
            AsyncImage(url: imageURL) { phase in
                if case .success(let image) = phase {
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(maxWidth: .infinity)
                        .frame(height: 480)
                        .clipped()
                } else {
                    Color.gray.opacity(0.1)
                        .frame(height: 480)
                }
            }
        } else {
            Color.gray.opacity(0.1)
                .frame(height: 480)
                .overlay {
                    Image(systemName: "tv")
                        .font(.largeTitle)
                        .foregroundStyle(.secondary)
                }
        }
    }

    // MARK: - EPG Layout

    private let channelColumnWidth: CGFloat = 200
    private let rowHeight: CGFloat = 100
    private let pixelsPerMinute: CGFloat = 6.66
    private let epgSpacing: CGFloat = 2
    private let timeHeaderHeight: CGFloat = 36

    @FocusState var focusedID: String?
    @State private var lastFocusedProgram: Media?
    @State private var lastChannelID: String?
    
    private var epgLayout: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 50) {
                ForEach(vm.channels) { channel in
                    VStack(alignment: .leading, spacing: 10) {
                        Text(channel.name)
                            .font(.headline)
                            .padding(.leading, 80)

                        ScrollView(.horizontal) {
                            LazyHStack(spacing: 20) {
                                ForEach(vm.programsByChannel[channel.id] ?? []) { program in
                                    ProgramCard(program: program)
                                        .id(program.id) // Nutné pro scrollTarget
                                        .focused($focusedID, equals: program.id)
                                        .onAppear {
                                            // Dočítání na konci řádku
                                            if program.id == vm.programsByChannel[channel.id]?.last?.id {
                                                vm.loadMoreData()
                                            }
                                        }
                                }
                            }
                            .padding(.horizontal, 80)
                            .padding(.vertical, 20)
                        }
                        // tvOS 17 feature: Přichytávání na střed/okraj při rychlém skrollování
                        .scrollTargetBehavior(.viewAligned)
                        .scrollIndicators(.hidden)
                    }
                    .focusSection() // Umožňuje přímý vertikální skok mezi řádky
                }
            }
        }
        .onChange(of: focusedID) { newValue in
            handleFocusChange(to: newValue)
        }
    }
        
    private func handleFocusChange(to newID: String?) {
        guard let newID = newID else { return }
        
        // 1. Najdeme aktuální kanál a program
        guard let currentChannel = vm.channels.first(where: { ch in (vm.programsByChannel[ch.id] ?? []).contains { $0.id == newID } }),
              let currentProgram = vm.programsByChannel[currentChannel.id]?.first(where: { $0.id == newID }) else { return }

        // 2. Kontrola vertikálního posunu (změna kanálu)
        if let lastChID = lastChannelID, lastChID != currentChannel.id, let lastProg = lastFocusedProgram {
            // Výpočet cíle podle času středu předchozího programu
            if let idealTargetID = vm.findTargetID(midTime: lastProg.programStart!.addingTimeInterval(lastProg.programEnd!.timeIntervalSince(lastProg.programStart!)), inChannel: currentChannel.id) {
                if idealTargetID != newID {
                    focusedID = idealTargetID
                    return // Přerušíme, abychom neukládali mezistav
                }
            }
        }

        // 3. Uložení stavu pro příští pohyb
        lastFocusedProgram = currentProgram
        lastChannelID = currentChannel.id
    }

    struct ProgramCard: View {
        let program: Media
        @Environment(\.isFocused) var isFocused

        var body: some View {
            Button(action: {
                print("Vybrán pořad: \(program.title)")
            }) {
                VStack(alignment: .leading) {
                    Text(program.title)
                        .font(.body)
                        .bold()
                    Text(program.programStart!, style: .time)
                        .font(.caption2)
                }
                .padding()
                .frame(	maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
                    .background(isFocused ? Color.white : Color.gray.opacity(0.2))
                    .foregroundColor(isFocused ? .black : .white)
            }
            .buttonStyle(.card) // Klíčové pro tvOS vzhled a focus
            .frame(width: CGFloat(program.programEnd!.timeIntervalSince(program.programStart!) / 3600) * 400, height: 180)
        }
    }
    
    private var epgTimeHeader: some View {
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

    private func epgChannelCell(_ channel: Media) -> some View {
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

    private func epgProgramRow(for channel: Media) -> some View {
        let programs = vm.programsByChannel[channel.id] ?? []
        let offset = epgLeadingOffset(for: programs)
        return LazyHStack(alignment: .top, spacing: epgSpacing) {
            if offset > 0 {
                Color.clear
                    .frame(width: offset, height: rowHeight)
            }
            ForEach(Array(programs.enumerated()), id: \.element.id) { index, program in
                EPGProgramCellTV(
                    program: program,
                    width: epgProgramWidth(program),
                    height: rowHeight - epgSpacing,
                    isNow: isProgramNow(program),
                    onTap: {
                        Task { await handleProgramTap(program: program, channel: channel) }
                    },
                    onLoadNext: index == programs.count - 1 ? { viewModel?.loadNextDay(for: channel) } : nil,
                    onLoadPrevious: index == 0 ? { viewModel?.loadPreviousDay(for: channel) } : nil
                )
            }
        }
        .onAppear { viewModel?.loadProgramsIfNeeded(for: channel) }
    }

    // MARK: - Shared Helpers

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

    private func isProgramNow(_ program: Media) -> Bool {
        guard let start = program.programStart, let end = program.programEnd else { return false }
        let now = Date.now
        return start <= now && now < end
    }

    private func epgLeadingOffset(for programs: [Media]) -> CGFloat {
        guard let firstStart = programs.first?.programStart else { return 0 }
        let dayStart = vm.baseDate
        let offsetMinutes = firstStart.timeIntervalSince(dayStart) / 60
        guard offsetMinutes > 0 else { return 0 }
        return CGFloat(offsetMinutes) * pixelsPerMinute
    }

    private func epgProgramWidth(_ program: Media) -> CGFloat {
        guard let start = program.programStart, let end = program.programEnd else {
            return 50
        }
        let durationMinutes = end.timeIntervalSince(start) / 60
        return CGFloat(durationMinutes) * pixelsPerMinute
    }

    private func playChannel(_ channel: Media) async {
        guard let playback = await viewModel?.resolveLivePlayback(for: channel) else { return }
        coordinator.showPlayer(streamURL: ApiClient.playbackURL(sessionId: playback.sessionId), sessionId: playback.sessionId, media: channel, channel: channel)
    }

    private func handleProgramTap(program: Media, channel: Media) async {
        let isNow = isProgramNow(program)
        let isPast = (program.programEnd ?? .distantFuture) < Date.now

        if isNow {
            guard let playback = await viewModel?.resolveArchivePlayback(channelId: channel.id, program: program) else { return }
            coordinator.showPlayer(streamURL: ApiClient.playbackURL(sessionId: playback.sessionId), sessionId: playback.sessionId, media: program, resumePosition: 0.0, channel: channel, program: program)
        } else if isPast {
            guard let playback = await viewModel?.resolveArchivePlayback(channelId: channel.id, program: program) else { return }
            coordinator.showPlayer(streamURL: ApiClient.playbackURL(sessionId: playback.sessionId), sessionId: playback.sessionId, media: program, channel: channel, program: program)
        }
    }
}

// MARK: - Category Row

private struct CategoryRowTV: View {
    let title: String
    let isSelected: Bool
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            HStack {
                Text(title)
                    .font(.callout)
                    .fontWeight(isSelected ? .bold : .regular)
                    .foregroundStyle(isSelected ? .primary : .secondary)
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isSelected ? Color.brandPrimary.opacity(0.2) : Color.clear)
            )
        }
        .buttonStyle(.card)
    }
}

// MARK: - Channel Row

private struct ChannelRowTV: View {
    let channel: Media
    let currentProgram: Media?
    let isSelected: Bool
    let onFocus: () -> Void
    let onPlay: () -> Void

    @FocusState private var isFocused: Bool

    var body: some View {
        Button(action: onPlay) {
            HStack(spacing: 12) {
                // Logo
                channelLogo
                    .frame(width: 56, height: 56)
                    .clipShape(RoundedRectangle(cornerRadius: 8))

                VStack(alignment: .leading, spacing: 4) {
                    // Channel name
                    Text(channel.title)
                        .font(.callout)
                        .fontWeight(.semibold)
                        .lineLimit(1)

                    // Current program name
                    if let program = currentProgram {
                        Text(program.title)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)

                        // Progress bar with times
                        if let start = program.programStart, let end = program.programEnd {
                            programProgress(start: start, end: end)
                        }
                    }
                }

                Spacer(minLength: 0)
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(isSelected ? Color.brandPrimary.opacity(0.15) : Color.gray.opacity(0.08))
            )
        }
        .buttonStyle(.card)
        .focused($isFocused)
        .onChange(of: isFocused) { _, focused in
            if focused {
                onFocus()
            }
        }
    }

    @ViewBuilder
    private var channelLogo: some View {
        let imageURL = channel.logoURL ?? channel.posterURL ?? channel.thumbURL
        if let imageURL {
            AsyncImage(url: imageURL) { phase in
                if case .success(let image) = phase {
                    image.resizable().scaledToFit()
                } else {
                    channelPlaceholder
                }
            }
        } else {
            channelPlaceholder
        }
    }

    private var channelPlaceholder: some View {
        RoundedRectangle(cornerRadius: 8, style: .continuous)
            .fill(Color.gray.opacity(0.15))
            .overlay {
                Image(systemName: "tv")
                    .font(.title3)
                    .foregroundStyle(.secondary)
            }
    }

    private func programProgress(start: Date, end: Date) -> some View {
        let now = Date.now
        let total = end.timeIntervalSince(start)
        let elapsed = now.timeIntervalSince(start)
        let progress = total > 0 ? min(max(elapsed / total, 0), 1) : 0

        return HStack(spacing: 10) {
            Text(start.formatted(.dateTime.hour().minute()))
            ProgressView(value: progress)
                .tint(.brandPrimary)
            Text(end.formatted(.dateTime.hour().minute()))
        }
        .font(.caption2)
        .foregroundStyle(.tertiary)
    }
}

// MARK: - Program Row

private struct ProgramRowTV: View {
    let program: Media
    let isNow: Bool
    let isSelected: Bool
    let onFocus: () -> Void
    let onPlay: () -> Void

    @FocusState private var isFocused: Bool

    var body: some View {
        Button(action: onPlay) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .top, spacing: 12) {
                    // Start time
                    if let start = program.programStart {
                        Text(start.formatted(.dateTime.hour().minute()))
                            .font(.callout)
                            .fontWeight(isNow ? .bold : .regular)
                            .monospacedDigit()
                    }
                    
                    Text(program.title)
                        .font(.callout)
                        .fontWeight(isNow ? .bold : .regular)
                        .lineLimit(1)
                }

                if let summary = program.summary, !summary.isEmpty {
                    Text(summary)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(3)
                }

                Spacer(minLength: 0)
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isNow ? Color.brandPrimary.opacity(0.15) : Color.clear)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .strokeBorder(isNow ? Color.brandPrimary : Color.clear, lineWidth: 1)
            )
        }
        .buttonStyle(.card)
        .focused($isFocused)
        .onChange(of: isFocused) { _, focused in
            if focused {
                onFocus()
            }
        }
    }
}

// MARK: - EPG Program Cell (reused from previous EPG)

private struct EPGProgramCellTV: View {
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
        .onMoveCommand { direction in
            if direction == .right, let onLoadNext {
                onLoadNext()
            } else if direction == .left, let onLoadPrevious {
                onLoadPrevious()
            }
        }
    }
}

