import SwiftUI

@MainActor
struct LiveTVMacView: View {
    @Environment(ChannelProgramManager.self) private var channelManager
    @Environment(\.scenePhase) private var scenePhase
    @EnvironmentObject private var coordinator: MainCoordinator
    @State private var viewModel: LiveTVViewModel?

    private var vm: LiveTVViewModel {
        viewModel ?? LiveTVViewModel(manager: channelManager)
    }

    var body: some View {
        VStack(spacing: 0) {
            modePicker
                .padding(.horizontal, 16)
                .padding(.vertical, 8)

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
                case .tvGuide:
                    epgContent
                }
            }
        }
        .navigationTitle("tabs.liveTV")
        .onAppear {
            if viewModel == nil {
                viewModel = LiveTVViewModel(manager: channelManager)
            }
            viewModel?.reloadIfProviderChanged()
        }
        .task { await viewModel?.load() }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active {
                viewModel?.refreshIfDayChanged()
            }
        }
        .overlay {
            if vm.isResolvingStream {
                ProgressView()
                    .controlSize(.large)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(.ultraThinMaterial)
            }
        }
        .sheet(item: Bindable(vm).selectedProgram) { program in
            EPGProgramDetailMacSheet(
                program: program,
                onPlayLive: { channel in
                    viewModel?.selectedProgram = nil
                    Task { await playLive(channel: channel) }
                },
                onPlayArchive: { channelId, program in
                    viewModel?.selectedProgram = nil
                    Task { await playArchive(channelId: channelId, program: program) }
                }
            )
            .frame(minWidth: 400, minHeight: 250)
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
        .frame(maxWidth: 300)
    }

    // MARK: - Channels 3-Column Layout

    private var channelsLayout: some View {
        HStack(spacing: 0) {
            // Column 1: Categories
            categoriesColumn
                .frame(width: 180)

            Divider()

            // Column 2: Channels
            channelsColumn
                .frame(width: 300)

            Divider()

            // Column 3: Program detail
            programDetailColumn
        }
    }

    // MARK: - Column 1: Categories

    private var categoriesColumn: some View {
        List(selection: Binding(
            get: { vm.selectedCategory?.id },
            set: { newId in
                let category = vm.categories.first { $0.id == newId }
                viewModel?.selectCategory(category)
            }
        )) {
            Text(String(localized: "livetv.category.all"))
                .tag(nil as Int?)

            ForEach(vm.categories) { category in
                Text(category.name)
                    .tag(category.id as Int?)
            }
        }
        .listStyle(.sidebar)
    }

    // MARK: - Column 2: Channels

    private var channelsColumn: some View {
        List(selection: Binding(
            get: { vm.selectedChannel?.id },
            set: { newId in
                if let channel = vm.filteredChannels.first(where: { $0.id == newId }) {
                    viewModel?.selectChannel(channel)
                }
            }
        )) {
            ForEach(vm.filteredChannels) { channel in
                ChannelRowMac(
                    channel: channel,
                    currentProgram: vm.currentProgram(for: channel),
                    onPlay: { Task { await playLive(channel: channel) } }
                )
                .tag(channel.id)
                .onAppear { viewModel?.loadProgramsIfNeeded(for: channel) }
            }
        }
        .listStyle(.plain)
    }

    // MARK: - Column 3: Program Detail

    private var programDetailColumn: some View {
        Group {
            if let channel = vm.selectedChannel {
                VStack(spacing: 0) {
                    programImageHeader

                    List {
                        ForEach(vm.selectedChannelPrograms) { program in
                            ProgramRowMac(
                                program: program,
                                isNow: isProgramNow(program),
                                isSelected: vm.selectedProgram?.id == program.id
                            ) {
                                viewModel?.selectedProgram = program
                            } onPlay: {
                                Task { await handleProgramTap(program: program, channel: channel) }
                            }
                        }
                    }
                    .listStyle(.plain)
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
                        .frame(height: 200)
                        .clipped()
                } else {
                    Color.gray.opacity(0.1)
                        .frame(height: 200)
                }
            }
        } else {
            Color.gray.opacity(0.1)
                .frame(height: 200)
                .overlay {
                    Image(systemName: "tv")
                        .font(.largeTitle)
                        .foregroundStyle(.secondary)
                }
        }
    }

    // MARK: - EPG Content

    private let channelColumnWidth: CGFloat = 100
    private let rowHeight: CGFloat = 60
    private let pixelsPerMinute: CGFloat = 3.33
    private let epgSpacing: CGFloat = 1
    private let timeHeaderHeight: CGFloat = 24

    private var epgContent: some View {
        VStack(spacing: 0) {
            epgDateHeader

            epgGrid
        }
    }

    private var epgDateHeader: some View {
        HStack(spacing: 16) {
            Spacer()

            HStack(spacing: 8) {
                ForEach(vm.availableDates, id: \.self) { date in
                    epgDateButton(date)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(.bar)
    }

    private func epgDateButton(_ date: Date) -> some View {
        let isSelected = Calendar.current.isDate(date, inSameDayAs: vm.selectedDate)
        return Button {
            viewModel?.selectedDate = date
            viewModel?.dateChanged()
        } label: {
            Text(date, format: .dateTime.weekday(.abbreviated).day())
                .font(.caption)
                .fontWeight(isSelected ? .bold : .regular)
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(
                    Capsule()
                        .fill(isSelected ? Color.brandPrimary : Color.gray.opacity(0.15))
                )
                .foregroundStyle(isSelected ? .white : .primary)
        }
        .buttonStyle(.plain)
    }

    private var epgGrid: some View {
        ScrollView(.vertical, showsIndicators: false) {
            HStack(alignment: .top, spacing: 0) {
                // Fixed channel column
                VStack(spacing: 0) {
                    Color.clear
                        .frame(width: channelColumnWidth, height: timeHeaderHeight)
                    LazyVStack(spacing: 0) {
                        ForEach(vm.channels) { channel in
                            epgChannelCell(channel)
                                .frame(width: channelColumnWidth, height: rowHeight)
                                .onAppear { viewModel?.loadProgramsIfNeeded(for: channel) }
                            Divider()
                        }
                    }
                }

                // Horizontally scrollable program area
                ScrollView(.horizontal, showsIndicators: true) {
                    VStack(alignment: .leading, spacing: 0) {
                        epgTimeHeader
                            .frame(height: timeHeaderHeight)
                            .background(.bar)
                        LazyVStack(alignment: .leading, spacing: 0) {
                            ForEach(vm.channels) { channel in
                                epgProgramRow(for: channel)
                                    .frame(height: rowHeight)
                                Divider()
                            }
                        }
                    }
                }
            }
        }
    }

    private func epgChannelCell(_ channel: Media) -> some View {
        VStack(spacing: 4) {
            channelLogo(channel)
                .frame(width: 36, height: 36)
                .clipShape(RoundedRectangle(cornerRadius: 6))

            Text(channel.title)
                .font(.system(size: 9))
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity)
    }

    private var epgTimeHeader: some View {
        HStack(spacing: 0) {
            ForEach(0..<24, id: \.self) { hour in
                Text(String(format: "%02d:00", hour))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .frame(width: pixelsPerMinute * 60, alignment: .leading)
                    .padding(.leading, 4)
            }
        }
    }

    private func epgProgramRow(for channel: Media) -> some View {
        let programs = vm.programsByChannel[channel.id] ?? []
        let offset = epgLeadingOffset(for: programs)
        return HStack(spacing: epgSpacing) {
            if programs.isEmpty {
                Rectangle()
                    .fill(Color.gray.opacity(0.1))
                    .frame(width: pixelsPerMinute * 60 * 24)
            } else {
                if offset > 0 {
                    Color.clear
                        .frame(width: offset, height: rowHeight)
                }
                ForEach(programs) { program in
                    epgProgramCell(program)
                }
            }
        }
        .onAppear { viewModel?.loadProgramsIfNeeded(for: channel) }
    }

    private func epgProgramCell(_ program: Media) -> some View {
        let width = epgProgramWidth(program)
        let isNow = isProgramNow(program)
        return Button {
            viewModel?.selectedProgram = program
        } label: {
            VStack(alignment: .leading, spacing: 2) {
                Text(program.title)
                    .font(.caption)
                    .fontWeight(isNow ? .bold : .regular)
                    .lineLimit(2)
                if let start = program.programStart {
                    Text(start, format: .dateTime.hour().minute())
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 4)
            .padding(.vertical, 3)
            .frame(width: width, height: rowHeight - 2, alignment: .topLeading)
            .background(
                RoundedRectangle(cornerRadius: 4)
                    .fill(isNow ? Color.brandPrimary.opacity(0.2) : Color.gray.opacity(0.1))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 4)
                    .strokeBorder(isNow ? Color.brandPrimary : Color.clear, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
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
                        .foregroundStyle(.secondary)
                }
            }
        } else {
            Image(systemName: "tv")
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
            return pixelsPerMinute * 30
        }
        let durationMinutes = end.timeIntervalSince(start) / 60
        return max(50, CGFloat(durationMinutes) * pixelsPerMinute)
    }

    private func playLive(channel: Media) async {
        guard let playback = await viewModel?.resolveLivePlayback(for: channel) else { return }
        coordinator.showPlayer(streamURL: ApiClient.playbackURL(sessionId: playback.sessionId), sessionId: playback.sessionId, media: channel)
    }

    private func playArchive(channelId: String, program: Media) async {
        guard let playback = await viewModel?.resolveArchivePlayback(program: program) else { return }
        coordinator.showPlayer(streamURL: ApiClient.playbackURL(sessionId: playback.sessionId), sessionId: playback.sessionId, media: program)
    }

    private func handleProgramTap(program: Media, channel: Media) async {
        let isNow = isProgramNow(program)
        let isPast = (program.programEnd ?? .distantFuture) < Date.now

        if isNow {
            await playLive(channel: channel)
        } else if isPast {
            await playArchive(channelId: channel.id, program: program)
        }
    }
}

// MARK: - Channel Row (macOS)

private struct ChannelRowMac: View {
    let channel: Media
    let currentProgram: Media?
    let onPlay: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            // Logo
            channelLogo
                .frame(width: 40, height: 40)
                .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))

            VStack(alignment: .leading, spacing: 2) {
                Text(channel.title)
                    .font(.callout)
                    .fontWeight(.semibold)
                    .lineLimit(1)

                if let program = currentProgram {
                    Text(program.title)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)

                    if let start = program.programStart, let end = program.programEnd {
                        programProgress(start: start, end: end)
                    }
                }
            }

            Spacer(minLength: 0)

            Button(action: onPlay) {
                Image(systemName: "play.fill")
                    .font(.caption)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)
        }
        .contentShape(Rectangle())
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
        RoundedRectangle(cornerRadius: 6, style: .continuous)
            .fill(Color.gray.opacity(0.15))
            .overlay {
                Image(systemName: "tv")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
    }

    private func programProgress(start: Date, end: Date) -> some View {
        let now = Date.now
        let total = end.timeIntervalSince(start)
        let elapsed = now.timeIntervalSince(start)
        let progress = total > 0 ? min(max(elapsed / total, 0), 1) : 0

        return VStack(spacing: 1) {
            ProgressView(value: progress)
                .tint(.brandPrimary)
            HStack {
                Text(start.formatted(.dateTime.hour().minute()))
                Spacer()
                Text(end.formatted(.dateTime.hour().minute()))
            }
            .font(.system(size: 8))
            .foregroundStyle(.tertiary)
        }
    }
}

// MARK: - Program Row (macOS)

private struct ProgramRowMac: View {
    let program: Media
    let isNow: Bool
    let isSelected: Bool
    let onSelect: () -> Void
    let onPlay: () -> Void

    var body: some View {
        Button(action: onPlay) {
            HStack(alignment: .top, spacing: 8) {
                if let start = program.programStart {
                    Text(start.formatted(.dateTime.hour().minute()))
                        .font(.callout)
                        .fontWeight(isNow ? .bold : .regular)
                        .monospacedDigit()
                        .frame(width: 50, alignment: .leading)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(program.title)
                        .font(.callout)
                        .fontWeight(isNow ? .bold : .regular)
                        .lineLimit(1)

                    if let summary = program.summary, !summary.isEmpty {
                        Text(summary)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(3)
                    }
                }

                Spacer(minLength: 0)
            }
            .padding(.vertical, 4)
            .listRowBackground(
                RoundedRectangle(cornerRadius: 4)
                    .fill(isNow ? Color.brandPrimary.opacity(0.1) : Color.clear)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Program Detail Sheet (macOS)

private struct EPGProgramDetailMacSheet: View {
    let program: Media
    let onPlayLive: (Media) -> Void
    let onPlayArchive: (String, Media) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(program.title)
                .font(.title2.bold())

            if let start = program.programStart, let end = program.programEnd {
                HStack(spacing: 12) {
                    Label(start.formatted(.dateTime.hour().minute()), systemImage: "clock")
                    Text("–")
                    Text(end.formatted(.dateTime.hour().minute()))
                }
                .font(.subheadline)
                .foregroundStyle(.secondary)
            }

            if let summary = program.summary, !summary.isEmpty {
                Text(summary)
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            HStack(spacing: 12) {
                if isPast {
                    Button {
                        if let channelId = program.channelId {
                            onPlayArchive(channelId, program)
                        }
                    } label: {
                        Label("epg.play.archive", systemImage: "play.fill")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(program.channelId == nil)
                }

                if isNow {
                    if let channelId = program.channelId {
                        Button {
                            let channel = Media(
                                kind: .channel,
                                id: channelId,
                                name: program.title,
                                description: nil,
                                url: "",
                                art: program.art,
                                details: nil,
                                watchPosition: nil,
                                watchCompleted: nil,
                                isFavorite: nil,
                                updatedUtc: nil
                            )
                            onPlayLive(channel)
                        } label: {
                            Label("epg.play.live", systemImage: "antenna.radiowaves.left.and.right")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                    }
                }
            }
        }
        .padding()
    }

    private var isNow: Bool {
        guard let start = program.programStart, let end = program.programEnd else { return false }
        let now = Date.now
        return start <= now && now < end
    }

    private var isPast: Bool {
        guard let end = program.programEnd else { return false }
        return end < Date.now
    }
}
