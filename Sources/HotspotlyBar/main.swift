import AppKit
import CoreLocation
import CoreWLAN
import HotspotlyCore
import ServiceManagement
import Sparkle

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

/// A status light: a colored dot, a name and a short detail, like the two lights on the logo's router.
/// Without a light it is a detail row under one, indented to the same column and greyed.
final class LightRow: NSView {
    private let dot = NSImageView()
    private let nameLabel = NSTextField(labelWithString: "")
    private let detailLabel = NSTextField(labelWithString: "")

    init(_ name: String, light: Light?, detail: String) {
        super.init(frame: NSRect(x: 0, y: 0, width: 260, height: 22))
        autoresizingMask = .width
        detailLabel.textColor = .secondaryLabelColor
        for view in [dot, nameLabel, detailLabel] as [NSView] {
            view.translatesAutoresizingMaskIntoConstraints = false
            addSubview(view)
        }
        nameLabel.font = .menuFont(ofSize: 0)
        detailLabel.font = .menuFont(ofSize: 0)
        NSLayoutConstraint.activate([
            dot.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            dot.centerYAnchor.constraint(equalTo: centerYAnchor),
            dot.widthAnchor.constraint(equalToConstant: 8),
            dot.heightAnchor.constraint(equalToConstant: 8),
            nameLabel.leadingAnchor.constraint(equalTo: dot.trailingAnchor, constant: 7),
            nameLabel.centerYAnchor.constraint(equalTo: centerYAnchor),
            detailLabel.leadingAnchor.constraint(greaterThanOrEqualTo: nameLabel.trailingAnchor, constant: 16),
            detailLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),
            detailLabel.centerYAnchor.constraint(equalTo: centerYAnchor),
        ])
        setAccessibilityElement(true)
        setAccessibilityRole(.staticText)
        update(name, light: light, detail: detail)
    }

    required init?(coder: NSCoder) { fatalError("unused") }

    var name: String { nameLabel.stringValue }

    /// Called again every few seconds while the menu is open.
    func update(_ name: String, light: Light?, detail: String) {
        let color: NSColor = switch light {
        case .green: .systemGreen
        case .amber: .systemOrange
        case .red: .systemRed
        case .off: .tertiaryLabelColor
        case nil: .clear
        }
        dot.image = NSImage(size: NSSize(width: 8, height: 8), flipped: false) { rect in
            color.setFill()
            NSBezierPath(ovalIn: rect).fill()
            return true
        }
        nameLabel.stringValue = name
        nameLabel.textColor = light == nil ? .secondaryLabelColor : .labelColor
        detailLabel.stringValue = detail
        setAccessibilityLabel("\(name): \(detail)")
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate, SPUStandardUserDriverDelegate {
    let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    /// Only used to unlock the SSID; macOS redacts it without location access.
    /// Everything else works when the user declines, because the agent identifies networks by gateway MAC.
    let locationManager = CLLocationManager()
    var timer: Timer?
    /// The rows that keep updating while the menu is open, and the timer that updates them.
    var liveRows: (connection: LightRow, readings: [LightRow], protection: LightRow)?
    var liveTimer: Timer?
    let agent = Agent()
    /// Checks appcast.xml on GitHub once a day and installs updates signed with the project's key.
    lazy var updater = SPUStandardUpdaterController(startingUpdater: true, updaterDelegate: nil, userDriverDelegate: self)
    /// A scheduled check found this version while the user was busy; offered in the menu instead.
    var availableUpdate: String?
    /// The CLI ships inside the bundle; "Install Command Line Tool" only links it onto the PATH.
    let cliPath = Bundle.main.bundleURL.appendingPathComponent("Contents/MacOS/hotspotly").path
    lazy var settings: SettingsWindow = {
        let model = SettingsModel(cliPath: cliPath)
        model.configChanged = { [weak self] in
            self?.agent.refresh()
            self?.refreshIcon()
        }
        model.finishSetup = { [weak self] in self?.offerSetup() }
        model.asAdmin = { [weak self] title, work, done in self?.asAdmin(title, work, then: done) }
        model.uninstallApp = { [weak self] in self?.uninstall() }
        model.updater = updater.updater
        model.checkForUpdates = { [weak self] in self?.checkForUpdates() }
        return SettingsWindow(model: model)
    }()

    func applicationDidFinishLaunching(_ notification: Notification) {
        let menu = NSMenu()
        menu.delegate = self
        statusItem.menu = menu
        locationManager.requestWhenInUseAuthorization()
        // No menu bar of its own (LSUIElement), but ⌘W should still close the Settings window.
        let appMenu = NSMenu()
        appMenu.addItem(withTitle: L("Close"), action: #selector(NSWindow.performClose(_:)), keyEquivalent: "w")
        let appItem = NSMenuItem()
        appItem.submenu = appMenu
        NSApp.mainMenu = NSMenu()
        NSApp.mainMenu?.addItem(appItem)
        _ = updater
        // A drop that follows sleep is not the network's fault; the agent needs to know.
        NSWorkspace.shared.notificationCenter.addObserver(forName: NSWorkspace.willSleepNotification, object: nil, queue: nil) {
            [agent] _ in agent.noteSleep()
        }
        // The agent loop blocks, so it gets a thread of its own for the app's lifetime.
        Thread { [agent] in agent.run() }.start()
        refreshIcon()
        timer = Timer.scheduledTimer(withTimeInterval: 5, repeats: true) { [weak self] _ in self?.refreshIcon() }
        // The rule is only needed to turn AWDL off.
        if !Setup.isRuleInstalled && Store.loadConfig().awdlMode != .never { offerSetup() }
        // With the icon hidden, opening the app by hand is the way to its settings; a login launch is not.
        let launch = NSAppleEventManager.shared().currentAppleEvent?.paramDescriptor(forKeyword: keyAEPropData)
        if Store.loadConfig().hideIcon && launch?.enumCodeValue != keyAELaunchedAsLogInItem { showSettings() }
    }

    /// Opening Hotspotly.app while it runs, which is how to reach Settings with the icon hidden.
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        showSettings()
        return false
    }

    func applicationWillTerminate(_ notification: Notification) {
        // The agent stops with the app; do not leave AirDrop and friends switched off behind it.
        if !Net.awdlIsUp() { _ = Net.setAWDL(up: true) }
    }

    func offerSetup() {
        let alert = NSAlert()
        alert.messageText = L("Finish setting up Hotspotly")
        alert.informativeText = L("Turning off AWDL on a hotspot needs administrator rights. Hotspotly adds a rule that lets it run only `ifconfig awdl0 up` and `ifconfig awdl0 down`, and nothing else. Keepalive and pinning work without it.")
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
        // The Hotspotly router, which is easy to tell apart from the system Wi-Fi icon next to it.
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
        statusItem.isVisible = !config.hideIcon
    }

    func routerIcon(filled: Bool = false, badge: String? = nil) -> NSImage {
        // Drawn by scripts/make-icons.swift; a copy, since the bundle hands out one shared instance.
        let router = Bundle.main.image(forResource: filled ? "MenuBarIconFilled" : "MenuBarIcon")!.copy() as! NSImage
        router.size = NSSize(width: 20, height: 20)
        router.accessibilityDescription = "Hotspotly"
        guard let badge, let mark = NSImage(systemSymbolName: badge, accessibilityDescription: nil)?
            .withSymbolConfiguration(.init(pointSize: 10, weight: .semibold)) else { return router }
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
        header.view = SwitchRow("Hotspotly", isOn: !config.paused) { [weak self] isOn in
            Store.updateConfig { $0.paused = !isOn }
            self?.agent.refresh()
            self?.refreshIcon()
        }
        menu.addItem(header)
        menu.addItem(.separator())

        if !Setup.isRuleInstalled && config.awdlMode != .never {
            menu.addItem(ActionItem(L("Finish Setup…")) { [weak self] in self?.offerSetup() })
        }
        if let version = availableUpdate {
            menu.addItem(ActionItem(L("Update to \(version)…")) { [weak self] in self?.checkForUpdates() })
        }
        liveRows = nil
        guard let status, !status.isStale else {
            info(menu, L("Starting…"))
            menu.addItem(.separator())
            addFooter(menu)
            return
        }
        // The network with its light and readings, then the Protection light.
        let connection = row(menu, networkName(status, ssid: ssid), status.connectionLight, connectionDetail(status))
        let readings = (status.gateway != nil ? linkReadings(status) : []).map { row(menu, $0.0, nil, $0.1) }
        let protection = row(menu, L("Protection"), status.protectionLight(config), protectionDetail(status, config: config))
        liveRows = (connection, readings, protection)
        menu.addItem(.separator())

        // Where AWDL is left alone the item does nothing; while allowed, keep it so it can be stopped.
        if !config.paused && (config.turnsOffAWDL(onHotspot: status.onHotspot) || config.awdlAllowed) {
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
        addFooter(menu)
    }

    func addFooter(_ menu: NSMenu) {
        menu.addItem(ActionItem(L("Check for Updates…")) { [weak self] in self?.checkForUpdates() })
        let settings = ActionItem(L("Settings…")) { [weak self] in self?.showSettings() }
        settings.keyEquivalent = ","
        menu.addItem(settings)
        menu.addItem(ActionItem(L("Quit Hotspotly")) { NSApp.terminate(nil) })
    }

    /// Titles the Connection light: the network, and whether it counts as a hotspot.
    func networkName(_ status: Status, ssid: String?) -> String {
        guard status.gateway != nil else { return L("Not connected") }
        let name = ssid ?? (locationManager.authorizationStatus == .denied ? L("Network name hidden") : L("Wi-Fi"))
        return status.onHotspot ? "\(name) · \(L("Hotspot"))" : name
    }

    func connectionDetail(_ status: Status) -> String {
        guard status.gateway != nil else { return "" }
        if status.gatewaySilent { return L("No reply from the router") }
        guard let loss = status.packetLoss, let latency = status.latencyMs else { return L("Measuring…") }
        let percent = Int((loss * 100).rounded())
        return "\(Int(latency.rounded())) ms · " + (percent == 0 ? L("no loss") : L("\(percent)% loss"))
    }

    func protectionDetail(_ status: Status, config: Config) -> String {
        if config.paused { return L("Paused") }
        var parts: [String] = []
        if status.onHotspot || config.awdlMode == .all {
            if !config.turnsOffAWDL(onHotspot: status.onHotspot) {
                parts.append(L("AWDL left on"))
            } else if let until = config.awdlAllowedUntil, config.awdlAllowed {
                parts.append(L("AirDrop allowed · \(Int((until.timeIntervalSinceNow / 60).rounded(.up))) min"))
            } else {
                parts.append(status.awdlDown ? L("AWDL off") : L("AWDL on"))
            }
        }
        if let pin = config.pin, let onPin = status.onPin {
            parts.append(onPin ? L("Pinned") : L("Away from \(pin.ssid)"))
        }
        return parts.isEmpty ? L("Not on a hotspot") : parts.joined(separator: " · ")
    }

    /// Live readings for the current Wi-Fi link, read when the menu opens, and the data used on a hotspot.
    func linkReadings(_ status: Status) -> [(String, String)] {
        guard let wifi = CWWiFiClient.shared().interface(), wifi.rssiValue() != 0 else { return [] }
        let rssi = wifi.rssiValue(), noise = wifi.noiseMeasurement()
        var rows = [(L("Signal"), "\(rssi) dBm · SNR \(rssi - noise) dB")]
        if let channel = wifi.wlanChannel() {
            let band = [1: "2.4 GHz", 2: "5 GHz", 3: "6 GHz"][channel.channelBand.rawValue] ?? "?"
            let width = [1: 20, 2: 40, 3: 80, 4: 160][channel.channelWidth.rawValue].map { "\($0) MHz" } ?? "?"
            rows.append((L("Channel"), "\(channel.channelNumber) · \(band) · \(width)"))
        }
        let standards = [1: "802.11a", 2: "802.11b", 3: "802.11g", 4: "Wi-Fi 4", 5: "Wi-Fi 5", 6: "Wi-Fi 6", 7: "Wi-Fi 7"]
        let standard = standards[wifi.activePHYMode().rawValue].map { "\($0) · " } ?? ""
        rows.append((L("Standard"), "\(standard)\(Int(wifi.transmitRate())) Mbps"))
        if let bytes = status.hotspotBytes {
            rows.append((L("Data used"), L("\(ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file)) since joining")))
        }
        return rows
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

    /// Removes what lives outside the bundle, then quits; the user drags the app to the Trash.
    func uninstall() {
        let alert = NSAlert()
        alert.messageText = L("Uninstall Hotspotly?")
        alert.informativeText = L("This removes the administrator rule, the command line tool and the login item, and turns AWDL back on. Then move Hotspotly.app to the Trash.")
        alert.addButton(withTitle: L("Uninstall"))
        alert.addButton(withTitle: L("Cancel"))
        NSApp.activate(ignoringOtherApps: true)
        guard alert.runModal() == .alertFirstButtonReturn else { return }
        try? SMAppService.mainApp.unregister()
        asAdmin(L("Could not uninstall"), { [cliPath] in try Setup.removeAll(cli: cliPath) }) {
            NSApp.terminate(nil)
        }
    }

    /// Same as `hotspotly pin <ssid>`: one join, and the password is saved only if it works.
    func switchAndPin(_ network: String) {
        if let saved = Keychain.password(for: network) { return join(network, password: saved, save: false) }
        let open = Net.rememberedNetworks().first { $0.ssid == network }?.security == CWSecurity.none
        switch askPassword(for: network, offerSaved: !open) {
        case .typed(let password):
            join(network, password: password, save: true)
        case .saved:
            // The system prompt blocks until answered; cancelling it falls back to typing.
            DispatchQueue.global().async {
                let password = Keychain.systemPassword(for: network)
                DispatchQueue.main.async { [weak self] in
                    guard let self else { return }
                    if let password { return self.join(network, password: password, save: true) }
                    if case .typed(let typed) = self.askPassword(for: network, offerSaved: false) {
                        self.join(network, password: typed, save: true)
                    }
                }
            }
        case nil:
            return
        }
    }

    func join(_ network: String, password: String, save: Bool) {
        DispatchQueue.global().async {
            let result = Net.join(network, password: password)
            DispatchQueue.main.async {
                switch result {
                case .success(let mac):
                    if save { Keychain.save(password, for: network) }
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

    enum PasswordChoice {
        case typed(String)
        /// Read the password macOS saved, which asks for the user's password.
        case saved
    }

    func askPassword(for network: String, offerSaved: Bool) -> PasswordChoice? {
        let alert = NSAlert()
        alert.messageText = L("Wi-Fi password for “\(network)”")
        alert.informativeText = L("Leave it empty for an open network. It is kept in your login keychain once the join works.")
        let field = NSSecureTextField(frame: NSRect(x: 0, y: 0, width: 260, height: 24))
        alert.accessoryView = field
        alert.addButton(withTitle: L("Join"))
        alert.addButton(withTitle: L("Cancel"))
        if offerSaved { alert.addButton(withTitle: L("Use Password Saved on This Mac…")) }
        alert.window.initialFirstResponder = field
        NSApp.activate(ignoringOtherApps: true)
        switch alert.runModal() {
        case .alertFirstButtonReturn: return .typed(field.stringValue)
        case .alertThirdButtonReturn: return .saved
        default: return nil
        }
    }

    func showSettings() {
        settings.show()
    }

    func checkForUpdates() {
        // A background app's update window would otherwise open behind the frontmost app.
        NSApp.activate(ignoringOtherApps: true)
        updater.checkForUpdates(nil)
    }

    // Gentle reminders: a menu bar app has no window the user is looking at, so a scheduled check
    // shows Sparkle's window only when it would not interrupt (just launched or idle), and otherwise
    // adds "Update to …" to the menu.
    var supportsGentleScheduledUpdateReminders: Bool { true }

    func standardUserDriverShouldHandleShowingScheduledUpdate(_ update: SUAppcastItem, andInImmediateFocus immediateFocus: Bool) -> Bool {
        immediateFocus
    }

    func standardUserDriverWillHandleShowingUpdate(_ handleShowingUpdate: Bool, forUpdate update: SUAppcastItem, state: SPUUserUpdateState) {
        if !handleShowingUpdate { availableUpdate = update.displayVersionString }
    }

    func standardUserDriverDidReceiveUserAttention(forUpdate update: SUAppcastItem) {
        availableUpdate = nil
    }

    func standardUserDriverWillFinishUpdateSession() {
        availableUpdate = nil
    }

    @discardableResult
    func row(_ menu: NSMenu, _ name: String, _ light: Light?, _ detail: String) -> LightRow {
        let view = LightRow(name, light: light, detail: detail)
        let item = NSMenuItem()
        item.view = view
        menu.addItem(item)
        return view
    }

    func menuWillOpen(_ menu: NSMenu) {
        // Common modes, so it also fires while the menu is tracking the mouse.
        let timer = Timer(timeInterval: 2, repeats: true) { [weak self] _ in self?.refreshLiveRows() }
        RunLoop.main.add(timer, forMode: .common)
        liveTimer = timer
    }

    func menuDidClose(_ menu: NSMenu) {
        liveTimer?.invalidate()
        liveTimer = nil
    }

    /// Re-reads the Wi-Fi readings (about 3 ms, no scan, nothing sent) and the agent's latest status.
    func refreshLiveRows() {
        guard let live = liveRows, let status = Store.loadStatus(), !status.isStale else { return }
        let config = Store.loadConfig()
        let ssid = CWWiFiClient.shared().interface()?.ssid()
        live.connection.update(networkName(status, ssid: ssid), light: status.connectionLight, detail: connectionDetail(status))
        let readings = status.gateway != nil ? linkReadings(status) : []
        for (i, row) in live.readings.enumerated() {
            row.update(row.name, light: nil, detail: i < readings.count ? readings[i].1 : "—")
        }
        live.protection.update(L("Protection"), light: status.protectionLight(config), detail: protectionDetail(status, config: config))
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
