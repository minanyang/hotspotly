import CoreWLAN
import Foundation

public enum Net {
    /// iPhone Personal Hotspot always hands out 172.20.10.0/28 with itself as the router.
    public static let iPhoneGateway = "172.20.10.1"

    public static let wifiDevice: String = {
        // "Hardware Port: Wi-Fi\nDevice: en0" — not always en0 on every Mac.
        let lines = sh("/usr/sbin/networksetup", ["-listallhardwareports"]).output.components(separatedBy: "\n")
        if let i = lines.firstIndex(of: "Hardware Port: Wi-Fi"), i + 1 < lines.count,
           lines[i + 1].hasPrefix("Device: ") {
            return String(lines[i + 1].dropFirst("Device: ".count))
        }
        return "en0"
    }()

    public static func router() -> String? {
        let result = sh("/usr/sbin/ipconfig", ["getoption", wifiDevice, "router"])
        return result.status == 0 && !result.output.isEmpty ? result.output : nil
    }

    public static func ping(_ ip: String) -> Bool {
        sh("/sbin/ping", ["-c", "1", "-t", "2", ip]).status == 0
    }

    public struct Probe {
        public let sent: Int
        public let received: Int
        /// Average round trip of the replies in milliseconds; nil when none came back.
        public let averageMs: Double?
    }

    /// A few pings in a row, so loss can be measured as well; takes about a second.
    public static func probe(_ ip: String, count: Int = 3) -> Probe {
        let lines = sh("/sbin/ping", ["-c", "\(count)", "-i", "0.3", "-t", "2", ip]).output.components(separatedBy: "\n")
        // "3 packets transmitted, 3 packets received, 0.0% packet loss"
        let counts = lines.first { $0.contains("packets received") }?
            .components(separatedBy: ", ").compactMap { Int($0.prefix { $0.isNumber }) } ?? []
        // "round-trip min/avg/max/stddev = 3.305/4.678/8.889/2.103 ms"
        let average = lines.first { $0.hasPrefix("round-trip") }?
            .components(separatedBy: " = ").last?.components(separatedBy: "/").dropFirst().first.flatMap(Double.init)
        return Probe(sent: counts.first ?? count, received: counts.count > 1 ? counts[1] : 0, averageMs: average)
    }

    /// The router's MAC from the ARP cache. Unlike the SSID, macOS does not redact it.
    public static func mac(of ip: String) -> String? {
        // "? (172.20.10.1) at 12:34:56:78:9a:bc on en0 ifscope [ethernet]"
        let parts = sh("/usr/sbin/arp", ["-n", ip]).output.components(separatedBy: " ")
        guard let at = parts.firstIndex(of: "at"), at + 1 < parts.count else { return nil }
        let mac = parts[at + 1]
        return mac.contains(":") ? mac : nil
    }

    /// nil without location access, which macOS requires for the name; the menu bar app has it,
    /// `hotspotly run` does not.
    public static func ssid() -> String? {
        CWWiFiClient.shared().interface()?.ssid()
    }

    public static func rssi() -> Int? {
        CWWiFiClient.shared().interface().map { $0.rssiValue() }.flatMap { $0 == 0 ? nil : $0 }
    }

    /// Bytes received plus sent on the Wi-Fi interface since boot. netstat shows the 64-bit counters;
    /// getifaddrs only has 32-bit ones, which wrap at 4 GB.
    public static func wifiBytes() -> Int64? {
        // "en0 1500 <Link#14> 2e:01:… 15115000 0 14564809521 8046936 0 3548742692 0"
        guard let line = sh("/usr/sbin/netstat", ["-ib", "-I", wifiDevice]).output
            .components(separatedBy: "\n").first(where: { $0.contains("<Link#") }) else { return nil }
        // Counted from the end: the address column can be empty.
        let fields = line.split(separator: " ")
        guard fields.count >= 6, let received = Int64(fields[fields.count - 5]),
              let sent = Int64(fields[fields.count - 2]) else { return nil }
        return received + sent
    }

    public struct RememberedNetwork {
        public let ssid: String
        public let security: CWSecurity
    }

    /// The networks macOS remembers, in its auto-join order. Unlike the current SSID these names
    /// need no location access.
    public static func rememberedNetworks() -> [RememberedNetwork] {
        let profiles = CWWiFiClient.shared().interface()?.configuration()?.networkProfiles.array as? [CWNetworkProfile] ?? []
        return profiles.compactMap { profile in
            profile.ssid.map { RememberedNetwork(ssid: $0, security: profile.security) }
        }
    }

    public static func awdlIsUp() -> Bool {
        let firstLine = sh("/sbin/ifconfig", ["awdl0"]).output.components(separatedBy: "\n").first ?? ""
        return firstLine.contains("<UP")
    }

    /// Needs the sudoers rule that Setup installs; `-n` fails instead of prompting.
    public static func setAWDL(up: Bool) -> Bool {
        sh("/usr/bin/sudo", ["-n", "/sbin/ifconfig", "awdl0", up ? "up" : "down"]).status == 0
    }

    public static func preferredNetworks() -> [String] {
        // First line is the "Preferred networks on en0:" header.
        sh("/usr/sbin/networksetup", ["-listpreferredwirelessnetworks", wifiDevice]).output
            .components(separatedBy: "\n")
            .dropFirst()
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
    }

    /// Joins `ssid` and returns its gateway's MAC, or the error. It drops the current network
    /// before trying, and on failure macOS auto-join picks some network, so only run it on request.
    public static func join(_ ssid: String, password: String) -> Result<String, JoinError> {
        let args = ["-setairportnetwork", wifiDevice, ssid] + (password.isEmpty ? [] : [password])
        let output = sh("/usr/sbin/networksetup", args).output
        // networksetup prints nothing on success; anything else (e.g. "Error: -3900") is a failure,
        // even if the Mac lands on some network afterwards.
        guard output.isEmpty else { return .failure(JoinError(message: output)) }
        for _ in 0..<20 {
            if let gateway = router(), ping(gateway), let mac = mac(of: gateway) { return .success(mac) }
            Thread.sleep(forTimeInterval: 1)
        }
        return .failure(JoinError(message: "joined '\(ssid)' but got no gateway within 20 seconds"))
    }

    public struct JoinError: Error, CustomStringConvertible {
        public let message: String
        public var description: String { message }
        /// networksetup scanned and did not see the network, so it never touched the current connection.
        public var networkNotFound: Bool { message.hasPrefix("Could not find network") }
    }
}
