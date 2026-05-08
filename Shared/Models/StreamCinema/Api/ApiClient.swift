//
//  ApiClient.swift
//  StreamCinema
//
//  Created by Vladimír Bárta on 21.02.2026.
//

import Foundation

struct ApiClient {
    static let baseURL = URL(string: "http://192.168.88.136:5020/api/")!
    //static let baseURL = URL(string: "https://tv.lan.mujrd.cz:5020/api/")!

    static func fetchMenu(urlPath: String = "/") async throws -> [Media] {
        try await fetch(path: "folder", queryItems: [URLQueryItem(name: "url", value: urlPath)])
    }
    
    static func fetchStream(urlPath: String = "/") async throws -> String {
        try await fetch(path: "stream", queryItems: [URLQueryItem(name: "url", value: urlPath)])
    }

    // MARK: - Search

    static func fetchSearch(text: String, type: String) async throws -> [Media] {
        try await fetch(path: "search", queryItems: [
            URLQueryItem(name: "text", value: text),
            URLQueryItem(name: "type", value: type)
        ])
    }

    // MARK: - Watch History

    static func fetchContinueWatching() async throws -> [Media] {
        try await fetch(path: "watch")
    }

    static func createWatch(media: Media) async throws {
        try await performRequest(path: "watch/create", method: "POST", body: media)
    }


    static func updateWatch(media: Media, position: Int? = nil, watched: Bool? = nil) async throws {
        var updatedMedia = media
        updatedMedia.watchPosition = position
        updatedMedia.watchCompleted = watched

        try await performRequest(path: "watch/update", method: "POST", body: updatedMedia)
    }

    static func removeWatch(media: Media) async throws {
        try await performRequest(path: "watch/remove", method: "POST", body: media)
    }

    // MARK: - Favorites

    static func fetchFavorites() async throws -> [Media] {
        try await fetch(path: "favorites")
    }

    static func addFavorite(media: Media) async throws {
        try await performRequest(path: "favorites/add", method: "POST", body: media)
    }

    static func removeFavorite(media: Media) async throws {
        try await performRequest(path: "favorites/remove", method: "POST", body: media)
    }

    // MARK: - TV Program Search

    static func fetchProgramSearch(text: String, providerType: ProviderType) async throws -> [Media] {
        let encoded = text.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? text
        return try await fetch(
            path: "tv/programs/search/\(encoded)",
            queryItems: [URLQueryItem(name: "providerType", value: String(providerType.rawValue))]
        )
    }

    // MARK: - TV Channels

    static func fetchCategories() async throws -> [ChannelCategory] {
        try await fetch(path: "tv/categories")
    }

    static func fetchChannels(providerType: ProviderType, categoryId: Int? = nil, favorites: Bool = false) async throws -> [Media] {
        var queryItems = [
            URLQueryItem(name: "providerType", value: String(providerType.rawValue)),
        ]
        if let categoryId {
            queryItems.append(URLQueryItem(name: "categoryId", value: String(categoryId)))
        }
        if favorites {
            queryItems.append(URLQueryItem(name: "favorites", value: "true"))
        }
        return try await fetch(path: "tv/channels", queryItems: queryItems)
    }

    static func fetchLiveStream(channelId: String, providerType: ProviderType? = nil) async throws -> Playback {
        var queryItems: [URLQueryItem] = []
        if let providerType {
            queryItems.append(URLQueryItem(name: "providerType", value: String(providerType.rawValue)))
        }
        return try await fetch(path: "tv/channels/\(channelId)/live", queryItems: queryItems.isEmpty ? nil : queryItems)
    }

    static func fetchAllPrograms(channelId: String) async throws -> [Media] {
        try await fetch(path: "tv/channels/\(channelId)/programs")
    }

    static func fetchProgramsForDate(channelId: String, date: Date) async throws -> [Media] {
        try await fetch(path: "tv/channels/\(channelId)/programs/\(dateString(for: date))")
    }
/*
    static func fetchPrograms(channelId: String, from: String, to: String) async throws -> [Media] {
        try await fetch(path: "channels/\(channelId)/programs/\(from)/\(to)")
    }
*/
    static func fetchNowNext(channelId: String) async throws -> [Media] {
        try await fetch(path: "tv/channels/\(channelId)/now-next")
    }

    static func fetchArchiveStream(channelId: String, programId: String) async throws -> Playback {
        try await fetch(path: "tv/channels/\(channelId)/archive/\(programId)")
    }

    // MARK: - Playback

    static func playbackURL(sessionId: String) -> URL {
        URL(string: "\(baseURL)tv/playback/\(sessionId).m3u8")!
    }

    // MARK: - Keepalive

    static func sendKeepalive(sessionId: String) async {
        let url = URL(string: "\(baseURL)tv/keepalive/\(sessionId)")!
        do {
            let (_, response) = try await URLSession.shared.data(from: url)
            if let http = response as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
                debugPrint("Keepalive HTTP \(http.statusCode)")
            }
        } catch {
            debugPrint("Keepalive failed:", error)
        }
    }

    private static func fetch<T: Decodable>(path: String, queryItems: [URLQueryItem]? = nil) async throws -> T {
        // Sestavení URL s parametry
        var components = URLComponents(string: "\(baseURL)\(path)")!
        components.queryItems = queryItems
        guard let url = components.url else { throw URLError(.badURL) }

        let (data, response) = try await URLSession.shared.data(from: url)
        
        // Kontrola HTTP statusu
        guard let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) else {
            throw URLError(.badServerResponse)
        }

        // Speciální případ pro String (např. fetchStream)
        if T.self == String.self {
            if let decodedString = String(data: data, encoding: .utf8) {
                return decodedString as! T
            }
            throw URLError(.cannotDecodeContentData)
        }

        // Standardní JSON dekódování
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom(Self.decodeDate)
        do {
            return try decoder.decode(T.self, from: data)
        } catch {
            print("Chyba dekódování na \(path): \(String(data: data, encoding: .utf8) ?? "no data")")
            throw error
        }
    }
    
    private static func performRequest(path: String, method: String, body: Media? = nil) async throws {
        let url = URL(string: "\(baseURL)\(path)")!
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        // Společné nastavení pro kódování (shodné s vaším API)
        if let body = body {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            request.httpBody = try encoder.encode(body)
        }

        let (data, response) = try await URLSession.shared.data(for: request)

        // Jednotná kontrola chyb
        guard let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) else {
            let statusCode = (response as? HTTPURLResponse)?.statusCode ?? 0
            let errorMsg = String(data: data, encoding: .utf8) ?? "Neznámá chyba"
            print("API Error [\(statusCode)]: \(errorMsg)")
            throw URLError(.badServerResponse)
        }
    }

    // MARK: - Date Decoding

    private nonisolated static func decodeDate(from decoder: Decoder) throws -> Date {
        let container = try decoder.singleValueContainer()
        let string = try container.decode(String.self)

        // ISO 8601 with fractional seconds and Z
        let isoFractional = ISO8601DateFormatter()
        isoFractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = isoFractional.date(from: string) { return date }

        // ISO 8601 standard (no fractional seconds)
        let isoStandard = ISO8601DateFormatter()
        isoStandard.formatOptions = [.withInternetDateTime]
        if let date = isoStandard.date(from: string) { return date }

        // No timezone suffix — treat as UTC
        let df = DateFormatter()
        df.locale = Locale(identifier: "en_US_POSIX")
        df.timeZone = TimeZone(identifier: "UTC")

        // With fractional seconds, no Z
        df.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSSSS"
        if let date = df.date(from: string) { return date }

        df.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSS"
        if let date = df.date(from: string) { return date }

        // No fractional seconds, no Z
        df.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
        if let date = df.date(from: string) { return date }

        throw DecodingError.dataCorruptedError(
            in: container,
            debugDescription: "Cannot decode date from: \(string)"
        )
    }

    private static func postReturning<Body: Encodable, Response: Decodable>(
        path: String,
        body: Body
    ) async throws -> Response {
        let url = URL(string: "\(baseURL)\(path)")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        request.httpBody = try encoder.encode(body)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) else {
            let statusCode = (response as? HTTPURLResponse)?.statusCode ?? 0
            let errorMsg = String(data: data, encoding: .utf8) ?? "Neznámá chyba"
            print("API Error [\(statusCode)]: \(errorMsg)")
            throw URLError(.badServerResponse)
        }

        if Response.self == String.self {
            if let decodedString = String(data: data, encoding: .utf8) {
                return decodedString as! Response
            }
            throw URLError(.cannotDecodeContentData)
        }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom(Self.decodeDate)
        return try decoder.decode(Response.self, from: data)
    }
    
    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.locale = Locale(identifier: "en_US_POSIX")
        //f.timeZone = TimeZone(identifier: "UTC")
        return f
    }()

    private static func dateString(for date: Date) -> String {
        dateFormatter.string(from: date)
    }
}
