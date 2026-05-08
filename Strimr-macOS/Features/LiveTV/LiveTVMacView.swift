import SwiftUI
import Combine

// MARK: - Scroll offset PreferenceKey

private struct EPGScrollOffsetKey: PreferenceKey {
    static let defaultValue = CGPoint.zero
    static func reduce(value: inout CGPoint, nextValue: () -> CGPoint) { value = nextValue() }
}

// MARK: - LiveTVMacView

@MainActor
struct LiveTVMacView: View {
    @Environment(ChannelManager.self) private var channelManager
    @Environment(\.scenePhase) private var scenePhase
    @EnvironmentObject private var coordinator: MainCoordinator
    @State private var viewModel: LiveTVViewModel?

    // EPG scroll state
    @State private var horizontalOffset: CGFloat = 0
    @State private var verticalOffset: CGFloat = 0
    @State private var epgScrollToDate: Date? = nil
    @State private var currentTime: Date = .now
    @State private var epgViewportSize: CGSize = .zero

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
        .onReceive(Timer.publish(every: 60, on: .main, in: .common).autoconnect()) { _ in
            currentTime = Date()
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
            categoriesColumn
                .frame(width: 180)

            Divider()

            channelsColumn
                .frame(width: 300)

            Divider()

            programDetailColumn
        }
    }

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
                    Color.gray.opacity(0.1).frame(height: 200)
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

    // MARK: - EPG Content (continuous multi-day grid)

    private let epgChannelWidth: CGFloat = 110
    private let epgRowHeight: CGFloat = 60
    private let epgRowSpacing: CGFloat = 1
    private let epgTimelineHeight: CGFloat = 28
    private let epgPPM: CGFloat = 3.5       // pixels per minute
    private let epgDaysBack: Int = 6        // 6 days ago + today = 7 days total

    private var epgStartDate: Date {
        var cal = Calendar.current
        cal.timeZone = TimeZone(abbreviation: "UTC")!
        return cal.startOfDay(for: cal.date(byAdding: .day, value: -epgDaysBack, to: Date())!)
    }

    private var epgTotalDays: Int { epgDaysBack + 1 }
    private var epgTotalWidth: CGFloat { CGFloat(epgTotalDays * 24 * 60) * epgPPM }
    private var epgTotalHeight: CGFloat { CGFloat(vm.channels.count) * (epgRowHeight + epgRowSpacing) }

    private var epgContent: some View {
        VStack(spacing: 0) {
            epgDateNav
                .background(.bar)

            GeometryReader { geo in
                let scrollW = geo.size.width - epgChannelWidth
                let scrollH = geo.size.height - epgTimelineHeight

                ZStack(alignment: .topLeading) {
                    // 1. Main scrollable program grid
                    ScrollViewReader { proxy in
                        ScrollView([.horizontal, .vertical], showsIndicators: true) {
                            ZStack(alignment: .topLeading) {
                                Color.clear
                                    .frame(width: epgTotalWidth, height: epgTotalHeight)

                                // Row backgrounds and program cells
                                ForEach(Array(vm.channels.enumerated()), id: \.element.id) { idx, channel in
                                    let yBase = CGFloat(idx) * (epgRowHeight + epgRowSpacing)

                                    Rectangle()
                                        .fill(idx % 2 == 0 ? Color.primary.opacity(0.04) : Color.clear)
                                        .frame(width: epgTotalWidth, height: epgRowHeight)
                                        .offset(y: yBase)

                                    epgProgramCells(for: channel, yBase: yBase)
                                }

                                // Current time vertical line
                                let nowX = epgXOffset(for: currentTime)
                                if nowX >= 0 && nowX <= epgTotalWidth {
                                    Rectangle()
                                        .fill(Color.red.opacity(0.75))
                                        .frame(width: 2, height: epgTotalHeight)
                                        .offset(x: nowX)
                                }

                                // Day anchor markers (for programmatic scroll)
                                ForEach(0..<epgTotalDays, id: \.self) { dayIdx in
                                    let dayX = CGFloat(dayIdx) * CGFloat(24 * 60) * epgPPM
                                    Color.clear.frame(width: 1, height: 1)
                                        .id("epg-day-\(dayIdx)")
                                        .offset(x: dayX)
                                }

                                // "Now" anchor (for initial scroll)
                                Color.clear.frame(width: 1, height: 1)
                                    .id("epg-now")
                                    .offset(x: max(0, epgXOffset(for: Date()) - scrollW * 0.25))
                            }
                            .background(
                                GeometryReader { gProxy in
                                    Color.clear.preference(
                                        key: EPGScrollOffsetKey.self,
                                        value: CGPoint(
                                            x: -gProxy.frame(in: .named("epgScroll")).minX,
                                            y: -gProxy.frame(in: .named("epgScroll")).minY
                                        )
                                    )
                                }
                            )
                        }
                        .coordinateSpace(.named("epgScroll"))
                        .onPreferenceChange(EPGScrollOffsetKey.self) { value in
                            horizontalOffset = max(0, value.x)
                            verticalOffset = max(0, value.y)
                            epgViewportSize = CGSize(width: scrollW, height: scrollH)
                            epgLoadVisibleData()
                        }
                        .onAppear {
                            epgViewportSize = CGSize(width: scrollW, height: scrollH)
                            DispatchQueue.main.async {
                                proxy.scrollTo("epg-now", anchor: .leading)
                                epgLoadInitialData()
                            }
                        }
                        .onChange(of: epgScrollToDate) { _, date in
                            guard let date else { return }
                            let dayIdx = epgDayIndex(for: date)
                            proxy.scrollTo("epg-day-\(dayIdx)", anchor: .leading)
                            epgScrollToDate = nil
                        }
                    }
                    .frame(width: scrollW, height: scrollH)
                    .offset(x: epgChannelWidth, y: epgTimelineHeight)

                    // 2. Sticky time header
                    epgTimeHeader(width: scrollW)
                        .frame(width: scrollW, height: epgTimelineHeight)
                        .offset(x: epgChannelWidth)

                    // 3. Sticky channel sidebar
                    epgChannelSidebar(height: scrollH)
                        .frame(width: epgChannelWidth, height: scrollH)
                        .offset(y: epgTimelineHeight)

                    // 4. Corner cap
                    Rectangle()
                        .fill(Color(.windowBackgroundColor))
                        .frame(width: epgChannelWidth, height: epgTimelineHeight)
                }
            }
        }
    }

    // MARK: - EPG date nav

    private var epgDateNav: some View {
        let visibleDate = epgDateForX(horizontalOffset)
        return HStack(spacing: 8) {
            ForEach(vm.availableDates, id: \.self) { date in
                let isSelected = Calendar.current.isDate(date, inSameDayAs: visibleDate)
                Button {
                    epgScrollToDate = date
                } label: {
                    Text(date, format: .dateTime.weekday(.abbreviated).day())
                        .font(.caption)
                        .fontWeight(isSelected ? .bold : .regular)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(Capsule().fill(isSelected ? Color.brandPrimary : Color.gray.opacity(0.15)))
                        .foregroundStyle(isSelected ? .white : .primary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }

    // MARK: - EPG time header

    private func epgTimeHeader(width: CGFloat) -> some View {
        ZStack(alignment: .leading) {
            Color(.windowBackgroundColor)
            HStack(spacing: 0) {
                ForEach(0..<(epgTotalDays * 24), id: \.self) { hourIdx in
                    let isNewDay = hourIdx % 24 == 0
                    Text(epgHourLabel(hourIndex: hourIdx))
                        .font(.caption2)
                        .foregroundStyle(isNewDay ? .primary : .secondary)
                        .fontWeight(isNewDay ? .semibold : .regular)
                        .frame(width: epgPPM * 60, alignment: .leading)
                        .padding(.leading, 4)
                }
            }
            .offset(x: -horizontalOffset)
            .clipped()
        }
        .clipped()
    }

    // MARK: - EPG channel sidebar

    private func epgChannelSidebar(height: CGFloat) -> some View {
        ZStack(alignment: .top) {
            Color(.windowBackgroundColor)
            VStack(spacing: epgRowSpacing) {
                ForEach(vm.channels) { channel in
                    epgChannelCell(channel)
                        .frame(height: epgRowHeight)
                }
            }
            .offset(y: -verticalOffset)
            .frame(maxHeight: .infinity, alignment: .top)
            .clipped()
        }
        .clipped()
    }

    private func epgChannelCell(_ channel: Media) -> some View {
        HStack(spacing: 6) {
            let logoURL = channel.logoURL ?? channel.posterURL ?? channel.thumbURL
            AsyncImage(url: logoURL) { phase in
                if case .success(let image) = phase {
                    image.resizable().scaledToFit()
                } else {
                    Image(systemName: "tv").foregroundStyle(.secondary)
                }
            }
            .frame(width: 28, height: 28)
            .clipShape(RoundedRectangle(cornerRadius: 4))

            Text(channel.name)
                .font(.caption)
                .lineLimit(2)

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 8)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - EPG program cells

    @ViewBuilder
    private func epgProgramCells(for channel: Media, yBase: CGFloat) -> some View {
        let programs = vm.programsByChannel[channel.id] ?? []
        ForEach(programs, id: \.id) { program in
            if let start = program.programStart, let end = program.programEnd {
                let xPos = epgXOffset(for: start)
                let width = max(2, epgProgramWidth(start: start, end: end))
                Button {
                    viewModel?.selectedProgram = program
                } label: {
                    epgProgramLabel(program)
                        .frame(width: width - 1, height: epgRowHeight - 2, alignment: .topLeading)
                }
                .buttonStyle(.plain)
                .offset(x: xPos, y: yBase + 1)
            }
        }
    }

    private func epgProgramLabel(_ program: Media) -> some View {
        let isNow = isProgramNow(program)
        return VStack(alignment: .leading, spacing: 2) {
            Text(program.title)
                .font(.caption)
                .fontWeight(isNow ? .semibold : .regular)
                .lineLimit(2)
            if let start = program.programStart {
                Text(start, format: .dateTime.hour().minute())
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 4)
        .padding(.vertical, 3)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(
            RoundedRectangle(cornerRadius: 4)
                .fill(isNow ? Color.brandPrimary.opacity(0.18) : Color.gray.opacity(0.1))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 4)
                .strokeBorder(isNow ? Color.brandPrimary.opacity(0.6) : Color.gray.opacity(0.2), lineWidth: 0.5)
        )
    }

    // MARK: - EPG helpers

    private func epgXOffset(for date: Date) -> CGFloat {
        CGFloat(date.timeIntervalSince(epgStartDate) / 60) * epgPPM
    }

    private func epgProgramWidth(start: Date, end: Date) -> CGFloat {
        CGFloat(end.timeIntervalSince(start) / 60) * epgPPM
    }

    private func epgDateForX(_ x: CGFloat) -> Date {
        epgStartDate.addingTimeInterval(TimeInterval(x / epgPPM) * 60)
    }

    private func epgDayIndex(for date: Date) -> Int {
        var cal = Calendar.current
        cal.timeZone = TimeZone(abbreviation: "UTC")!
        let dayStart = cal.startOfDay(for: date)
        let days = cal.dateComponents([.day], from: epgStartDate, to: dayStart).day ?? 0
        return max(0, min(epgTotalDays - 1, days))
    }

    private func epgHourLabel(hourIndex: Int) -> String {
        let date = epgStartDate.addingTimeInterval(TimeInterval(hourIndex * 3600))
        let formatter = DateFormatter()
        formatter.timeZone = .current
        if hourIndex % 24 == 0 {
            formatter.dateFormat = "E d.M."
        } else {
            formatter.dateFormat = "HH:mm"
        }
        return formatter.string(from: date)
    }

    private func epgLoadInitialData() {
        let today = Date()
        let visibleRows = min(vm.channels.count, 15)
        for idx in 0..<visibleRows {
            viewModel?.loadProgramsIfNeeded(for: vm.channels[idx], on: today) { _ in }
        }
    }

    private func epgLoadVisibleData() {
        guard !vm.channels.isEmpty else { return }
        let bufferMinutes: Double = 120
        let visibleMinDate = epgDateForX(max(0, horizontalOffset - CGFloat(bufferMinutes) * epgPPM))
        let visibleMaxDate = epgDateForX(horizontalOffset + epgViewportSize.width + CGFloat(bufferMinutes) * epgPPM)

        var cal = Calendar.current
        cal.timeZone = TimeZone(abbreviation: "UTC")!

        let rowTotal = epgRowHeight + epgRowSpacing
        let firstRow = max(0, Int(verticalOffset / rowTotal) - 1)
        let lastRow = min(vm.channels.count - 1, Int((verticalOffset + epgViewportSize.height) / rowTotal) + 1)
        guard firstRow <= lastRow else { return }

        var current = cal.startOfDay(for: visibleMinDate)
        while current <= visibleMaxDate {
            for idx in firstRow...lastRow {
                viewModel?.loadProgramsIfNeeded(for: vm.channels[idx], on: current) { _ in }
            }
            guard let next = cal.date(byAdding: .day, value: 1, to: current) else { break }
            current = next
        }
    }

    // MARK: - Playback

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

    private func isProgramNow(_ program: Media) -> Bool {
        guard let start = program.programStart, let end = program.programEnd else { return false }
        let now = Date.now
        return start <= now && now < end
    }
}

// MARK: - Channel Row (macOS)

private struct ChannelRowMac: View {
    let channel: Media
    let currentProgram: Media?
    let onPlay: () -> Void

    var body: some View {
        HStack(spacing: 10) {
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
