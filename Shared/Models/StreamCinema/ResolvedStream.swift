//
//  ResolvedStream.swift
//  Strimr
//

import Foundation

/// Odpověď /api/stream/resolve — přímá URL videa a externí titulky (např. Bombuj .vtt).
struct ResolvedStream: Codable {
    let url: String
    let subtitles: [ExternalSubtitle]?
}

struct ExternalSubtitle: Codable, Hashable {
    let url: String
    let label: String?
    /// ISO 639 kód jazyka (např. "cze")
    let lang: String?
    /// Zapnout titulky hned po načtení (stream s titulky, ne dabing)
    let isDefault: Bool
}
