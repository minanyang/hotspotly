import Foundation

public struct Config: Codable, Equatable {
    public enum AWDLMode: String, Codable {
        case hotspots, all, never
    }

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
    /// Network names for `hotspotMACs`, when known; only the menu bar app can read them.
    public var hotspotNames: [String: String] = [:]
    public var paused = false
    /// Where to turn AWDL off. Some prefer to keep Universal Control and friends.
    public var awdlMode = AWDLMode.hotspots
    /// Leaves AWDL alone until then, e.g. to use AirDrop on a hotspot for a few minutes.
    public var awdlAllowedUntil: Date?

    public var awdlAllowed: Bool { awdlAllowedUntil.map { $0 > Date() } == true }

    /// Whether the current network is one where AWDL should be off, before pause and allowance.
    public func turnsOffAWDL(onHotspot: Bool) -> Bool {
        awdlMode == .all || (awdlMode == .hotspots && onHotspot)
    }

    public init() {}

    /// Missing keys keep their defaults, so a config written by an older version still loads;
    /// a failed decode would fall back to `Config()` and lose the pin.
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        pin = try c.decodeIfPresent(Pin.self, forKey: .pin)
        hotspotMACs = try c.decodeIfPresent([String].self, forKey: .hotspotMACs) ?? hotspotMACs
        hotspotNames = try c.decodeIfPresent([String: String].self, forKey: .hotspotNames) ?? hotspotNames
        paused = try c.decodeIfPresent(Bool.self, forKey: .paused) ?? paused
        awdlMode = try c.decodeIfPresent(AWDLMode.self, forKey: .awdlMode) ?? awdlMode
        awdlAllowedUntil = try c.decodeIfPresent(Date.self, forKey: .awdlAllowedUntil)
    }
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
    /// Over the last minute of keepalive pings; nil without a gateway or before the first reply.
    public var latencyMs: Double?
    /// 0...1 over the last minute of keepalive pings; nil without a gateway.
    public var packetLoss: Double?
    /// No reply to the last two rounds of keepalive pings.
    public var gatewaySilent = false
    /// Sent and received over Wi-Fi since joining the current hotspot; nil off a hotspot.
    public var hotspotBytes: Int64?
    /// The Wi-Fi byte count when the Mac joined the hotspot, so a restart keeps counting from there.
    public var hotspotStartBytes: Int64?

    /// The agent ticks every 10 seconds; anything much older means it is not running.
    public var isStale: Bool { Date().timeIntervalSince(updated) > 30 }
}

/// What Hotspotly has seen of one network since it was installed. macOS keeps its own join dates,
/// but only root with Full Disk Access can read them.
public struct NetworkRecord: Codable {
    public var lastConnected: Date
    public var sent = 0
    public var received = 0
    /// Sum over the received replies, so the average stays exact as rounds add up.
    public var roundTripMs = 0.0
    public var rssiSum = 0
    public var rssiCount = 0
    /// Times the router stopped answering keepalive pings.
    public var dropouts = 0

    public var latencyMs: Double? { received > 0 ? roundTripMs / Double(received) : nil }
    public var packetLoss: Double? { sent > 0 ? 1 - Double(received) / Double(sent) : nil }
    public var rssi: Int? { rssiCount > 0 ? rssiSum / rssiCount : nil }
}

public enum Store {
    static let home = FileManager.default.homeDirectoryForCurrentUser
    public static let dir = home.appendingPathComponent("Library/Application Support/hotspotly")
    public static let logURL = home.appendingPathComponent("Library/Logs/hotspotly.log")
    static let configURL = dir.appendingPathComponent("config.json")
    static let statusURL = dir.appendingPathComponent("status.json")
    static let historyURL = dir.appendingPathComponent("history.json")

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

    /// Keyed by network name, to match the list of networks macOS remembers.
    public static func loadHistory() -> [String: NetworkRecord] {
        read([String: NetworkRecord].self, from: historyURL) ?? [:]
    }

    public static func updateHistory(_ change: (inout [String: NetworkRecord]) -> Void) {
        var history = loadHistory()
        change(&history)
        write(history, to: historyURL)
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
