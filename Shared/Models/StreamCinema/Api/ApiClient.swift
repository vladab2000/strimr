//
//  ApiClient.swift
//  StreamCinema
//
//  Created by Vladimír Bárta on 21.02.2026.
//

import Foundation

struct ApiClient {
    static let baseURL = URL(string: "http://192.168.88.136:5020/api/")!
    
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
        decoder.dateDecodingStrategy = .iso8601
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
}
