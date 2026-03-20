//
//  Stream.swift
//  StreamCinema
//
//  Created by Vladimír Bárta on 21.02.2026.
//

import Foundation

struct Stream: MediaItem, MediaLangItem {
    var id: String { url ?? ""}
    let type: String //= "stream"
    let name: String
    let description: String?
    let url: String?
    let art: Art?
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

}
