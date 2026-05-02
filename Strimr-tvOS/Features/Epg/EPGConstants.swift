import CoreFoundation

enum EPGConstants {
    static let pointsPerMinute: CGFloat = 15.0
    static let rowHeight: CGFloat = 80.0
    static let rowSpacing: CGFloat = 4.0
    static let cellSpacing: CGFloat = 4.0
    static let channelSidebarWidth: CGFloat = 250.0
    static let timelineHeight: CGFloat = 60.0
    static let visibleRows: Int = 7

    /// Výška viditelné části mřížky bez časové osy (přesně visibleRows celých řádků).
    static var gridHeight: CGFloat { CGFloat(visibleRows) * (rowHeight + rowSpacing) }

    /// Celková výška EPG sekce včetně časové osy.
    static var epgHeight: CGFloat { timelineHeight + gridHeight }
}
