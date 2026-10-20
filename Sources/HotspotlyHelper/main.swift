import Foundation
import HotspotlyCore

/// Runs as root, started by launchd when Hotspotly.app connects. It exits once the app has gone,
/// so after an update the next connection starts the new binary.
final class Service: NSObject, HelperProtocol {
    func version(reply: @escaping (String) -> Void) {
        reply(Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "?")
    }

    func setAWDL(up: Bool, reply: @escaping (Bool) -> Void) {
        reply(run("/sbin/ifconfig", ["awdl0", up ? "up" : "down"]))
    }

    func forget(_ ssids: [String], reply: @escaping (String) -> Void) {
        // An SSID is at most 32 bytes; anything else did not come from the Networks tab.
        guard ssids.allSatisfy({ !$0.isEmpty && $0.utf8.count <= 32 && !$0.contains("\0") }) else {
            return reply("not a network name")
        }
        let failed = ssids.filter {
            !run("/usr/sbin/networksetup", ["-removepreferredwirelessnetwork", Net.wifiDevice, $0])
        }
        reply(failed.isEmpty ? "" : "could not forget \(failed.joined(separator: ", "))")
    }

    /// The link always points into this app bundle; the caller does not choose the target.
    func linkCLI(_ link: Bool, reply: @escaping (Bool) -> Void) {
        let files = FileManager.default
        let target = Bundle.main.bundleURL.appendingPathComponent("Contents/MacOS/hotspotly").path
        try? files.removeItem(atPath: Setup.cliLinkPath)
        guard link else { return reply(true) }
        do {
            try files.createDirectory(atPath: "/usr/local/bin", withIntermediateDirectories: true)
            try files.createSymbolicLink(atPath: Setup.cliLinkPath, withDestinationPath: target)
            reply(true)
        } catch {
            reply(false)
        }
    }

    func removeLegacyRule(reply: @escaping (Bool) -> Void) {
        let files = FileManager.default
        guard files.fileExists(atPath: Setup.sudoersPath) else { return reply(true) }
        reply((try? files.removeItem(atPath: Setup.sudoersPath)) != nil)
    }

    /// Arguments go straight to the program, never through a shell.
    func run(_ path: String, _ arguments: [String]) -> Bool {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: path)
        process.arguments = arguments
        do { try process.run() } catch { return false }
        process.waitUntilExit()
        return process.terminationStatus == 0
    }
}

final class Listener: NSObject, NSXPCListenerDelegate {
    let service = Service()
    var connections = 0

    func listener(_ listener: NSXPCListener, shouldAcceptNewConnection connection: NSXPCConnection) -> Bool {
        connection.setCodeSigningRequirement(Helper.clientRequirement)
        connection.exportedInterface = Helper.interface
        connection.exportedObject = service
        connection.invalidationHandler = { [weak self] in
            DispatchQueue.main.async { self?.closed() }
        }
        DispatchQueue.main.async { self.connections += 1 }
        connection.resume()
        return true
    }

    /// launchd starts the helper again on the next connection.
    func closed() {
        connections -= 1
        if connections <= 0 { exit(0) }
    }
}

let delegate = Listener()
let listener = NSXPCListener(machServiceName: Helper.label)
listener.delegate = delegate
listener.resume()
RunLoop.main.run()
