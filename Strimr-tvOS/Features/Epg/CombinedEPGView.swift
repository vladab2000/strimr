//
//  CombinedEPGView.swift
//  Strimr
//
//  Created by Vladimír Bárta on 26.04.2026.
//

import SwiftUI

struct CombinedEPGView: View {

    let viewModel: LiveTVViewModel

    @EnvironmentObject private var coordinator: MainCoordinator

    // Stavy pro uložení aktuálního posunu mřížky
    @State private var horizontalOffset: CGFloat = 0
    @State private var verticalOffset: CGFloat = 0
    @State private var focusedProgram: Media? = nil
    @State private var focusedChannel: Media? = nil

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
            HStack(spacing: 0) {
                ForEach(0..<(14 * 24), id: \.self) { hourIndex in
                    Text(timelineLabel(for: hourIndex))
                        .font(.headline)
                        .foregroundColor(.secondary)
                        .frame(width: hourWidth, alignment: .leading)
                }
            }
            .background(Color.black.opacity(0.8))
            .padding(.leading, channelSidebarWidth)
            .offset(x: -horizontalOffset)
            .frame(width: geometry.size.width - channelSidebarWidth, height: timelineHeight, alignment: .leading)
            .clipped()

            // MARK: - 3. Levý sloupec s kanály (SwiftUI)
            VStack(spacing: spacing) {
                ForEach(viewModel.channels) { channel in
                    HStack {
                        Text(channel.name)
                            .font(.headline)
                            .foregroundColor(.white)
                            .padding(.leading)
                        Spacer()
                    }
                    .frame(width: channelSidebarWidth, height: rowHeight)
                    .background(Color.gray.opacity(0.15))
                }
            }
            .padding(.top, timelineHeight)
            .background(Color.black.opacity(0.9))
            .offset(y: -verticalOffset)
            .frame(width: channelSidebarWidth, height: height - timelineHeight, alignment: .top)
            .clipped()

            // MARK: - 4. Prázdný statický roh
            ZStack {
                Rectangle()
                    .fill(Color.black)
                    .frame(width: channelSidebarWidth, height: timelineHeight)
                Text(displayedDateString)
                    .font(.headline)
                    .foregroundColor(.white)
            }
        }
        .background(Color.black.opacity(0.85))
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

    private func timelineLabel(for hourIndex: Int) -> String {
        var calendar = Calendar.current
        calendar.timeZone = TimeZone(abbreviation: "UTC")!
        let sevenDaysAgo = calendar.date(byAdding: .day, value: -7, to: Date()) ?? Date()
        let epgStartDate = calendar.startOfDay(for: sevenDaysAgo)
        let cellDate = calendar.date(byAdding: .hour, value: hourIndex, to: epgStartDate) ?? Date()
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        formatter.timeZone = TimeZone.current
        return formatter.string(from: cellDate)
    }

    // Výpočet zobrazeného dne na základě posunu mřížky
    private var displayedDateString: String {
        // Výpočet kalendářního dne stejně jako v koordinátorovi
        var calendar = Calendar.current
        calendar.timeZone = TimeZone(abbreviation: "UTC")!
        let sevenDaysAgo = calendar.date(byAdding: .day, value: -7, to: Date()) ?? Date()
        let epgStartDate = calendar.startOfDay(for: sevenDaysAgo)
        
        // Zjistíme, na kolikátou hodinu od začátku se uživatel právě dívá
        let currentHourInView = horizontalOffset / hourWidth
        let currentDayInView = Int(currentHourInView / 24.0)
        
        // Získáme konkrétní datum
        let targetDate = calendar.date(byAdding: .day, value: currentDayInView, to: epgStartDate) ?? Date()
        
        // Formátování pro českou lokalizaci (např. "26. 4.")
        let formatter = DateFormatter()
        formatter.dateFormat = "E d. M."
        
        // Volitelné: Přidání dne v týdnu (např. "Ne 26. 4.")
        // formatter.dateFormat = "E d. M."
        
        return formatter.string(from: targetDate)
    }
}
