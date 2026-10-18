import Foundation
import SteadyWiFiCore

let usage = """
    usage: steadywifi <command>

      status              show what the agent sees
      networks            list remembered Wi-Fi networks
      pin <ssid>          switch to <ssid> and pin it (asks for its password once)
      pin --here <ssid>   pin the network you are on now, named <ssid>, without switching
      unpin               stop holding a network
      mark-hotspot        treat the current network as a hotspot (iPhone hotspots are detected automatically)
      unmark-hotspot      stop treating the current network as a hotspot
      pause | resume      suspend or resume everything (e.g. to use AirDrop)
      install             start the agent at login and allow it to toggle awdl0
                          (as root, `install --user <name>` sets it up for that user)
      uninstall           remove the agent and the sudoers rule
      run                 run the agent in the foreground (what the LaunchAgent calls)
    """

func fail(_ message: String) -> Never {
    FileHandle.standardError.write(Data("steadywifi: \(message)\n".utf8))
    exit(1)
}

/// The LaunchAgent must point at a stable path (e.g. Homebrew's bin symlink), not wherever it resolves to.
func executablePath() -> String {
    let arg0 = CommandLine.arguments[0]
    if arg0.contains("/") {
        return URL(fileURLWithPath: arg0, relativeTo: URL(fileURLWithPath: FileManager.default.currentDirectoryPath))
            .standardizedFileURL.path
    }
    let which = Process()
    which.executableURL = URL(fileURLWithPath: "/usr/bin/which")
    which.arguments = [arg0]
    let pipe = Pipe()
    which.standardOutput = pipe
    try? which.run()
    which.waitUntilExit()
    return String(decoding: pipe.fileHandleForReading.readDataToEndOfFile(), as: UTF8.self)
        .trimmingCharacters(in: .whitespacesAndNewlines)
}

func printStatus() {
    let config = Store.loadConfig()
    guard let status = Store.loadStatus(), !status.isStale else {
        print("agent:    not running\(Installer.isInstalled ? "" : " (run `steadywifi install`)")")
        return
    }
    print("agent:    running\(config.paused ? ", paused" : "")")
    print("gateway:  \(status.gateway ?? "none") \(status.gatewayMAC.map { "(\($0))" } ?? "")")
    print("hotspot:  \(status.onHotspot ? "yes" : "no")")
    print("awdl0:    \(status.awdlDown ? "down" : "up")")
    if let pin = config.pin {
        let state = status.onPin.map { $0 ? "connected" : "away" } ?? "not checked while paused"
        print("pinned:   \(pin.ssid) (\(state))")
    } else {
        print("pinned:   none")
    }
    if let event = status.lastEvent { print("last:     \(event)") }
    print("log:      \(Store.logURL.path)")
}

func currentGatewayMAC() -> String {
    guard let gateway = Net.router() else { fail("not connected to a Wi-Fi network") }
    _ = Net.ping(gateway)
    guard let mac = Net.mac(of: gateway) else { fail("cannot read the gateway's MAC address") }
    return mac
}

/// Prompts on the terminal without echo; nil without a terminal.
func readPassword(_ prompt: String) -> String? {
    var buffer = [CChar](repeating: 0, count: 256)
    guard let line = readpassphrase(prompt, &buffer, buffer.count, RPP_REQUIRE_TTY) else { return nil }
    return String(cString: line)
}

let args = Array(CommandLine.arguments.dropFirst())
switch args.first {
case "run":
    Agent().run()
case "status", nil:
    printStatus()
case "networks":
    let pinned = Store.loadConfig().pin?.ssid
    for ssid in Net.preferredNetworks() { print("\(ssid == pinned ? "*" : " ") \(ssid)") }
case "pin":
    let here = args.count == 3 && args[1] == "--here"
    guard args.count == 2 || here else { fail("usage: steadywifi pin [--here] <ssid>") }
    let ssid = args[args.count - 1]
    guard Net.preferredNetworks().contains(ssid) else {
        fail("'\(ssid)' is not a remembered network; join it once in System Settings first")
    }
    let mac: String
    if here {
        mac = currentGatewayMAC()
    } else {
        let saved = Keychain.password(for: ssid)
        guard let password = saved ?? readPassword("Wi-Fi password for '\(ssid)' (empty if open): ") else {
            fail("cannot read the password; run this in a terminal")
        }
        print("switching to '\(ssid)'…")
        switch Net.join(ssid, password: password) {
        case .success(let joined):
            mac = joined
            // Saved only after it worked, so a mistyped password is asked for again next time.
            if saved == nil { Keychain.save(password, for: ssid) }
        case .failure(let error):
            fail("could not switch to '\(ssid)': \(error)")
        }
    }
    Store.updateConfig { $0.pin = Config.Pin(ssid: ssid, gatewayMAC: mac) }
    print("pinned '\(ssid)' (gateway \(mac))")
case "unpin":
    Store.updateConfig { $0.pin = nil }
case "mark-hotspot":
    let mac = currentGatewayMAC()
    Store.updateConfig { if !$0.hotspotMACs.contains(mac) { $0.hotspotMACs.append(mac) } }
    print("marked gateway \(mac) as a hotspot")
case "unmark-hotspot":
    let mac = currentGatewayMAC()
    Store.updateConfig { $0.hotspotMACs.removeAll { $0 == mac } }
case "pause":
    Store.updateConfig { $0.paused = true }
case "resume":
    Store.updateConfig { $0.paused = false }
case "install":
    var user: String?
    if args.count == 3 && args[1] == "--user" {
        user = args[2]
    } else if args.count != 1 {
        fail("usage: steadywifi install [--user <name>]")
    }
    do {
        try Installer.install(executable: executablePath(), user: user)
        print("installed; the agent is running")
    } catch {
        fail("\(error)")
    }
case "uninstall":
    Installer.uninstall()
    print("uninstalled")
case "-h", "--help", "help":
    print(usage)
default:
    fail("unknown command '\(args[0])'\n\n\(usage)")
}
