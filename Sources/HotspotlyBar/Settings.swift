import AppKit
import CoreWLAN
import HotspotlyCore
import ServiceManagement
import SwiftUI

/// What the Settings window shows, reloaded each time it opens and after every change.
final class SettingsModel: ObservableObject {
    @Published private(set) var config = Store.loadConfig()
    @Published private(set) var status: Status?
    @Published private(set) var ssid: String?
    @Published private(set) var openAtLogin = false
    @Published private(set) var cliLinked = false
    @Published private(set) var ruleInstalled = false

    let cliPath: String
    /// Set by the app delegate, which owns the agent and the administrator prompts.
    var configChanged: () -> Void = {}
    var finishSetup: () -> Void = {}
    var asAdmin: (String, @escaping () throws -> Void, @escaping () -> Void) -> Void = { _, _, _ in }
    var uninstallApp: () -> Void = {}

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
        .frame(width: 480, height: 250)
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

struct AboutTab: View {
    var body: some View {
        VStack(spacing: 8) {
            Image(nsImage: NSApp.applicationIconImage).resizable().frame(width: 96, height: 96)
            Text("Hotspotly").font(.title2.bold())
            Text(L("Version \(Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "?")"))
                .foregroundStyle(.secondary)
            Text(L("Keeps your Mac steady on phone hotspots and Wi-Fi.")).padding(.top, 4)
            Link("github.com/minanyang/hotspotly", destination: URL(string: "https://github.com/minanyang/hotspotly")!)
            Text(L("MIT License")).font(.caption).foregroundStyle(.secondary)
        }
        .frame(width: 480, height: 280)
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
        if window == nil {
            let tabs = NSTabViewController()
            tabs.tabStyle = .toolbar
            for (title, symbol, view) in [
                (L("General"), "gearshape", AnyView(GeneralTab(model: model))),
                (L("Hotspots"), "personalhotspot", AnyView(HotspotsTab(model: model))),
                (L("About"), "info.circle", AnyView(AboutTab())),
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
