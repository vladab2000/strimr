import SwiftUI

@MainActor
struct EPGMacView: View {
    @Environment(ChannelProgramManager.self) private var channelManager
    @EnvironmentObject private var coordinator: MainCoordinator
    @State private var viewModel: EPGViewModel?

    private var vm: EPGViewModel { viewModel ?? EPGViewModel(manager: channelManager) }

    private let channelColumnWidth: CGFloat = 100
    private let rowHeight: CGFloat = 60
    private let pixelsPerMinute: CGFloat = 3.33 // 200px per hour
    private let spacing: CGFloat = 1

    var body: some View {
        VStack(spacing: 0) {
            headerBar

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
            }
        }
        .navigationTitle("tabs.epg")
        .onAppear {
            if viewModel == nil {
                viewModel = EPGViewModel(manager: channelManager)
            }
            vm.reloadIfProviderChanged()
        }
        .task { await vm.load() }
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
                    vm.selectedProgram = nil
                    Task { await playLive(channel: channel) }
                },
                onPlayArchive: { channelId, program in
                    vm.selectedProgram = nil
                    Task { await playArchive(channelId: channelId, program: program) }
                }
            )
            .frame(minWidth: 400, minHeight: 250)
        }
    }

    // MARK: - Header

    private var headerBar: some View {
        HStack(spacing: 16) {
            Spacer()

            HStack(spacing: 8) {
                ForEach(vm.availableDates, id: \.self) { date in
                    dateButton(date)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(.bar)
    }

    private func dateButton(_ date: Date) -> some View {
        let isSelected = Calendar.current.isDate(date, inSameDayAs: vm.selectedDate)
        return Button {
            vm.selectedDate = date
            vm.dateChanged()
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

    private let timeHeaderHeight: CGFloat = 24

    // MARK: - EPG Grid (channels pinned left, programs scroll horizontally, both scroll vertically together)

    private var epgGrid: some View {
        ScrollView(.vertical, showsIndicators: false) {
            HStack(alignment: .top, spacing: 0) {
                // Fixed channel column (does not scroll horizontally)
                VStack(spacing: 0) {
                    Color.clear
                        .frame(width: channelColumnWidth, height: timeHeaderHeight)
                    LazyVStack(spacing: 0) {
                        ForEach(vm.channels) { channel in
                            channelCell(channel)
                                .frame(width: channelColumnWidth, height: rowHeight)
                                .onAppear { vm.loadProgramsIfNeeded(for: channel) }
                            Divider()
                        }
                    }
                }

                // Horizontally scrollable program area
                ScrollView(.horizontal, showsIndicators: true) {
                    VStack(alignment: .leading, spacing: 0) {
                        timeHeader
                            .frame(height: timeHeaderHeight)
                            .background(.bar)
                        LazyVStack(alignment: .leading, spacing: 0) {
                            ForEach(vm.channels) { channel in
                                programRow(for: channel)
                                    .frame(height: rowHeight)
                                Divider()
                            }
                        }
                    }
                }
            }
        }
    }

    // MARK: - Channel Cell

    private func channelCell(_ channel: Media) -> some View {
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

    // MARK: - Time Header

    private var timeHeader: some View {
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

    // MARK: - Program Row

    private func programRow(for channel: Media) -> some View {
        let programs = vm.programsByChannel[channel.id] ?? []
        let offset = leadingOffset(for: programs)
        return HStack(spacing: spacing) {
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
                    programCell(program, channel: channel)
                }
            }
        }
        .onAppear { vm.loadProgramsIfNeeded(for: channel) }
    }

    /// Computes the pixel offset from 00:00 of the selected day to the first program's start.
    private func leadingOffset(for programs: [Media]) -> CGFloat {
        guard let firstStart = programs.first?.programStart else { return 0 }
        let dayStart = vm.baseDate
        let offsetMinutes = firstStart.timeIntervalSince(dayStart) / 60
        guard offsetMinutes > 0 else { return 0 }
        return CGFloat(offsetMinutes) * pixelsPerMinute
    }

    private func programCell(_ program: Media, channel: Media) -> some View {
        let width = programWidth(program)
        let isNow = isProgramNow(program)
        return Button {
            vm.selectedProgram = program
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

    // MARK: - Helpers

    private func programWidth(_ program: Media) -> CGFloat {
        guard let start = program.programStart, let end = program.programEnd else {
            return pixelsPerMinute * 30
        }
        let durationMinutes = end.timeIntervalSince(start) / 60
        return max(50, CGFloat(durationMinutes) * pixelsPerMinute)
    }

    private func isProgramNow(_ program: Media) -> Bool {
        guard let start = program.programStart, let end = program.programEnd else { return false }
        let now = Date.now
        return start <= now && now < end
    }

    private func playLive(channel: Media) async {
        guard let url = await vm.resolveLiveStreamURL(for: channel) else { return }
        coordinator.showPlayer(streamURL: url, media: channel)
    }

    private func playArchive(channelId: String, program: Media) async {
        guard let url = await vm.resolveArchiveStreamURL(channelId: channelId, program: program) else { return }
        coordinator.showPlayer(streamURL: url, media: program)
    }
}

// MARK: - Program Detail Sheet

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
