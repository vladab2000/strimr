//
//  ResolvedStream.swift
//  Strimr
//

import Foundation

/// Odpověď /api/stream/resolve — přímá URL videa a externí titulky (např. Bombuj .vtt).
struct ResolvedStream: Codable {
    let url: String
    let subtitles: [ExternalSubtitle]?
    /// "hls" / "dash" u šifrovaného streamu (jinak podle url)
    let type: String?
    /// DRM (FairPlay pro AVPlayer) — licence a certifikát přes server
    let drm: StreamDrm?
}

/// Šifrovaný stream (OnePlay — tituly z limitu přehrání zdarma): adresy na našem serveru, relativní k jeho kořeni
struct StreamDrm: Codable, Hashable {
    /// "com.apple.fps" (FairPlay), "com.widevine.alpha" (jen web)
    let keySystem: String
    let licenseUrl: String
    let certificateUrl: String?

    var isFairPlay: Bool {
        keySystem == "com.apple.fps"
    }

    /// Absolutní adresa na serveru API (baseURL je …/api/, adresy začínají /api/…)
    func serverURL(_ path: String) -> URL? {
        URL(string: path, relativeTo: ApiClient.baseURL)?.absoluteURL
    }
}

struct ExternalSubtitle: Codable, Hashable {
    let url: String
    let label: String?
    /// ISO 639 kód jazyka (např. "cze")
    let lang: String?
    /// Zapnout titulky hned po načtení (stream s titulky, ne dabing)
    let isDefault: Bool
}
