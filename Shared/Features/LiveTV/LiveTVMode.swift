import Foundation

enum LiveTVMode: String, CaseIterable, Identifiable {
    case channels
    case tvGuide

    var id: String { rawValue }

    var titleKey: String {
        switch self {
        case .channels: return "livetv.mode.channels"
        case .tvGuide: return "livetv.mode.tvGuide"
        }
    }
}
