import Foundation

enum SCItemType: String, Codable, Hashable {
    case video
    case tvshow
    case season
    case episode
    case folder
    case stream
    case unknown

    var isSupported: Bool {
        self != .unknown && self != .folder
    }
}
