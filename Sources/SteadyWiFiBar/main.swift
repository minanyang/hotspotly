import AppKit
import CoreLocation
import CoreWLAN
import SteadyWiFiCore
import ServiceManagement

/// NSMenuItem that runs a closure, so the menu can be rebuilt freely on every open.
final class ActionItem: NSMenuItem {
    private let handler: () -> Void

    init(_ title: String, checked: Bool = false, handler: @escaping () -> Void) {
        self.handler = handler
        super.init(title: title, action: #selector(fire), keyEquivalent: "")
        target = self
        state = checked ? .on : .off
    }

    required init(coder: NSCoder) { fatalError("unused") }

    @objc private func fire() { handler() }
}

final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    /// Only used to unlock the SSID; macOS redacts it without location access.
    /// Everything else works when the user declines, because the agent identifies networks by gateway MAC.
    let locationManager = CLLocationManager()
    var timer: Timer?

    func applicationDidFinishLaunching(_ notification: Notification) {
        let menu = NSMenu()
        menu.delegate = self
        statusItem.menu = menu
        locationManager.requestWhenInUseAuthorization()
        refreshIcon()
        timer = Timer.scheduledTimer(withTimeInterval: 5, repeats: true) { [weak self] _ in self?.refreshIcon() }
    }

    func refreshIcon() {
        let config = Store.loadConfig()
        let status = Store.loadStatus()
        // Shields, so the icon is not mistaken for the system Wi-Fi or hotspot icon next to it.
        let symbol: String
        if status == nil || status!.isStale {
            symbol = "exclamationmark.shield"
        } else if config.paused {
            symbol = "pause.circle"
        } else if status!.onHotspot {
            symbol = "checkmark.shield.fill"
        } else {
            symbol = "shield"
        }
        statusItem.button?.image = NSImage(systemSymbolName: symbol, accessibilityDescription: "steadywifi")
    }

    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()
        let config = Store.loadConfig()
        let status = Store.loadStatus()

        let ssid = CWWiFiClient.shared().interface()?.ssid()
        if let status, !status.isStale {
            if let ssid {
                info(menu, "Network: \(ssid)")
            } else if locationManager.authorizationStatus == .denied {
                info(menu, "Network name hidden (allow Location to show it)")
            }
            info(menu, status.onHotspot ? "On a hotspot · AWDL \(status.awdlDown ? "off" : "on")" : "Not on a hotspot")
            if let pin = config.pin {
                let state = status.onPin.map { $0 ? "connected" : "away" } ?? "not checked while paused"
                info(menu, "Pinned: \(pin.ssid) (\(state))")
            }
            if let event = status.lastEvent { info(menu, "Last: \(event)") }
        } else {
            info(menu, "Agent not running — run `steadywifi install`")
        }
        menu.addItem(.separator())

        menu.addItem(ActionItem(config.paused ? "Resume" : "Pause") { [weak self] in
            Store.updateConfig { $0.paused.toggle() }
            self?.refreshIcon()
        })

        let pinMenu = NSMenu()
        for network in Net.preferredNetworks() {
            pinMenu.addItem(ActionItem(network, checked: network == config.pin?.ssid) { [weak self] in
                if network == ssid, let mac = status?.gatewayMAC {
                    Store.updateConfig { $0.pin = Config.Pin(ssid: network, gatewayMAC: mac) }
                } else {
                    self?.switchAndPin(network)
                }
            })
        }
        if config.pin != nil {
            pinMenu.addItem(.separator())
            pinMenu.addItem(ActionItem("Unpin") { Store.updateConfig { $0.pin = nil } })
        }
        let pinItem = NSMenuItem(title: "Pin Network", action: nil, keyEquivalent: "")
        pinItem.submenu = pinMenu
        menu.addItem(pinItem)

        if let mac = status?.gatewayMAC, status?.gateway != Net.iPhoneGateway {
            let marked = config.hotspotMACs.contains(mac)
            menu.addItem(ActionItem("Current Network Is a Hotspot", checked: marked) {
                Store.updateConfig {
                    if marked { $0.hotspotMACs.removeAll { $0 == mac } } else { $0.hotspotMACs.append(mac) }
                }
            })
        }
        menu.addItem(.separator())

        let loginItem = SMAppService.mainApp
        menu.addItem(ActionItem("Open at Login", checked: loginItem.status == .enabled) {
            do {
                if loginItem.status == .enabled { try loginItem.unregister() } else { try loginItem.register() }
            } catch {
                Store.log("open at login: \(error.localizedDescription)")
            }
        })
        menu.addItem(ActionItem("Open Log") { NSWorkspace.shared.open(Store.logURL) })
        menu.addItem(ActionItem("Quit") { NSApp.terminate(nil) })
    }

    /// Same as `steadywifi pin <ssid>`: one join, and the password is saved only if it works.
    func switchAndPin(_ network: String) {
        let saved = Keychain.password(for: network)
        guard let password = saved ?? askPassword(for: network) else { return }
        DispatchQueue.global().async {
            let result = Net.join(network, password: password)
            DispatchQueue.main.async {
                switch result {
                case .success(let mac):
                    if saved == nil { Keychain.save(password, for: network) }
                    Store.updateConfig { $0.pin = Config.Pin(ssid: network, gatewayMAC: mac) }
                    Store.log("pinned '\(network)' (gateway \(mac))")
                case .failure(let error):
                    Store.log("could not switch to '\(network)': \(error)")
                    let alert = NSAlert()
                    alert.messageText = "Could not switch to “\(network)”"
                    alert.informativeText = error.message
                    NSApp.activate(ignoringOtherApps: true)
                    alert.runModal()
                }
            }
        }
    }

    func askPassword(for network: String) -> String? {
        let alert = NSAlert()
        alert.messageText = "Wi-Fi password for “\(network)”"
        alert.informativeText = "Leave it empty for an open network. It is kept in your login keychain once the join works."
        let field = NSSecureTextField(frame: NSRect(x: 0, y: 0, width: 260, height: 24))
        alert.accessoryView = field
        alert.addButton(withTitle: "Join")
        alert.addButton(withTitle: "Cancel")
        alert.window.initialFirstResponder = field
        NSApp.activate(ignoringOtherApps: true)
        return alert.runModal() == .alertFirstButtonReturn ? field.stringValue : nil
    }

    func info(_ menu: NSMenu, _ title: String) {
        let item = NSMenuItem(title: title, action: nil, keyEquivalent: "")
        item.isEnabled = false
        menu.addItem(item)
    }
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.accessory)
app.run()
