//
//  ApiClient.swift
//  StreamCinema
//
//  Created by Vladimír Bárta on 21.02.2026.
//

import Foundation

struct ApiClient {
    static let baseURL = URL(string: "http://192.168.88.136:5001/api/")!
    
    static func fetchMenu(urlPath: String = "/") async throws -> [Media] {
        let endpointUrl = URL(string: "\(baseURL)folder")!
        var components = URLComponents(url: endpointUrl, resolvingAgainstBaseURL: false)!
        components.queryItems = [URLQueryItem(name: "url", value: urlPath)]
        let url = components.url!
        
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            do {
                return try decoder.decode([Media].self, from: data)
            } catch {
                if let jsonString = String(data: data, encoding: .utf8) {
                    print("Chyba při deserializaci adresáře, data z API:")
                    print(jsonString)
                } else {
                    print("Chyba při deserializaci adresáře, data nejsou validní UTF-8.")
                }
                throw error
            }
        } catch {
            print("Chyba během síťového požadavku na \(url): \(error)")
            throw error
        }
    }
    
    static func fetchStream(urlPath: String = "/") async throws -> ApiStreamResponse {
        let endpointUrl = URL(string: "\(baseURL)stream")!
        var components = URLComponents(url: endpointUrl, resolvingAgainstBaseURL: false)!
        components.queryItems = [URLQueryItem(name: "url", value: urlPath)]
        let url = components.url!
        
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            do {
                return try decoder.decode(ApiStreamResponse.self, from: data)
            } catch {
                if let jsonString = String(data: data, encoding: .utf8) {
                    print("Chyba při deserializaci streamu, data z API:")
                    print(jsonString)
                } else {
                    print("Chyba při deserializaci streamu, data nejsou validní UTF-8.")
                }
                throw error
            }
        } catch {
            print("Chyba během síťového požadavku na \(url): \(error)")
            throw error
        }
    }

    // MARK: - Watch History

    static func fetchContinueWatching() async throws -> [Media] {
        let url = URL(string: "\(baseURL)watch/continue")!
        
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            do {
                return try decoder.decode([Media].self, from: data)
            } catch {
                if let jsonString = String(data: data, encoding: .utf8) {
                    print("Chyba při deserializaci continue watching data z API:")
                    print(jsonString)
                } else {
                    print("Chyba při deserializaci continue watching, data nejsou validní UTF-8.")
                }
                throw error
                
            }
        } catch {
            print("Chyba během síťového požadavku na \(url): \(error)")
            throw error
        }

    }

    static func createWatchRecord(
        media: Media
    ) async throws {
        let url = URL(string: "\(baseURL)watch/create")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        request.httpBody = try JSONEncoder().encode(media)
        let (_, _) = try await URLSession.shared.data(for: request)
    }

    static func updateWatchPosition(
        mediaUrl: String,
        season: Int? = nil,
        episode: Int? = nil,
        position: Int,
        watched: Bool? = nil
    ) async throws {
        let url = URL(string: "\(baseURL)watch/update")!
        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        var body: [String: Any] = [
            "url": mediaUrl,
            "position": position,
        ]
        if let season { body["season"] = season }
        if let episode { body["episode"] = episode }
        if let watched { body["watched"] = watched }

        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        let (_, _) = try await URLSession.shared.data(for: request)
    }

}
