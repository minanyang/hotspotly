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

    /// The router's MAC from the ARP cache. Unlike the SSID, macOS does not redact it.
    public static func mac(of ip: String) -> String? {
        // "? (172.20.10.1) at 12:34:56:78:9a:bc on en0 ifscope [ethernet]"
        let parts = sh("/usr/sbin/arp", ["-n", ip]).output.components(separatedBy: " ")
        guard let at = parts.firstIndex(of: "at"), at + 1 < parts.count else { return nil }
        let mac = parts[at + 1]
        return mac.contains(":") ? mac : nil
    }

    public static func awdlIsUp() -> Bool {
        let firstLine = sh("/sbin/ifconfig", ["awdl0"]).output.components(separatedBy: "\n").first ?? ""
        return firstLine.contains("<UP")
    }

    /// Needs the sudoers rule that `steadywifi install` adds; `-n` fails instead of prompting.
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
