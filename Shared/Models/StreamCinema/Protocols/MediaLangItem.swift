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
    var isCZLang: Bool {
        if let langs, langs.contains("CZ") {
            return true
        }
        return false
    }
    var langString: String? {
        guard let langs, !langs.isEmpty else { return nil }
        var arr = langs
        // Najdi jazyk CZ (case-insensitive) a dej jej na začátek
        if let idx = arr.firstIndex(where: { $0.caseInsensitiveCompare("CZ") == .orderedSame }) {
            let cz = arr.remove(at: idx)
            arr.insert(cz, at: 0)
        }
        return arr.joined(separator: ", ")
        
/*        if let first = arr.first, first.caseInsensitiveCompare("CZ") == .orderedSame {
            var note = String("♫ ")
            result.append(note)
            var czStr = String(first)
            result.append(czStr)
            if arr.count > 1 { result.append(", ") }
        }
        // Zbývající jazyky v defaultní barvě
        for (idx, lang) in arr.enumerated() where idx != 0 {
            result.append(lang)
            if idx < arr.count-1 { result.append(", ") }
        }
        
        return result*/
    }
}
