import SwiftUI

@MainActor
struct EPGView: View {
    @Environment(SettingsManager.self) private var settingsManager
    @EnvironmentObject private var coordinator: MainCoordinator
    @State private var viewModel: EPGViewModel?

    private var vm: EPGViewModel { viewModel ?? EPGViewModel(settingsManager: settingsManager) }

    private let channelColumnWidth: CGFloat = 80
    private let rowHeight: CGFloat = 70
    private let pixelsPerMinute: CGFloat = 4.0 // 240px per hour
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
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            if viewModel == nil {
                viewModel = EPGViewModel(settingsManager: settingsManager)
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
            EPGProgramDetailSheet(
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
            .presentationDetents([.medium])
        }
    }

    // MARK: - Header

    private var headerBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
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

    private let timeHeaderHeight: CGFloat = 24

    // MARK: - EPG Grid (two-column layout: fixed channels + scrollable programs)

    private var epgGrid: some View {
        HStack(alignment: .top, spacing: 0) {
            // Fixed channel column (with corner spacer for time header)
            VStack(spacing: 0) {
                Color.clear
                    .frame(width: channelColumnWidth, height: timeHeaderHeight)
                ScrollView(.vertical, showsIndicators: false) {
                    channelColumn
                }
            }

            // Horizontally scrollable: time header pinned on top + vertically scrollable programs
            ScrollView(.horizontal, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 0) {
                    timeHeader
                        .frame(height: timeHeaderHeight)
                        .background(Color(.systemBackground))

                    ScrollView(.vertical, showsIndicators: false) {
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

    // MARK: - Channel Column

    private var channelColumn: some View {
        LazyVStack(spacing: 0) {
            ForEach(vm.channels) { channel in
                channelCell(channel)
                    .frame(width: channelColumnWidth, height: rowHeight)
                    .background(Color(.systemBackground))
                    .onAppear { vm.loadProgramsIfNeeded(for: channel) }
                Divider()
            }
        }
    }

    private func channelCell(_ channel: Media) -> some View {
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
    }

    /// Computes the pixel offset from 00:00 of the selected day to the first program's start.
    private func leadingOffset(for programs: [Media]) -> CGFloat {
        guard let firstStart = programs.first?.programStart else { return 0 }
        let dayStart = Calendar.current.startOfDay(for: vm.selectedDate)
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

    // MARK: - Helpers

    private func programWidth(_ program: Media) -> CGFloat {
        guard let start = program.programStart, let end = program.programEnd else {
            return pixelsPerMinute * 30
        }
        let durationMinutes = end.timeIntervalSince(start) / 60
        return max(60, CGFloat(durationMinutes) * pixelsPerMinute)
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
