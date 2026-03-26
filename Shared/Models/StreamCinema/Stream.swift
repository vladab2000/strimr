//
//  Stream.swift
//  StreamCinema
//
//  Created by Vladimír Bárta on 21.02.2026.
//

import Foundation

struct Stream: Codable, Hashable, Identifiable {

    static func == (lhs: Stream, rhs: Stream) -> Bool {
        lhs.url == rhs.url
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(url)
    }

    var id: String { url ?? "" }
    let url: String?
    let quality: String?
    let fps: Double?
    let audioInfo: [String]?
    let videoInfo: String?
    let size: String?
    let bitrate: String?
    let langs: [String]?
}

extension Stream {

    var sizeMb: Int {
        guard let s = size else { return 0 }
        let lowered = s.lowercased()
        if let gb = lowered.range(of: "gb") {
            let num = lowered[..<gb.lowerBound].trimmingCharacters(in: .whitespaces)
            return Int((Double(num) ?? 0) * 1000)
        } else if let mb = lowered.range(of: "mb") {
            let num = lowered[..<mb.lowerBound].trimmingCharacters(in: .whitespaces)
            return Int(Double(num) ?? 0)
        } else {
            return Int(Double(s) ?? 0)
        }
    }

    var qualityRank: Int {
        let quality = quality?.lowercased() ?? ""
        if quality.contains("1080") { return 1 }
        if quality.contains("720") { return 2 }
        if quality.contains("4k") { return 3 }
        return 4
    }

    var isCZLang: Bool {
        if let langs, langs.contains("CZ") {
            return true
        }
        return false
    }

    var langString: String? {
        guard let langs, !langs.isEmpty else { return nil }
        var arr = langs
        if let idx = arr.firstIndex(where: { $0.caseInsensitiveCompare("CZ") == .orderedSame }) {
            let cz = arr.remove(at: idx)
            arr.insert(cz, at: 0)
        }
        return arr.joined(separator: ", ")
    }

    static let preview1 = Stream(
        url: "url123",
        quality: "1080p",
        fps: 25.0,
        audioInfo: ["lc 5.1 CZ"],
        videoInfo: "AVC1 SDR",
        size: "12345 MB",
        bitrate: "1236548",
        langs: ["CZ", "EN"]
    )
}
enum StreamSorter {
    static func sorted(_ allStreams: [Stream]) -> [Stream] {
        let groupedByLang = Dictionary(grouping: allStreams) { (stream: Stream) in
            (stream.langs?.first { $0.range(of: "cz", options: .caseInsensitive) != nil } != nil) ? "CZ" : (stream.langs?.first ?? "")
        }

        func filteredAndSorted(_ streams: [Stream]) -> [Stream] {
            let hasLowerRes = streams.contains { $0.qualityRank == 1 || $0.qualityRank == 2 }
            let filtered = hasLowerRes ? streams.filter { $0.qualityRank != 3 } : streams
            return filtered.sorted { (lhs, rhs) in
                if lhs.qualityRank != rhs.qualityRank { return lhs.qualityRank < rhs.qualityRank }
                return lhs.sizeMb < rhs.sizeMb
            }
        }

        let czStreams = filteredAndSorted(groupedByLang["CZ"] ?? [])
        let otherLangStreams = groupedByLang.filter { $0.key != "CZ" }.flatMap { filteredAndSorted($0.value) }
        return czStreams + otherLangStreams
    }
}

