import Foundation

public struct Config: Codable, Equatable {
    public struct Pin: Codable, Equatable {
        /// Only a label: macOS hides the current SSID from the agent.
        public var ssid: String
        /// Identifies the network. Recorded when pinning, which is only allowed while on it.
        public var gatewayMAC: String

        public init(ssid: String, gatewayMAC: String) {
            self.ssid = ssid
            self.gatewayMAC = gatewayMAC
        }
    }

    public var pin: Pin?
    /// Gateway MACs of networks the user marked as hotspots.
    public var hotspotMACs: [String] = []
    public var paused = false

    public init() {}
}

/// Written by the agent on every tick; read by the CLI and the menu bar app.
public struct Status: Codable {
    public var updated: Date
    public var gateway: String?
    public var gatewayMAC: String?
    public var onHotspot: Bool
    public var awdlDown: Bool
    /// nil when nothing is pinned.
    public var onPin: Bool?
    public var lastEvent: String?

    /// The agent ticks every 10 seconds; anything much older means it is not running.
    public var isStale: Bool { Date().timeIntervalSince(updated) > 30 }
}

public enum Store {
    static let home = FileManager.default.homeDirectoryForCurrentUser
    public static let dir = home.appendingPathComponent("Library/Application Support/steadywifi")
    public static let logURL = home.appendingPathComponent("Library/Logs/steadywifi.log")
    static let configURL = dir.appendingPathComponent("config.json")
    static let statusURL = dir.appendingPathComponent("status.json")

    public static func loadConfig() -> Config {
        read(Config.self, from: configURL) ?? Config()
    }

    public static func updateConfig(_ change: (inout Config) -> Void) {
        var config = loadConfig()
        change(&config)
        write(config, to: configURL)
    }

    public static func loadStatus() -> Status? {
        read(Status.self, from: statusURL)
    }

    static func saveStatus(_ status: Status) {
        write(status, to: statusURL)
    }

    public static func log(_ message: String) {
        let line = "\(ISO8601DateFormatter().string(from: Date())) \(message)\n"
        if let handle = try? FileHandle(forWritingTo: logURL) {
            handle.seekToEndOfFile()
            handle.write(Data(line.utf8))
            try? handle.close()
        } else {
            try? FileManager.default.createDirectory(at: logURL.deletingLastPathComponent(), withIntermediateDirectories: true)
            try? Data(line.utf8).write(to: logURL)
        }
    }

    static func read<T: Decodable>(_ type: T.Type, from url: URL) -> T? {
        guard let data = try? Data(contentsOf: url) else { return nil }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try? decoder.decode(type, from: data)
    }

    static func write<T: Encodable>(_ value: T, to url: URL) {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        guard let data = try? encoder.encode(value) else { return }
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        try? data.write(to: url, options: .atomic)
    }
}
