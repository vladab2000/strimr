import SwiftUI

@MainActor
struct LiveTVView: View {
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
                    channelsContent
                case .tvGuide:
                    epgContent
                }
            }
        }
        .navigationTitle("tabs.liveTV")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            if viewModel == nil {
                viewModel = LiveTVViewModel(manager: channelManager)
            }
            viewModel?.reloadIfProviderChanged()
        }
        .task { await viewModel?.load() }
        .refreshable { await viewModel?.reload() }
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
            EPGProgramDetailSheet(
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
            .presentationDetents([.medium])
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
    }

    // MARK: - Channels Content

    private var channelsContent: some View {
        VStack(spacing: 0) {
            // Category chip bar
            categoryChipBar
                .padding(.vertical, 8)

            // Channel list
            ScrollView {
                LazyVStack(spacing: 2) {
                    ForEach(vm.filteredChannels) { channel in
                        ChannelRowIOS(
                            channel: channel,
                            currentProgram: vm.currentProgram(for: channel),
                            onTap: {
                                viewModel?.selectChannel(channel)
                            },
                            onPlay: {
                                Task { await playLive(channel: channel) }
                            }
                        )
                        .onAppear {
                            viewModel?.loadProgramsIfNeeded(for: channel)
                        }
                    }
                }
                .padding(.horizontal, 16)
            }
        }
    }

    private var categoryChipBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                CategoryChip(
                    title: String(localized: "livetv.category.all"),
                    isSelected: vm.selectedCategory == nil
                ) {
                    viewModel?.selectCategory(nil)
                }

                ForEach(vm.categories) { category in
                    CategoryChip(
                        title: category.name,
                        isSelected: vm.selectedCategory?.id == category.id
                    ) {
                        viewModel?.selectCategory(category)
                    }
                }
            }
            .padding(.horizontal, 16)
        }
    }

    // MARK: - EPG Content

    private let channelColumnWidth: CGFloat = 80
    private let rowHeight: CGFloat = 70
    private let pixelsPerMinute: CGFloat = 4.0
    private let epgSpacing: CGFloat = 1
    private let timeHeaderHeight: CGFloat = 24

    private var epgContent: some View {
        VStack(spacing: 0) {
            epgDateHeader

            if vm.isLoading, !vm.hasContent {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                epgGrid
            }
        }
    }

    private var epgDateHeader: some View {
        ScrollView(.horizontal, showsIndicators: false) {
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
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
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
                                .background(Color(.systemBackground))
                                .onAppear { viewModel?.loadProgramsIfNeeded(for: channel) }
                            Divider()
                        }
                    }
                }

                // Horizontally scrollable program area
                ScrollView(.horizontal, showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 0) {
                        epgTimeHeader
                            .frame(height: timeHeaderHeight)
                            .background(Color(.systemBackground))
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
                .frame(width: 40, height: 40)
                .clipShape(RoundedRectangle(cornerRadius: 8))

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
            .padding(.horizontal, 6)
            .padding(.vertical, 4)
            .frame(width: width, height: rowHeight - 2, alignment: .topLeading)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(isNow ? Color.brandPrimary.opacity(0.2) : Color.gray.opacity(0.1))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 6)
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
        return max(60, CGFloat(durationMinutes) * pixelsPerMinute)
    }

    private func playLive(channel: Media) async {
        guard let playback = await viewModel?.resolveLivePlayback(for: channel) else { return }
        coordinator.showPlayer(streamURL: ApiClient.playbackURL(sessionId: playback.sessionId), sessionId: playback.sessionId, media: channel)
    }

    private func playArchive(channelId: String, program: Media) async {
        guard let playback = await viewModel?.resolveArchivePlayback(channelId: channelId, program: program) else { return }
        coordinator.showPlayer(streamURL: ApiClient.playbackURL(sessionId: playback.sessionId), sessionId: playback.sessionId, media: program)
    }
}

// MARK: - Category Chip

private struct CategoryChip: View {
    let title: String
    let isSelected: Bool
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            Text(title)
                .font(.caption)
                .fontWeight(isSelected ? .semibold : .regular)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(
                    Capsule()
                        .fill(isSelected ? Color.brandPrimary : Color.gray.opacity(0.15))
                )
                .foregroundStyle(isSelected ? .white : .primary)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Channel Row (iOS)

private struct ChannelRowIOS: View {
    let channel: Media
    let currentProgram: Media?
    let onTap: () -> Void
    let onPlay: () -> Void

    var body: some View {
        Button(action: onPlay) {
            HStack(spacing: 12) {
                // Logo
                channelLogo
                    .frame(width: 48, height: 48)
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

                VStack(alignment: .leading, spacing: 3) {
                    // Channel name
                    Text(channel.title)
                        .font(.subheadline)
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
            .padding(.vertical, 8)
        }
        .buttonStyle(.plain)
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
            .font(.system(size: 9))
            .foregroundStyle(.tertiary)
        }
    }
}

// MARK: - Program Detail Sheet (reused from EPG)

private struct EPGProgramDetailSheet: View {
    let program: Media
    let onPlayLive: (Media) -> Void
    let onPlayArchive: (String, Media) -> Void

    var body: some View {
        NavigationStack {
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
            .navigationBarTitleDisplayMode(.inline)
        }
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
