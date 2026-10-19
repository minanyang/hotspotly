import AppKit
import CoreWLAN
import HotspotlyCore
import ServiceManagement
import Sparkle
import SwiftUI

/// What the Settings window shows, reloaded each time it opens and after every change.
final class SettingsModel: ObservableObject {
    @Published private(set) var config = Store.loadConfig()
    @Published private(set) var status: Status?
    @Published private(set) var ssid: String?
    @Published private(set) var openAtLogin = false
    @Published private(set) var cliLinked = false
    @Published private(set) var ruleInstalled = false
    @Published private(set) var networks: [NetworkRow] = []

    let cliPath: String
    /// Set by the app delegate, which owns the agent and the administrator prompts.
    var configChanged: () -> Void = {}
    var finishSetup: () -> Void = {}
    var asAdmin: (String, @escaping () throws -> Void, @escaping () -> Void) -> Void = { _, _, _ in }
    var uninstallApp: () -> Void = {}
    var checkForUpdates: () -> Void = {}
    var updater: SPUUpdater?

    var checksForUpdates: Bool {
        get { updater?.automaticallyChecksForUpdates ?? false }
        set {
            updater?.automaticallyChecksForUpdates = newValue
            objectWillChange.send()
        }
    }

    /// Downloads and installs in the background; the update applies when Hotspotly next quits.
    var installsUpdates: Bool {
        get { updater?.automaticallyDownloadsUpdates ?? false }
        set {
            updater?.automaticallyDownloadsUpdates = newValue
            objectWillChange.send()
        }
    }

    init(cliPath: String) {
        self.cliPath = cliPath
        reload()
    }

    func reload() {
        config = Store.loadConfig()
        status = Store.loadStatus()
        ssid = CWWiFiClient.shared().interface()?.ssid()
        openAtLogin = SMAppService.mainApp.status == .enabled
        cliLinked = Setup.cliIsLinked(to: cliPath)
        ruleInstalled = Setup.isRuleInstalled
    }

    /// Separate from `reload`, which runs after every change: a Mac can remember hundreds of networks.
    func loadNetworks() {
        let history = Store.loadHistory()
        networks = Net.rememberedNetworks().map { NetworkRow(network: $0, record: history[$0.ssid]) }
    }

    func forget(_ ssids: Set<String>) {
        let list = Array(ssids)
        asAdmin(L("Could not forget the networks"), { try Setup.forget(list) }) { [weak self] in
            Store.updateHistory { history in for ssid in list { history[ssid] = nil } }
            if let pin = self?.config.pin, ssids.contains(pin.ssid) { self?.update { $0.pin = nil } }
            Store.log("forgot \(list.count) network(s)")
            self?.loadNetworks()
        }
    }

    func update(_ change: (inout Config) -> Void) {
        Store.updateConfig(change)
        configChanged()
        reload()
    }

    func setAWDLMode(_ mode: Config.AWDLMode) {
        update { $0.awdlMode = mode }
        if mode != .never && !ruleInstalled { finishSetup() }
    }

    func setOpenAtLogin(_ on: Bool) {
        do {
            if on { try SMAppService.mainApp.register() } else { try SMAppService.mainApp.unregister() }
        } catch {
            Store.log("open at login: \(error.localizedDescription)")
        }
        reload()
    }

    func toggleCLI() {
        let path = cliPath
        asAdmin(L("Could not change the command line tool"), cliLinked ? Setup.unlinkCLI : { try Setup.linkCLI(path) }) {
            [weak self] in self?.reload()
        }
    }

    func mark(_ mac: String) {
        let name = ssid
        update {
            if !$0.hotspotMACs.contains(mac) { $0.hotspotMACs.append(mac) }
            $0.hotspotNames[mac] = name
        }
    }

    func unmark(_ mac: String) {
        update {
            $0.hotspotMACs.removeAll { $0 == mac }
            $0.hotspotNames[mac] = nil
        }
    }

    /// The current network, if it is not an iPhone hotspot (detected anyway) and not marked yet.
    var unmarkedCurrentMAC: String? {
        guard let mac = status?.gatewayMAC, status?.gateway != Net.iPhoneGateway,
              !config.hotspotMACs.contains(mac) else { return nil }
        return mac
    }
}

struct GeneralTab: View {
    @ObservedObject var model: SettingsModel

    var body: some View {
        Form {
            Toggle(L("Open at Login"), isOn: Binding(get: { model.openAtLogin }, set: model.setOpenAtLogin))
            VStack(alignment: .leading, spacing: 2) {
                Toggle(L("Hide Menu Bar Icon"), isOn: Binding(get: { model.config.hideIcon }, set: { on in model.update { $0.hideIcon = on } }))
                Text(L("Hotspotly keeps running. Open it again from Applications to see these settings."))
                    .font(.callout).foregroundStyle(.secondary)
            }
            LabeledContent(L("Command line tool")) {
                HStack {
                    Text(model.cliLinked ? Setup.cliLinkPath : L("Not installed")).foregroundStyle(.secondary)
                    Button(model.cliLinked ? L("Uninstall…") : L("Install…"), action: model.toggleCLI)
                }
            }
            LabeledContent(L("Log")) {
                Button(L("Open Log")) { NSWorkspace.shared.open(Store.logURL) }
            }
            Section {
                Button(L("Uninstall Hotspotly…"), role: .destructive, action: model.uninstallApp)
            }
        }
        .formStyle(.grouped)
        .frame(width: 480, height: 300)
    }
}

struct HotspotsTab: View {
    @ObservedObject var model: SettingsModel

    var body: some View {
        Form {
            Section {
                Picker(L("Turn Off AWDL"), selection: Binding(get: { model.config.awdlMode }, set: model.setAWDLMode)) {
                    Text(L("On Hotspots")).tag(Config.AWDLMode.hotspots)
                    Text(L("On All Networks")).tag(Config.AWDLMode.all)
                    Text(L("Never")).tag(Config.AWDLMode.never)
                }
                Text(L("AWDL is behind AirDrop, Universal Control and Sidecar, and makes phone hotspots drop. Turned off, those stop working until you allow AirDrop from the menu."))
                    .font(.callout).foregroundStyle(.secondary)
                if model.config.awdlMode != .never && !model.ruleInstalled {
                    LabeledContent(L("Needs an administrator rule")) {
                        Button(L("Finish Setup…"), action: model.finishSetup)
                    }
                }
            }
            Section(L("Hotspots")) {
                Text(L("iPhone hotspots are detected automatically. Mark others here, such as Android phones and pocket routers."))
                    .font(.callout).foregroundStyle(.secondary)
                if let mac = model.unmarkedCurrentMAC {
                    LabeledContent(model.ssid ?? L("Current network")) {
                        Button(L("Mark as Hotspot")) { model.mark(mac) }
                    }
                }
                ForEach(model.config.hotspotMACs, id: \.self) { mac in
                    LabeledContent {
                        Button(L("Remove")) { model.unmark(mac) }
                    } label: {
                        Text(model.config.hotspotNames[mac] ?? mac)
                        if model.config.hotspotNames[mac] != nil { Text(mac) }
                    }
                }
            }
        }
        .formStyle(.grouped)
        .frame(width: 480, height: 320)
    }
}

/// A remembered network, with what Hotspotly has seen of it.
struct NetworkRow: Identifiable {
    let network: Net.RememberedNetwork
    let record: NetworkRecord?

    var id: String { network.ssid }
    var name: String { network.ssid }
    /// Sorts networks without a record last.
    var lastConnected: Date { record?.lastConnected ?? .distantPast }

    var security: String {
        switch network.security {
        case .none: L("Open")
        case .WEP, .dynamicWEP: "WEP"
        case .wpaPersonal: "WPA"
        case .wpaPersonalMixed: "WPA/WPA2"
        case .wpa2Personal, .personal: "WPA2"
        case .wpa3Personal: "WPA3"
        case .wpa3Transition: "WPA2/WPA3"
        case .OWE, .oweTransition: L("Enhanced Open")
        case .wpaEnterprise, .wpaEnterpriseMixed, .wpa2Enterprise, .enterprise, .wpa3Enterprise: L("Enterprise")
        default: "—"
        }
    }

    /// Anyone nearby can read the traffic, or crack the password in minutes.
    var insecure: Bool { [.none, .WEP, .dynamicWEP].contains(network.security) }

    var quality: String {
        guard let record, let latency = record.latencyMs, let loss = record.packetLoss else { return "" }
        var parts = ["\(Int(latency.rounded())) ms", L("\(Int((loss * 100).rounded()))% loss")]
        if let rssi = record.rssi { parts.append("\(rssi) dBm") }
        if record.dropouts == 1 { parts.append(L("1 dropout")) }
        if record.dropouts > 1 { parts.append(L("\(record.dropouts) dropouts")) }
        return parts.joined(separator: " · ")
    }
}

struct NetworksTab: View {
    @ObservedObject var model: SettingsModel
    @State private var filter = ""
    @State private var selection = Set<String>()
    @State private var sortOrder = [KeyPathComparator(\NetworkRow.lastConnected, order: .reverse)]
    @State private var confirming = false

    var rows: [NetworkRow] {
        model.networks
            .filter { filter.isEmpty || $0.name.localizedCaseInsensitiveContains(filter) }
            .sorted(using: sortOrder)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            TextField(L("Filter"), text: $filter).textFieldStyle(.roundedBorder)
            Table(rows, selection: $selection, sortOrder: $sortOrder) {
                TableColumn(L("Name"), value: \.name)
                    .width(min: 120, max: 200)
                TableColumn(L("Security"), value: \.security) { row in
                    Text(row.security).foregroundStyle(row.insecure ? .orange : .primary)
                }
                .width(90)
                TableColumn(L("Last Connected"), value: \.lastConnected) { row in
                    if let date = row.record?.lastConnected {
                        Text(date, format: .relative(presentation: .named))
                    } else {
                        Text(L("No record")).foregroundStyle(.secondary)
                    }
                }
                .width(110)
                TableColumn(L("Quality")) { row in Text(row.quality).foregroundStyle(.secondary) }
                    .width(min: 280)
            }
            HStack {
                Text(L("\(model.networks.count) networks. Last connected and quality are recorded by Hotspotly from when it was installed."))
                    .font(.callout).foregroundStyle(.secondary)
                Spacer()
                Button(L("Forget…")) { confirming = true }.disabled(selection.isEmpty)
            }
        }
        .padding()
        .frame(width: 760, height: 440)
        .confirmationDialog(L("Forget \(selection.count) networks?"), isPresented: $confirming) {
            Button(L("Forget"), role: .destructive) {
                model.forget(selection)
                selection = []
            }
        } message: {
            Text(L("The Mac stops joining them automatically. This needs an administrator password."))
        }
    }
}

struct AboutTab: View {
    @ObservedObject var model: SettingsModel

    var body: some View {
        VStack(spacing: 8) {
            Image(nsImage: NSApp.applicationIconImage).resizable().frame(width: 96, height: 96)
            Text("Hotspotly").font(.title2.bold())
            Text(L("Version \(Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "?")"))
                .foregroundStyle(.secondary)
            Text(L("Keeps your Mac steady on phone hotspots and Wi-Fi.")).padding(.top, 4)
            Link("github.com/minanyang/hotspotly", destination: URL(string: "https://github.com/minanyang/hotspotly")!)
            Text(L("MIT License")).font(.caption).foregroundStyle(.secondary)
            Divider().padding(.vertical, 8)
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 6) {
                    Toggle(L("Check for Updates Automatically"), isOn: Binding(get: { model.checksForUpdates }, set: { model.checksForUpdates = $0 }))
                    Toggle(L("Install Updates Automatically"), isOn: Binding(get: { model.installsUpdates }, set: { model.installsUpdates = $0 }))
                        .disabled(!model.checksForUpdates)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 6) {
                    Button(L("Check Now"), action: model.checkForUpdates)
                    if let date = model.updater?.lastUpdateCheckDate {
                        Text(L("Last check: \(date.formatted(date: .abbreviated, time: .shortened))"))
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }
            }
            .padding(.horizontal, 24)
        }
        .padding(.vertical)
        .frame(width: 480, height: 380)
    }
}

/// Settings in a window with toolbar tabs, the usual layout for a Mac app's settings.
final class SettingsWindow {
    let model: SettingsModel
    private var window: NSWindow?

    init(model: SettingsModel) {
        self.model = model
    }

    func show() {
        model.reload()
        // Before the table appears: rows arriving afterwards leave it scrolled partway down.
        model.loadNetworks()
        if window == nil {
            let tabs = NSTabViewController()
            tabs.tabStyle = .toolbar
            for (title, symbol, view) in [
                (L("General"), "gearshape", AnyView(GeneralTab(model: model))),
                (L("Hotspots"), "personalhotspot", AnyView(HotspotsTab(model: model))),
                (L("Networks"), "wifi", AnyView(NetworksTab(model: model))),
                (L("About"), "info.circle", AnyView(AboutTab(model: model))),
            ] {
                let hosting = NSHostingController(rootView: view)
                hosting.sizingOptions = .preferredContentSize
                hosting.title = title  // the window title follows the selected tab
                let item = NSTabViewItem(viewController: hosting)
                item.label = title
                item.image = NSImage(systemSymbolName: symbol, accessibilityDescription: title)
                tabs.addTabViewItem(item)
            }
            let window = NSWindow(contentViewController: tabs)
            window.styleMask = [.titled, .closable]
            window.isReleasedWhenClosed = false
            window.center()
            self.window = window
        }
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
    }
}
