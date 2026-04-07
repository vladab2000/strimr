import Foundation

enum SCItemType: String, Codable, Hashable {
    case folder
    case movie
    case tvshow
    case season
    case episode
    case channel
    case program
    case stream
    case unknown

    var isSupported: Bool {
        switch self {
        case .unknown, .folder, .stream:
            false
        default:
            true
        }
    }

    // Server sends kind as Int: Folder=0, Movie=1, TvShow=2, Season=3, Episode=4, Channel=5, Program=6
    private static let intMapping: [Int: SCItemType] = [
        0: .folder,
        1: .movie,
        2: .tvshow,
        3: .season,
        4: .episode,
        5: .channel,
        6: .program,
    ]

    private static let toIntMapping: [SCItemType: Int] = {
        var result: [SCItemType: Int] = [:]
        for (key, value) in intMapping { result[value] = key }
        return result
    }()

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let intValue = try? container.decode(Int.self) {
            self = SCItemType.intMapping[intValue] ?? .unknown
        } else if let stringValue = try? container.decode(String.self) {
            self = SCItemType(rawValue: stringValue.lowercased()) ?? .unknown
        } else {
            self = .unknown
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        if let intValue = SCItemType.toIntMapping[self] {
            try container.encode(intValue)
        } else {
            try container.encode(rawValue)
        }
    }
}
