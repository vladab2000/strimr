//
//  MediaItem.swift
//  BartTV
//
//  Created by Vladimír Bárta on 26.02.2026.
//

import Foundation

protocol MediaItem: Identifiable, Decodable {
    var id: String { get }
    var name: String { get }
    var type: String { get }
    var description: String? { get }
    var url: String? { get }
    var art: Art? { get }
}

extension MediaItem {
    
    var thumbURL: URL? {
        guard let thumb = art?.thumb, !thumb.isEmpty else { return nil }
        return URL(string: "\(thumb)")
    }
    
    var posterURL: URL? {
        guard let thumb = art?.poster ?? art?.thumb, !thumb.isEmpty else { return nil }
        return URL(string: thumb)
    }

}
