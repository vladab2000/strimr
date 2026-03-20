//
//  Folder.swift
//  StreamCinema
//
//  Created by Vladimír Bárta on 21.02.2026.
//

struct Folder: MediaItem {
    let id: String
    let name: String
    let type: String //= "folder"
    let description: String?
    let url: String?
    let art: Art?
}


