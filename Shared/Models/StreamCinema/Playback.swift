import Foundation

struct Playback: Codable {
    let sessionId: String
    let playbackUrl: String
    let kind: Int?
    let type: Int?
    let providerType: Int?
    let isEncoded: Bool?
    let start: Date?
    let end: Date?
}
