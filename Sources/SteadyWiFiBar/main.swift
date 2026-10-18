import AppKit
import CoreLocation
import CoreWLAN
import SteadyWiFiCore
import ServiceManagement

/// Looks the text up in Localizable.strings, so the menu follows the system language.
func L(_ key: String.LocalizationValue) -> String { String(localized: key) }

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

/// NSSwitch draws as inactive (grey) in a menu, whose window never becomes key. This one uses the
/// accent color like the switches in the system Wi-Fi menu.
final class MenuSwitch: NSView {
    var isOn: Bool { didSet { needsDisplay = true } }
    var onChange: (Bool) -> Void = { _ in }

    init(isOn: Bool) {
        self.isOn = isOn
        super.init(frame: NSRect(origin: .zero, size: Self.size))
        setAccessibilityElement(true)
        setAccessibilityRole(.checkBox)
    }

    required init?(coder: NSCoder) { fatalError("unused") }

    static let size = NSSize(width: 38, height: 20)

    override var intrinsicContentSize: NSSize { Self.size }

    override func draw(_ dirtyRect: NSRect) {
        let radius = bounds.height / 2
        (isOn ? NSColor.controlAccentColor : NSColor.quaternaryLabelColor).setFill()
        NSBezierPath(roundedRect: bounds, xRadius: radius, yRadius: radius).fill()
        let knob = bounds.height - 4
        NSColor.white.setFill()
        NSBezierPath(ovalIn: NSRect(x: isOn ? bounds.maxX - knob - 2 : 2, y: 2, width: knob, height: knob)).fill()
    }

    override func mouseUp(with event: NSEvent) {
        isOn.toggle()
        onChange(isOn)
    }

    override func accessibilityValue() -> Any? { isOn }
}

/// The first row, like the system Wi-Fi menu's: the app name and a switch that pauses or resumes it.
final class SwitchRow: NSView {
    init(_ title: String, isOn: Bool, handler: @escaping (Bool) -> Void) {
        super.init(frame: NSRect(x: 0, y: 0, width: 260, height: 30))
        autoresizingMask = .width
        let label = NSTextField(labelWithString: title)
        label.font = .boldSystemFont(ofSize: NSFont.systemFontSize)
        let toggle = MenuSwitch(isOn: isOn)
        toggle.setAccessibilityLabel(title)
        toggle.onChange = handler
        for view in [label, toggle] as [NSView] {
            view.translatesAutoresizingMaskIntoConstraints = false
            addSubview(view)
        }
        NSLayoutConstraint.activate([
            label.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            label.centerYAnchor.constraint(equalTo: centerYAnchor),
            toggle.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -14),
            toggle.centerYAnchor.constraint(equalTo: centerYAnchor),
        ])
    }

    required init?(coder: NSCoder) { fatalError("unused") }
}

final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    /// Only used to unlock the SSID; macOS redacts it without location access.
    /// Everything else works when the user declines, because the agent identifies networks by gateway MAC.
    let locationManager = CLLocationManager()
    var timer: Timer?
    let agent = Agent()
    /// The CLI ships inside the bundle; "Install Command Line Tool" only links it onto the PATH.
    let cliPath = Bundle.main.bundleURL.appendingPathComponent("Contents/MacOS/steadywifi").path

    func applicationDidFinishLaunching(_ notification: Notification) {
        let menu = NSMenu()
        menu.delegate = self
        statusItem.menu = menu
        locationManager.requestWhenInUseAuthorization()
        // The agent loop blocks, so it gets a thread of its own for the app's lifetime.
        Thread { [agent] in agent.run() }.start()
        refreshIcon()
        timer = Timer.scheduledTimer(withTimeInterval: 5, repeats: true) { [weak self] _ in self?.refreshIcon() }
        // The rule is only needed to turn AWDL off.
        if !Setup.isRuleInstalled && Store.loadConfig().awdlOff { offerSetup() }
    }

    func applicationWillTerminate(_ notification: Notification) {
        // The agent stops with the app; do not leave AirDrop and friends switched off behind it.
        if !Net.awdlIsUp() { _ = Net.setAWDL(up: true) }
    }

    func offerSetup() {
        let alert = NSAlert()
        alert.messageText = L("Finish setting up Steady WiFi")
        alert.informativeText = L("Turning off AWDL on a hotspot needs administrator rights. Steady WiFi adds a rule that lets it run only `ifconfig awdl0 up` and `ifconfig awdl0 down`, and nothing else. Keepalive and pinning work without it.")
        alert.addButton(withTitle: L("Continue"))
        alert.addButton(withTitle: L("Not Now"))
        NSApp.activate(ignoringOtherApps: true)
        guard alert.runModal() == .alertFirstButtonReturn else { return }
        asAdmin(L("Could not finish setup"), Setup.installRule)
    }

    /// Runs a Setup step off the main thread, since the administrator prompt blocks until answered.
    func asAdmin(_ failureTitle: String, _ work: @escaping () throws -> Void, then done: @escaping () -> Void = {}) {
        DispatchQueue.global().async {
            do {
                try work()
                DispatchQueue.main.async(execute: done)
            } catch let error as SetupError where error.description == "cancelled" {
                // The user said no; leave things as they are.
            } catch {
                DispatchQueue.main.async {
                    let alert = NSAlert()
                    alert.messageText = failureTitle
                    alert.informativeText = "\(error)"
                    NSApp.activate(ignoringOtherApps: true)
                    alert.runModal()
                }
            }
        }
    }

    func refreshIcon() {
        let config = Store.loadConfig()
        let status = Store.loadStatus()
        // A router, so it is not mistaken for the system Wi-Fi or hotspot icon next to it.
        let image: NSImage
        if status == nil || status!.isStale {
            image = routerIcon(badge: "exclamationmark.circle.fill")
        } else if config.paused {
            image = routerIcon(badge: "pause.circle.fill")
        } else {
            image = routerIcon(filled: status!.onHotspot)
        }
        image.isTemplate = true
        statusItem.button?.image = image
    }

    func routerIcon(filled: Bool = false, badge: String? = nil) -> NSImage {
        let pointSize: CGFloat = 14
        let router = NSImage(systemSymbolName: filled ? "wifi.router.fill" : "wifi.router", accessibilityDescription: "Steady WiFi")!
            .withSymbolConfiguration(.init(pointSize: pointSize, weight: .regular))!
        guard let badge, let mark = NSImage(systemSymbolName: badge, accessibilityDescription: nil)?
            .withSymbolConfiguration(.init(pointSize: pointSize * 0.7, weight: .semibold)) else { return router }
        // The badge sits on the bottom-right corner, cut out of the router so it stays legible.
        let lift = mark.size.height * 0.25
        let size = NSSize(width: router.size.width + mark.size.width * 0.35, height: router.size.height + lift)
        return NSImage(size: size, flipped: false) { _ in
            router.draw(at: NSPoint(x: 0, y: lift), from: .zero, operation: .sourceOver, fraction: 1)
            let rect = NSRect(x: size.width - mark.size.width, y: 0, width: mark.size.width, height: mark.size.height)
            NSGraphicsContext.current?.compositingOperation = .clear
            NSBezierPath(ovalIn: rect.insetBy(dx: -1, dy: -1)).fill()
            mark.draw(in: rect, from: .zero, operation: .sourceOver, fraction: 1)
            return true
        }
    }

    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()
        let config = Store.loadConfig()
        let status = Store.loadStatus()
        let ssid = CWWiFiClient.shared().interface()?.ssid()

        let header = NSMenuItem()
        header.view = SwitchRow("Steady WiFi", isOn: !config.paused) { [weak self] isOn in
            Store.updateConfig { $0.paused = !isOn }
            self?.agent.refresh()
            self?.refreshIcon()
        }
        menu.addItem(header)
        menu.addItem(.separator())

        if !Setup.isRuleInstalled && config.awdlOff {
            menu.addItem(ActionItem(L("Finish Setup…")) { [weak self] in self?.offerSetup() })
        }
        if let status, !status.isStale {
            for line in statusLines(status, config: config, ssid: ssid) { info(menu, line) }
        } else {
            info(menu, L("Starting…"))
        }
        menu.addItem(.separator())

        // Off a hotspot AWDL is on anyway; while allowed, keep the item so it can be stopped.
        if config.awdlOff && !config.paused && (status?.onHotspot == true || config.awdlAllowed) {
            if let until = config.awdlAllowedUntil, config.awdlAllowed {
                let minutes = Int((until.timeIntervalSinceNow / 60).rounded(.up))
                menu.addItem(ActionItem(L("Stop Allowing AirDrop (\(minutes) min left)")) { [weak self] in
                    Store.updateConfig { $0.awdlAllowedUntil = nil }
                    self?.agent.refresh()
                })
            } else {
                menu.addItem(ActionItem(L("Allow AirDrop for 10 Minutes")) { [weak self] in
                    Store.updateConfig { $0.awdlAllowedUntil = Date().addingTimeInterval(10 * 60) }
                    self?.agent.refresh()
                })
            }
        }
        menu.addItem(submenu(L("Pin Network"), pinMenu(config: config, status: status, ssid: ssid)))
        menu.addItem(.separator())
        menu.addItem(submenu(L("Settings"), settingsMenu(config: config, status: status)))
        menu.addItem(ActionItem(L("Quit Steady WiFi")) { NSApp.terminate(nil) })
    }

    /// One line about the network, plus one when away from the pinned network.
    func statusLines(_ status: Status, config: Config, ssid: String?) -> [String] {
        var parts: [String] = []
        if let ssid {
            parts.append(ssid)
        } else if status.gateway == nil {
            parts.append(L("Not connected"))
        } else if locationManager.authorizationStatus == .denied {
            parts.append(L("Network name hidden"))
        }
        if config.paused {
            parts.append(L("Paused"))
        } else {
            if status.onHotspot {
                parts.append(L("Hotspot"))
                if config.awdlOff { parts.append(status.awdlDown ? L("AWDL off") : L("AWDL on")) }
            }
            if status.onPin == true { parts.append(L("Pinned")) }
        }
        var lines = [parts.joined(separator: " · ")]
        if let pin = config.pin, status.onPin == false { lines.append(L("Away from \(pin.ssid)")) }
        return lines
    }

    /// The current and pinned networks, remembered networks seen nearby, and the rest one level down:
    /// a Mac can remember hundreds of networks.
    func pinMenu(config: Config, status: Status?, ssid: String?) -> NSMenu {
        let menu = NSMenu()
        let remembered = Net.preferredNetworks()
        func item(_ network: String) -> NSMenuItem {
            ActionItem(network, checked: network == config.pin?.ssid) { [weak self] in
                if network == ssid, let mac = status?.gatewayMAC {
                    Store.updateConfig { $0.pin = Config.Pin(ssid: network, gatewayMAC: mac) }
                } else {
                    self?.switchAndPin(network)
                }
            }
        }

        var shown: [String] = []
        for network in [config.pin?.ssid, ssid].compactMap({ $0 }) where !shown.contains(network) {
            menu.addItem(item(network))
            shown.append(network)
        }
        // The last scan macOS already did; scanning again would take the radio off the hotspot's
        // channel. Names are hidden here too without location access.
        let nearby = (CWWiFiClient.shared().interface()?.cachedScanResults() ?? [])
            .sorted { $0.rssiValue > $1.rssiValue }
            .compactMap(\.ssid)
            .filter { remembered.contains($0) && !shown.contains($0) }
        if !nearby.isEmpty {
            if !shown.isEmpty { menu.addItem(.separator()) }
            menu.addItem(sectionHeader(L("Nearby")))
            for network in NSOrderedSet(array: nearby).array as! [String] {
                menu.addItem(item(network))
                shown.append(network)
            }
        }
        let others = remembered.filter { !shown.contains($0) }
        if !others.isEmpty {
            if !shown.isEmpty { menu.addItem(.separator()) }
            let othersMenu = NSMenu()
            for network in others { othersMenu.addItem(item(network)) }
            menu.addItem(submenu(L("Other Remembered Networks"), othersMenu))
        }
        if config.pin != nil {
            menu.addItem(.separator())
            menu.addItem(ActionItem(L("Unpin")) { Store.updateConfig { $0.pin = nil } })
        }
        return menu
    }

    func settingsMenu(config: Config, status: Status?) -> NSMenu {
        let menu = NSMenu()
        menu.addItem(ActionItem(L("Turn Off AWDL on Hotspots"), checked: config.awdlOff) { [weak self] in
            Store.updateConfig { $0.awdlOff.toggle() }
            self?.agent.refresh()
            if !config.awdlOff && !Setup.isRuleInstalled { self?.offerSetup() }
        })
        if let mac = status?.gatewayMAC, status?.gateway != Net.iPhoneGateway {
            let marked = config.hotspotMACs.contains(mac)
            menu.addItem(ActionItem(L("Current Network Is a Hotspot"), checked: marked) { [weak self] in
                Store.updateConfig {
                    if marked { $0.hotspotMACs.removeAll { $0 == mac } } else { $0.hotspotMACs.append(mac) }
                }
                self?.agent.refresh()
            })
        }
        let loginItem = SMAppService.mainApp
        menu.addItem(ActionItem(L("Open at Login"), checked: loginItem.status == .enabled) {
            do {
                if loginItem.status == .enabled { try loginItem.unregister() } else { try loginItem.register() }
            } catch {
                Store.log("open at login: \(error.localizedDescription)")
            }
        })
        menu.addItem(.separator())
        menu.addItem(ActionItem(L("Open Log")) { NSWorkspace.shared.open(Store.logURL) })
        let cliLinked = Setup.cliIsLinked(to: cliPath)
        menu.addItem(ActionItem(cliLinked ? L("Uninstall Command Line Tool…") : L("Install Command Line Tool…")) { [weak self] in
            guard let self else { return }
            asAdmin(L("Could not change the command line tool"), cliLinked ? Setup.unlinkCLI : { try Setup.linkCLI(self.cliPath) })
        })
        menu.addItem(ActionItem(L("Uninstall Steady WiFi…")) { [weak self] in self?.uninstall() })
        return menu
    }

    /// Removes what lives outside the bundle, then quits; the user drags the app to the Trash.
    func uninstall() {
        let alert = NSAlert()
        alert.messageText = L("Uninstall Steady WiFi?")
        alert.informativeText = L("This removes the administrator rule, the command line tool and the login item, and turns AWDL back on. Then move SteadyWiFi.app to the Trash.")
        alert.addButton(withTitle: L("Uninstall"))
        alert.addButton(withTitle: L("Cancel"))
        NSApp.activate(ignoringOtherApps: true)
        guard alert.runModal() == .alertFirstButtonReturn else { return }
        try? SMAppService.mainApp.unregister()
        asAdmin(L("Could not uninstall"), { [cliPath] in try Setup.removeAll(cli: cliPath) }) {
            NSApp.terminate(nil)
        }
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
                    alert.messageText = L("Could not switch to “\(network)”")
                    alert.informativeText = error.message
                    NSApp.activate(ignoringOtherApps: true)
                    alert.runModal()
                }
            }
        }
    }

    func askPassword(for network: String) -> String? {
        let alert = NSAlert()
        alert.messageText = L("Wi-Fi password for “\(network)”")
        alert.informativeText = L("Leave it empty for an open network. It is kept in your login keychain once the join works.")
        let field = NSSecureTextField(frame: NSRect(x: 0, y: 0, width: 260, height: 24))
        alert.accessoryView = field
        alert.addButton(withTitle: L("Join"))
        alert.addButton(withTitle: L("Cancel"))
        alert.window.initialFirstResponder = field
        NSApp.activate(ignoringOtherApps: true)
        return alert.runModal() == .alertFirstButtonReturn ? field.stringValue : nil
    }

    func info(_ menu: NSMenu, _ title: String) {
        let item = NSMenuItem(title: title, action: nil, keyEquivalent: "")
        item.isEnabled = false
        menu.addItem(item)
    }

    func submenu(_ title: String, _ submenu: NSMenu) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: nil, keyEquivalent: "")
        item.submenu = submenu
        return item
    }

    func sectionHeader(_ title: String) -> NSMenuItem {
        if #available(macOS 14, *) { return .sectionHeader(title: title) }
        let item = NSMenuItem(title: title, action: nil, keyEquivalent: "")
        item.isEnabled = false
        return item
    }
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.accessory)
app.run()
