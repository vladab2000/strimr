import OSLog

/// Logování do systémového logu (Console.app) místo print — debug zprávy se v release neukládají
enum Log {
    private static let subsystem = Bundle.main.bundleIdentifier ?? "Strimr"

    static let api = Logger(subsystem: subsystem, category: "api")
    static let epg = Logger(subsystem: subsystem, category: "epg")
    static let player = Logger(subsystem: subsystem, category: "player")
}
