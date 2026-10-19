import Foundation

/// The background loop. The menu bar app runs it on a thread of its own; `hotspotly run` runs it
/// in the foreground for development.
public final class Agent {
    let interval: TimeInterval = 10
    /// Each failed join drops the current network for a few seconds, so tries are few and far apart.
    let rejoinSpacing: TimeInterval = 60
    let maxRejoinFailures = 3
    /// Each try scans, which briefly takes the radio off the current channel. A phone hotspot that
    /// stopped advertising can stay unseen for a long time, so back off while it is not found.
    let notFoundSpacing: [TimeInterval] = [60, 120, 300, 600]

    /// handleAWDL runs on the agent thread and the watcher on its own, so both take this lock.
    let awdlLock = NSLock()
    var keepAWDLDown = false
    var awdlDownedByUs = false
    var awdlFailureLogged = false
    var trackedPin: Config.Pin?
    var wasOnPin = true
    var rejoinFailures = 0
    var notFoundStreak = 0
    var nextRejoin = Date.distantPast
    var lastEvent: String?
    /// The last minute of keepalive probes, for the Connection light; cleared when the gateway changes.
    var probes: [Net.Probe] = []
    var probedGateway: String?
    /// Rounds before latency and loss are shown: one lost ping in the first round would read as 33%.
    let minRounds = 3
    var wasSilent = false
    /// The hotspot's gateway MAC and the Wi-Fi byte count when the Mac joined it.
    var hotspotStart: (mac: String, bytes: Int64)? = Store.loadStatus().flatMap { status in
        // Carried over from the previous run, if it was on a hotspot.
        guard let mac = status.gatewayMAC, let bytes = status.hotspotStartBytes else { return nil }
        return (mac, bytes)
    }
    /// Lets the app tick right away after a menu change instead of up to 10 seconds later.
    let wakeUp = DispatchSemaphore(value: 0)

    public init() {}

    public func refresh() { wakeUp.signal() }

    public func run() -> Never {
        event("agent started")
        AWDLWatcher.start { [self] in
            awdlLock.lock()
            defer { awdlLock.unlock() }
            if keepAWDLDown { _ = Net.setAWDL(up: false) }
        }
        while true {
            // Without a run loop nothing drains autoreleased objects, so every Pipe from `sh` stayed
            // open until the agent ran out of file descriptors and every command failed.
            autoreleasepool { tick() }
            _ = wakeUp.wait(timeout: .now() + interval)
        }
    }

    func tick() {
        let config = Store.loadConfig()
        let gateway = Net.router()
        // Pinging the gateway is the keepalive: it stops a phone from shutting an idle hotspot down.
        // It also refreshes the ARP entry that `mac(of:)` reads, and measures latency and loss.
        if gateway != probedGateway {
            probes = []
            probedGateway = gateway
        }
        let probe = gateway.map { Net.probe($0) }
        if let probe { probes = (probes + [probe]).suffix(6) }
        let mac = gateway.flatMap(Net.mac(of:))
        let onHotspot = gateway == Net.iPhoneGateway || mac.map(config.hotspotMACs.contains) == true
        let silent = probes.count >= 2 && probes.suffix(2).allSatisfy { $0.received == 0 }
        if let probe, let ssid = Net.ssid() { record(probe, on: ssid, silent: silent) }
        wasSilent = silent

        handleAWDL(down: config.turnsOffAWDL(onHotspot: onHotspot) && !config.paused && !config.awdlAllowed)
        let onPin = config.paused ? nil : handlePin(config.pin, currentMAC: mac)

        let measured = probes.count >= minRounds
        let sent = probes.reduce(0) { $0 + $1.sent }
        let received = probes.reduce(0) { $0 + $1.received }
        let roundTrips = probes.reduce(0.0) { $0 + ($1.averageMs ?? 0) * Double($1.received) }
        Store.saveStatus(Status(
            updated: Date(), gateway: gateway, gatewayMAC: mac, onHotspot: onHotspot,
            awdlDown: !Net.awdlIsUp(), onPin: onPin, lastEvent: lastEvent,
            latencyMs: measured && received > 0 ? roundTrips / Double(received) : nil,
            packetLoss: measured && sent > 0 ? 1 - Double(received) / Double(sent) : nil,
            gatewaySilent: silent,
            hotspotBytes: hotspotBytes(onHotspot: onHotspot, gateway: gateway, mac: mac),
            hotspotStartBytes: hotspotStart?.bytes))
    }

    func record(_ probe: Net.Probe, on ssid: String, silent: Bool) {
        let rssi = Net.rssi()
        Store.updateHistory { history in
            var entry = history[ssid] ?? NetworkRecord(lastConnected: Date())
            entry.lastConnected = Date()
            entry.sent += probe.sent
            entry.received += probe.received
            entry.roundTripMs += (probe.averageMs ?? 0) * Double(probe.received)
            if let rssi {
                entry.rssiSum += rssi
                entry.rssiCount += 1
            }
            if silent && !wasSilent { entry.dropouts += 1 }
            history[ssid] = entry
        }
    }

    /// Counted from joining the hotspot. A moment without a gateway keeps the count going; another
    /// network ends it.
    func hotspotBytes(onHotspot: Bool, gateway: String?, mac: String?) -> Int64? {
        guard onHotspot else {
            if gateway != nil { hotspotStart = nil }
            return nil
        }
        guard let mac, let bytes = Net.wifiBytes() else { return nil }
        // A lower count means the counters restarted.
        if let start = hotspotStart, start.mac == mac, start.bytes <= bytes { return bytes - start.bytes }
        hotspotStart = (mac, bytes)
        return 0
    }

    func handleAWDL(down: Bool) {
        awdlLock.lock()
        defer { awdlLock.unlock() }
        keepAWDLDown = down
        if down {
            // macOS brings awdl0 back whenever something asks for it. The watcher takes it down at
            // once; this catches anything it missed.
            // Already down counts as ours too (e.g. left down by a previous run), so leaving the
            // hotspot still brings it back up.
            guard Net.awdlIsUp() else { awdlDownedByUs = true; return }
            if Net.setAWDL(up: false) {
                if !awdlDownedByUs { event("awdl0 down") }
                awdlDownedByUs = true
            } else if !awdlFailureLogged {
                event("cannot bring awdl0 down: sudoers rule missing, choose Finish Setup in the menu")
                awdlFailureLogged = true
            }
        } else if awdlDownedByUs {
            _ = Net.setAWDL(up: true)
            awdlDownedByUs = false
            event("awdl0 up")
        }
    }

    func handlePin(_ pin: Config.Pin?, currentMAC: String?) -> Bool? {
        if pin != trackedPin {
            trackedPin = pin
            wasOnPin = true
        }
        guard let pin else { return nil }

        let onPin = currentMAC == pin.gatewayMAC
        if onPin != wasOnPin {
            event(onPin ? "back on '\(pin.ssid)'" : "left '\(pin.ssid)'")
            wasOnPin = onPin
            rejoinFailures = 0
            notFoundStreak = 0
            // Give macOS a minute to settle before pulling the Mac back.
            nextRejoin = Date().addingTimeInterval(rejoinSpacing)
        }
        // Only when another gateway is actually seen: no gateway can also mean a failed lookup,
        // and with no network at all macOS auto-join already reconnects.
        if !onPin && currentMAC != nil { rejoin(pin) }
        return onPin
    }

    func rejoin(_ pin: Config.Pin) {
        guard rejoinFailures < maxRejoinFailures, Date() >= nextRejoin else { return }
        nextRejoin = Date().addingTimeInterval(rejoinSpacing)
        guard let password = Keychain.password(for: pin.ssid) else {
            event("no saved password for '\(pin.ssid)'; run `hotspotly pin \"\(pin.ssid)\"` once to save it")
            rejoinFailures = maxRejoinFailures
            return
        }
        switch Net.join(pin.ssid, password: password) {
        case .success:
            notFoundStreak = 0  // the next tick logs "back on"
        case .failure(let error) where error.networkNotFound:
            // Out of range; the current connection was not touched, so this does not count.
            notFoundStreak += 1
            nextRejoin = Date().addingTimeInterval(notFoundSpacing[min(notFoundStreak, notFoundSpacing.count - 1)])
        case .failure(let error):
            notFoundStreak = 0
            rejoinFailures += 1
            event("rejoin '\(pin.ssid)' failed (\(rejoinFailures)/\(maxRejoinFailures)): \(error)")
            if rejoinFailures == maxRejoinFailures {
                event("stopped rejoining '\(pin.ssid)' until the Mac is back on it")
            }
        }
    }

    func event(_ message: String) {
        lastEvent = message
        Store.log(message)
    }
}
