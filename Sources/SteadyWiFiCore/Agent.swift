import Foundation

/// The background loop. The menu bar app runs it on a thread of its own; `steadywifi run` runs it
/// in the foreground for development.
public final class Agent {
    let interval: TimeInterval = 10
    /// Each failed join drops the current network for a few seconds, so tries are few and far apart.
    let rejoinSpacing: TimeInterval = 60
    let maxRejoinFailures = 3
    /// Each try scans, which briefly takes the radio off the current channel. A phone hotspot that
    /// stopped advertising can stay unseen for a long time, so back off while it is not found.
    let notFoundSpacing: [TimeInterval] = [60, 120, 300, 600]

    var awdlDownedByUs = false
    var awdlFailureLogged = false
    var trackedPin: Config.Pin?
    var wasOnPin = true
    var rejoinFailures = 0
    var notFoundStreak = 0
    var nextRejoin = Date.distantPast
    var lastEvent: String?

    public init() {}

    public func run() -> Never {
        event("agent started")
        while true {
            // Without a run loop nothing drains autoreleased objects, so every Pipe from `sh` stayed
            // open until the agent ran out of file descriptors and every command failed.
            autoreleasepool { tick() }
            Thread.sleep(forTimeInterval: interval)
        }
    }

    func tick() {
        let config = Store.loadConfig()
        let gateway = Net.router()
        // Pinging the gateway is the keepalive: it stops a phone from shutting an idle hotspot down.
        // It also refreshes the ARP entry that `mac(of:)` reads.
        if let gateway { _ = Net.ping(gateway) }
        let mac = gateway.flatMap(Net.mac(of:))
        let onHotspot = gateway == Net.iPhoneGateway || mac.map(config.hotspotMACs.contains) == true

        handleAWDL(onHotspot: onHotspot && !config.paused)
        let onPin = config.paused ? nil : handlePin(config.pin, currentMAC: mac)

        Store.saveStatus(Status(
            updated: Date(), gateway: gateway, gatewayMAC: mac, onHotspot: onHotspot,
            awdlDown: !Net.awdlIsUp(), onPin: onPin, lastEvent: lastEvent))
    }

    func handleAWDL(onHotspot: Bool) {
        if onHotspot {
            // macOS brings awdl0 back whenever something asks for it, so this runs every tick.
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
            event("no saved password for '\(pin.ssid)'; run `steadywifi pin \"\(pin.ssid)\"` once to save it")
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
