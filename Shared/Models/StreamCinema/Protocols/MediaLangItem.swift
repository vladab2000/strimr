//
//  MediaLangItem.swift
//  BartTV
//
//  Created by Vladimír Bárta on 15.03.2026.
//

import Foundation
import SwiftUI


protocol MediaLangItem {
    var langs: [String]? { get }
}

extension MediaLangItem {
    var langString: AttributedString? {
        guard let langs, !langs.isEmpty else { return nil }
        var arr = langs
        // Najdi jazyk CZ (case-insensitive) a dej jej na začátek
        if let idx = arr.firstIndex(where: { $0.caseInsensitiveCompare("CZ") == .orderedSame }) {
            let cz = arr.remove(at: idx)
            arr.insert(cz, at: 0)
        }
        var result = AttributedString("")
        
        if let first = arr.first, first.caseInsensitiveCompare("CZ") == .orderedSame {
            var note = AttributedString("♫ ")
            note.foregroundColor = .yellow
            result.append(note)
            var czStr = AttributedString(first)
            czStr.foregroundColor = .yellow
            czStr.font = .boldSystemFont(ofSize: 25)
            result.append(czStr)
            if arr.count > 1 { result.append(AttributedString(", ")) }
        }
        // Zbývající jazyky v defaultní barvě
        for (idx, lang) in arr.enumerated() where idx != 0 {
            result.append(AttributedString(lang))
            if idx < arr.count-1 { result.append(AttributedString(", ")) }
        }
        
        return result
    }
}
