import Foundation

/// Why the Mac lost a network, as far as the system log tells.
public enum DropCause: String, Codable {
    /// The phone or router sent a deauthentication or disassociation, e.g. a hotspot turned off.
    case networkEnded
    /// The Mac stopped hearing the network: out of range, or the signal faded.
    case signalLost
    /// The Mac moved to another network without either of the above.
    case switched
    case slept
    case unknown
}

public struct Drop: Codable {
    public var start: Date
    /// nil until the Mac is on a network again.
    public var end: Date?
    public var network: String
    public var hotspot: Bool
    public var cause: DropCause = .unknown
    /// The IEEE 802.11 reason code that came with a deauthentication.
    public var reason: Int?
}

/// Keepalive rounds on one network while AWDL was either up or down.
public struct RoundStats: Codable {
    public var rounds = 0
    public var sent = 0
    public var received = 0
    public var roundTripMs = 0.0
    /// Rounds that lost a ping or averaged 150 ms or more.
    public var slowRounds = 0
    public var drops = 0

    public init() {}

    /// Below this, a comparison says more about chance than about AWDL.
    public static let enoughRounds = 30

    public var latencyMs: Double? { received > 0 ? roundTripMs / Double(received) : nil }
    public var packetLoss: Double? { sent > 0 ? 1 - Double(received) / Double(sent) : nil }
    public var slowShare: Double? { rounds > 0 ? Double(slowRounds) / Double(rounds) : nil }
    /// Rounds are 10 seconds apart.
    public var dropsPerHour: Double? { rounds > 0 ? Double(drops) / (Double(rounds) * 10 / 3600) : nil }

    mutating func add(_ probe: Net.Probe) {
        rounds += 1
        sent += probe.sent
        received += probe.received
        roundTripMs += (probe.averageMs ?? 0) * Double(probe.received)
        if probe.received < probe.sent || (probe.averageMs ?? 0) >= 150 { slowRounds += 1 }
    }

    public static func + (a: RoundStats, b: RoundStats) -> RoundStats {
        var sum = a
        sum.rounds += b.rounds
        sum.sent += b.sent
        sum.received += b.received
        sum.roundTripMs += b.roundTripMs
        sum.slowRounds += b.slowRounds
        sum.drops += b.drops
        return sum
    }
}

public struct NetworkInsights: Codable {
    public var hotspot: Bool
    public var awdlOn = RoundStats()
    public var awdlOff = RoundStats()
}

/// What the Insights tab shows: how each network behaved with AWDL up and down, why it dropped,
/// and what Hotspotly did about it. Kept on this Mac only.
public struct Insights: Codable {
    public var since = Date()
    /// Keyed by network name, or the gateway's MAC when the name is hidden.
    public var networks: [String: NetworkInsights] = [:]
    public var drops: [Drop] = []
    /// Times Hotspotly took AWDL down after macOS brought it up.
    public var awdlBlocked = 0
    /// Times pinning brought the Mac back.
    public var rejoins = 0

    public init() {}

    static let keptDrops = 200
}

/// Reads why Wi-Fi dropped from the kernel's messages, which `log show` returns without root.
/// macOS keeps them for about a day, so this runs when the drop ends.
enum SystemLog {
    static func dropCause(from start: Date, to end: Date) -> (DropCause, Int?)? {
        let format = DateFormatter()
        format.dateFormat = "yyyy-MM-dd HH:mm:ss"
        let lines = sh("/usr/bin/log", [
            "show", "--style", "compact",
            "--start", format.string(from: start), "--end", format.string(from: end),
            "--predicate", #"process == "kernel" AND (eventMessage CONTAINS "handleDeauthDisassoc@" OR eventMessage CONTAINS "roamed due to lost beacons")"#,
        ]).output.components(separatedBy: "\n")
        return cause(in: lines)
    }

    /// "… handleDeauthDisassoc@166:Reason: Deauth,   IEEE reason = 3, addr = c2:58:…"
    /// "… handleRoam@977:status = 3 failed …, reason = 4 roamed due to lost beacons, …"
    static func cause(in lines: [String]) -> (DropCause, Int?)? {
        if let line = lines.last(where: { $0.contains("handleDeauthDisassoc@") }) {
            let reason = line.components(separatedBy: "IEEE reason = ").dropFirst().first
                .flatMap { Int($0.prefix { $0.isNumber }) }
            return (.networkEnded, reason)
        }
        if lines.contains(where: { $0.contains("roamed due to lost beacons") }) { return (.signalLost, nil) }
        return nil
    }
}
