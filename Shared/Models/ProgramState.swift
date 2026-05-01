//
//  ProgramState.swift
//  Strimr
//
//  Created by Vladimír Bárta on 26.04.2026.
//

import SwiftUI

enum ProgramState {
    case past, current, future
    
    var color: UIColor {
        switch self {
        case .past:
            return UIColor.gray.withAlphaComponent(0.4)
        case .current:
            return UIColor.green.withAlphaComponent(0.7)
        case .future:
            return UIColor.blue.withAlphaComponent(0.6)
        }
    }
}
