//
//  ApiClient.swift
//  StreamCinema
//
//  Created by Vladimír Bárta on 21.02.2026.
//

import Foundation

struct ApiClient {
    static let baseURL = URL(string: "http://192.168.88.136:5001/api/")!
    
    static func fetchMenu(urlPath: String = "/") async throws -> ApiFolderResponse {
        let endpointUrl = URL(string: "\(baseURL)folder")!
        var components = URLComponents(url: endpointUrl, resolvingAgainstBaseURL: false)!
        components.queryItems = [URLQueryItem(name: "url", value: urlPath)]
        let url = components.url!
        
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            do {
                return try decoder.decode(ApiFolderResponse.self, from: data)
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

}
