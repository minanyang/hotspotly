import Foundation
import HotspotlyCore

let usage = """
    usage: hotspotly <command>

      status              show what the agent sees
      networks            list remembered Wi-Fi networks
      pin <ssid>          switch to <ssid> and pin it (asks for its password once)
      pin --here <ssid>   pin the network you are on now, named <ssid>, without switching
      unpin               stop holding a network
      mark-hotspot        treat the current network as a hotspot (iPhone hotspots are detected automatically)
      unmark-hotspot      stop treating the current network as a hotspot
      pause | resume      suspend or resume everything
      awdl hotspots | all | never
                          where to turn AWDL off (hotspots, the default)
      allow-awdl [min]    leave AWDL on for <min> minutes (default 10), e.g. for AirDrop
      allow-awdl stop     end that early
      run                 run the agent in the foreground instead of the app (for development)

    The agent runs inside Hotspotly.app; these commands read and change its state.
    """

func fail(_ message: String) -> Never {
    FileHandle.standardError.write(Data("hotspotly: \(message)\n".utf8))
    exit(1)
}

func printStatus() {
    let config = Store.loadConfig()
    guard let status = Store.loadStatus(), !status.isStale else {
        print("agent:    not running (open Hotspotly.app)")
        return
    }
    print("agent:    running\(config.paused ? ", paused" : "")")
    print("gateway:  \(status.gateway ?? "none") \(status.gatewayMAC.map { "(\($0))" } ?? "")")
    print("hotspot:  \(status.onHotspot ? "yes" : "no")")
    if let loss = status.packetLoss {
        let latency = status.latencyMs.map { "\(Int($0.rounded())) ms" } ?? "no reply"
        print("router:   \(latency), \(Int((loss * 100).rounded()))% loss over the last minute")
    }
    var awdl = status.awdlDown ? "down" : "up"
    if config.awdlMode == .never {
        awdl += " (left alone: awdl never)"
    } else if let until = config.awdlAllowedUntil, config.awdlAllowed {
        awdl += " (allowed until \(until.formatted(date: .omitted, time: .shortened)))"
    }
    print("awdl0:    \(awdl)")
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
    // Two loops would fight over awdl0 and both write status.json.
    if let status = Store.loadStatus(), !status.isStale { fail("the agent is already running (quit Hotspotly.app first)") }
    Agent().run()
case "status", nil:
    printStatus()
case "networks":
    let pinned = Store.loadConfig().pin?.ssid
    for ssid in Net.preferredNetworks() { print("\(ssid == pinned ? "*" : " ") \(ssid)") }
case "pin":
    let here = args.count == 3 && args[1] == "--here"
    guard args.count == 2 || here else { fail("usage: hotspotly pin [--here] <ssid>") }
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
    Store.updateConfig {
        $0.hotspotMACs.removeAll { $0 == mac }
        $0.hotspotNames[mac] = nil
    }
case "pause":
    Store.updateConfig { $0.paused = true }
case "resume":
    Store.updateConfig { $0.paused = false }
case "awdl":
    guard args.count == 2, let mode = Config.AWDLMode(rawValue: args[1]) else {
        fail("usage: hotspotly awdl hotspots|all|never")
    }
    Store.updateConfig { $0.awdlMode = mode }
case "allow-awdl":
    if args.count == 2 && args[1] == "stop" {
        Store.updateConfig { $0.awdlAllowedUntil = nil }
        break
    }
    guard args.count <= 2, let minutes = args.count == 2 ? Int(args[1]) : 10, minutes > 0 else {
        fail("usage: hotspotly allow-awdl [minutes] | allow-awdl stop")
    }
    let until = Date().addingTimeInterval(TimeInterval(minutes * 60))
    Store.updateConfig { $0.awdlAllowedUntil = until }
    print("AWDL stays on until \(until.formatted(date: .omitted, time: .shortened)) (takes effect within 10 seconds)")
case "-h", "--help", "help":
    print(usage)
default:
    fail("unknown command '\(args[0])'\n\n\(usage)")
}
