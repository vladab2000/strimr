//
//  ApiStreamResponse.swift
//  StreamCinema
//
//  Created by Vladimír Bárta on 21.02.2026.
//

struct ApiStreamResponse: Decodable {
    let input: String
    let ident: String
    let resolved: String
}
