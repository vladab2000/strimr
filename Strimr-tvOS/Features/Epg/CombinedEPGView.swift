//
//  CombinedEPGView.swift
//  Strimr
//
//  Created by Vladimír Bárta on 26.04.2026.
//

import SwiftUI
import Combine

struct CombinedEPGView: View {

    let viewModel: LiveTVViewModel

    @EnvironmentObject private var coordinator: MainCoordinator

    // Stavy pro uložení aktuálního posunu mřížky
    @State private var horizontalOffset: CGFloat = 0
    @State private var verticalOffset: CGFloat = 0
    @State private var focusedProgram: Media? = nil
    @State private var focusedChannel: Media? = nil
    @State private var currentTime: Date = .now

    let hourWidth: CGFloat = 15*60 // Musí sedět s EPGLayoutem
    let rowHeight: CGFloat = 80.0
    let spacing: CGFloat = 4.0
    let channelSidebarWidth: CGFloat = 250.0
    let timelineHeight: CGFloat = 60.0

    var body: some View {
        GeometryReader { geometry in
            let heroHeight = geometry.size.height * 0.38
            let epgHeight = geometry.size.height - heroHeight

            ZStack(alignment: .bottom) {

                // MARK: - Pozadí (Hero obrázek nebo černá)
                if let program = focusedProgram {
                    MediaHeroBackgroundView(media: program)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .ignoresSafeArea()
                } else {
                    Color.black.ignoresSafeArea()
                }

                VStack(spacing: 0) {

                    // MARK: - Hero obsah (název, popis, metadata)
                    HStack(alignment: .top) {
                        if let program = focusedProgram {
                            MediaHeroContentView(media: program)
                                .frame(maxWidth: geometry.size.width * 0.55, alignment: .topLeading)
                                .padding(.leading, 80)
                                .padding(.top, 32)
                        }
                        Spacer()
                    }
                    .frame(height: heroHeight)

                    // MARK: - EPG mřížka
                    epgGrid(geometry: geometry, height: epgHeight)
                }
            }
        }
        .edgesIgnoringSafeArea(.all)
        .onReceive(Timer.publish(every: 60, on: .main, in: .common).autoconnect()) { _ in
            currentTime = Date()
        }
    }

    @ViewBuilder
    private func channelRow(_ channel: Media, isSelected: Bool) -> some View {
        let logoURL = channel.logoURL ?? channel.posterURL ?? channel.thumbURL
        HStack(spacing: 10) {
            AsyncImage(url: logoURL) { phase in
                if case .success(let image) = phase {
                    image.resizable().scaledToFit()
                } else {
                    Image(systemName: "tv")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(width: 48, height: 48)
            .clipShape(RoundedRectangle(cornerRadius: 6))

            Text(channel.name)
                .font(.caption)
                .foregroundColor(isSelected ? .black : .white.opacity(0.85))
                .lineLimit(2)

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 12)
        .frame(width: channelSidebarWidth, height: rowHeight)
        .background(isSelected ? Color.white.opacity(0.9) : Color.gray.opacity(0.12))
        .animation(.easeInOut(duration: 0.15), value: isSelected)
    }

    @ViewBuilder
    private func epgGrid(geometry: GeometryProxy, height: CGFloat) -> some View {
        ZStack(alignment: .topLeading) {

            // MARK: - 1. Hlavní mřížka programů (UIKit)
            EPGCollectionViewRepresentable(
                viewModel: viewModel,
                onProgramSelected: { program, channel in
                    Task { await handleProgramTap(program: program, channel: channel) }
                },
                onProgramFocused: { program, channel in
                    focusedProgram = program
                    focusedChannel = channel
                },
                horizontalOffset: $horizontalOffset,
                verticalOffset: $verticalOffset
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(.top, timelineHeight)
            .padding(.leading, channelSidebarWidth)

            // MARK: - 2. Horní Časová Osa (SwiftUI)
            let halfHourWidth = hourWidth / 2
            let pointsPerMinute = hourWidth / 60
            let nowContentX = CGFloat(currentTime.timeIntervalSince(epgStartDate) / 60) * pointsPerMinute
            let nowVisibleX = nowContentX - horizontalOffset

            HStack(spacing: 0) {
                ForEach(0..<(14 * 24 * 2), id: \.self) { halfIndex in
                    let isHalf = halfIndex % 2 != 0
                    Text("| " + halfHourLabel(for: halfIndex))
                        .font(.caption2)
                        .foregroundColor(isHalf ? .white.opacity(0.55) : .white)
                        .frame(width: halfHourWidth, alignment: .leading)
                }
            }
            .offset(x: -horizontalOffset)
            .frame(width: geometry.size.width - channelSidebarWidth, height: timelineHeight, alignment: .leading)
            .clipped()
            .padding(.leading, channelSidebarWidth)

            // MARK: - 2b. Marker aktuálního času (přes celou výšku EPG)
            if nowVisibleX >= 0 && nowVisibleX <= geometry.size.width - channelSidebarWidth {
                Rectangle()
                    .fill(Color.red.opacity(0.7))
                    .frame(width: 2, height: height)
                    .overlay(alignment: .top) {
                        Text(currentTimeLabel)
                            .font(.caption2)
                            .bold()
                            .foregroundColor(.white)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 2)
                            .background(Color.red)
                            .cornerRadius(4)
                            .fixedSize()
                            .offset(y: 6)
                    }
                    .padding(.leading, channelSidebarWidth + nowVisibleX)
            }

            // MARK: - 3. Levý sloupec s kanály (SwiftUI)
            VStack(spacing: spacing) {
                ForEach(viewModel.channels) { channel in
                    channelRow(channel, isSelected: channel.id == focusedChannel?.id)
                }
            }
            .padding(.top, timelineHeight)
            .background(Color.black.opacity(0.9))
            .offset(y: -verticalOffset)
            .frame(width: channelSidebarWidth, height: height, alignment: .top)
            .clipped()

            // MARK: - 4. Prázdný statický roh
            Text(displayedDateString)
                .font(.caption)
                .foregroundColor(.white)
                .frame(width: channelSidebarWidth, height: timelineHeight)
        }
        //.background(Color.black.opacity(0.85))
        .frame(height: height)
    }
    
    private func handleProgramTap(program: Media, channel: Media) async {
        let now = Date.now
        let isNow = (program.programStart ?? .distantFuture) <= now && now < (program.programEnd ?? .distantPast)
        let isPast = (program.programEnd ?? .distantFuture) < now

        if isNow || isPast {
            guard let playback = await viewModel.resolveArchivePlayback(program: program) else { return }
            coordinator.showPlayer(
                streamURL: ApiClient.playbackURL(sessionId: playback.sessionId),
                sessionId: playback.sessionId,
                media: program,
                channel: channel,
                program: program
            )
        }
    }

    private var epgStartDate: Date {
        var cal = Calendar.current
        cal.timeZone = TimeZone(abbreviation: "UTC")!
        let sevenDaysAgo = cal.date(byAdding: .day, value: -7, to: Date()) ?? Date()
        return cal.startOfDay(for: sevenDaysAgo)
    }

    private var currentTimeLabel: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        formatter.timeZone = .current
        return formatter.string(from: currentTime)
    }

    // halfIndex = index po 30 minutách od začátku EPG
    private func halfHourLabel(for halfIndex: Int) -> String {
        let cellDate = epgStartDate.addingTimeInterval(TimeInterval(halfIndex) * 30 * 60)
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        formatter.timeZone = .current
        return formatter.string(from: cellDate)
    }

    // Výpočet zobrazeného dne na základě posunu mřížky
    private var displayedDateString: String {
        var utcCalendar = Calendar.current
        utcCalendar.timeZone = TimeZone(abbreviation: "UTC")!
        let sevenDaysAgo = utcCalendar.date(byAdding: .day, value: -7, to: Date()) ?? Date()
        let epgStartDate = utcCalendar.startOfDay(for: sevenDaysAgo)

        // Převedeme horizontální posun na reálné UTC datum
        let pointsPerMinute = hourWidth / 60
        let viewingDate = epgStartDate.addingTimeInterval(TimeInterval(horizontalOffset / pointsPerMinute * 60))

        // Porovnáme lokálním kalendářem, aby se přepínání Dnes/Včera dělo na lokální půlnoc
        let localCalendar = Calendar.current
        let today = localCalendar.startOfDay(for: Date())
        let viewingDay = localCalendar.startOfDay(for: viewingDate)
        let dayDiff = localCalendar.dateComponents([.day], from: today, to: viewingDay).day ?? 0

        switch dayDiff {
        case 0:  return "Dnes"
        case -1: return "Včera"
        case 1:  return "Zítra"
        default:
            let formatter = DateFormatter()
            formatter.dateFormat = "E d. M."
            return formatter.string(from: viewingDate)
        }
    }
}
