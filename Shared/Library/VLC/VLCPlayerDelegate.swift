import Foundation

#if canImport(UIKit)
@MainActor
protocol VLCPlayerDelegate: AnyObject {
    func propertyChange(player: VLCPlayerViewController, property: PlayerProperty, data: Any?)
    func fileLoaded()
    func playbackEnded()
}
#endif
