import SwiftUI

/// Overlay zobrazující historické výskyty programu stejného názvu z archivu.
/// Vyvolá se dlouhým stiskem Select na buňce EPG.
struct ProgramHistoryView: View {

    let program: Media
    let providerType: ProviderType
    let onPlay: (Media) -> Void
    let onDismiss: () -> Void

    @State private var results: [Media] = []
    @State private var isLoading = true
    @State private var errorMessage: String?

    var body: some View {
        ZStack {
            Color.black.opacity(0.85).ignoresSafeArea()

            VStack(spacing: 0) {
                // Hlavička
                VStack(spacing: 8) {
                    Text(program.title)
                        .font(.title2)
                        .bold()
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.center)
                    Text("epg.history.title")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
                .padding(.top, 48)
                .padding(.horizontal, 48)
                .padding(.bottom, 32)

                // Obsah
                Group {
                    if isLoading {
                        ProgressView()
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else if let error = errorMessage {
                        ContentUnavailableView(error, systemImage: "exclamationmark.triangle")
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else if results.isEmpty {
                        ContentUnavailableView(
                            "epg.history.empty.title",
                            systemImage: "tv.slash",
                            description: Text(String(format: String(localized: "epg.history.empty.description"), program.title))
                        )
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else {
                        ScrollView {
                            LazyVStack(spacing: 4) {
                                ForEach(results) { item in
                                    ProgramHistoryRow(item: item) {
                                        onPlay(item)
                                    }
                                }
                            }
                            .padding(.horizontal, 48)
                            .padding(.bottom, 48)
                        }
                    }
                }
            }
        }
        .task { await load() }
        .onExitCommand { onDismiss() }
    }

    private func load() async {
        isLoading = true
        errorMessage = nil
        do {
            let all = try await ApiClient.fetchProgramSearch(text: program.title, providerType: providerType)
            // Hledání najde název i v popisu jiných pořadů — přednost mají vysílání se stejným názvem
            let sameTitle = all.filter { $0.title.caseInsensitiveCompare(program.title) == .orderedSame }
            // Seřadíme sestupně — nejnovější záznamy nahoře, filtrujeme jen minulé
            let now = Date()
            results = (sameTitle.isEmpty ? all : sameTitle)
                .filter { ($0.programEnd ?? .distantFuture) < now }
                .sorted { ($0.programStart ?? .distantPast) > ($1.programStart ?? .distantPast) }
        } catch {
            errorMessage = String(localized: "epg.history.error")
        }
        isLoading = false
    }
}

private struct ProgramHistoryRow: View {
    let item: Media
    let onSelect: () -> Void

    @FocusState private var isFocused: Bool

    private var dateLabel: String {
        guard let start = item.programStart, let end = item.programEnd else { return "" }
        let dateFmt = DateFormatter()
        dateFmt.dateFormat = "E d. M. yyyy"
        let timeFmt = DateFormatter()
        timeFmt.dateFormat = "HH:mm"
        return "\(dateFmt.string(from: start))  \(timeFmt.string(from: start)) – \(timeFmt.string(from: end))"
    }

    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 24) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(item.channelName ?? "")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                    Text(dateLabel)
                        .font(.body)
                        .foregroundStyle(.white)
                }
                Spacer()
                Image(systemName: "play.fill")
                    .foregroundStyle(.white.opacity(0.6))
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 16)
            .background(isFocused ? Color.white.opacity(0.15) : Color.white.opacity(0.05))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
        .focused($isFocused)
    }
}
