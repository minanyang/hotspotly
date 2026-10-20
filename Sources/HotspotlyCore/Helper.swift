import Foundation
import ServiceManagement

/// The privileged helper's interface. It runs as root, so it does as little as possible: only these
/// calls, only from Hotspotly.app, and no shell.
@objc public protocol HelperProtocol {
    func version(reply: @escaping (String) -> Void)
    func setAWDL(up: Bool, reply: @escaping (Bool) -> Void)
    /// Replies with what went wrong, or "".
    func forget(_ ssids: [String], reply: @escaping (String) -> Void)
    /// Links /usr/local/bin/hotspotly to the CLI in the helper's own app bundle, or removes the link.
    func linkCLI(_ link: Bool, reply: @escaping (Bool) -> Void)
    /// Removes the sudoers rule that versions before the helper installed.
    func removeLegacyRule(reply: @escaping (Bool) -> Void)
}

public enum Helper {
    public static let label = "io.github.minanyang.hotspotly.helper"
    public static let plistName = "\(label).plist"

    /// Who may call the helper: Hotspotly.app signed by this team. Checked by the system for every
    /// connection, so a process that merely knows the service name gets nowhere.
    public static let clientRequirement =
        #"anchor apple generic and identifier "io.github.minanyang.hotspotly.bar" and certificate leaf[subject.OU] = "2JK3XFMC2R""#

    public static var interface: NSXPCInterface {
        let interface = NSXPCInterface(with: HelperProtocol.self)
        interface.setClasses(NSSet(array: [NSArray.self, NSString.self]) as! Set<AnyHashable>, for: #selector(HelperProtocol.forget(_:reply:)),
                             argumentIndex: 0, ofReply: false)
        return interface
    }

    public static var service: SMAppService { SMAppService.daemon(plistName: plistName) }
}

/// Talks to the helper once the user has allowed it. Every call returns nil when the helper is not
/// there, so callers fall back to the sudoers rule.
public enum HelperClient {
    static let lock = NSLock()
    static var connection: NSXPCConnection?
    /// After a failed call the helper is not tried again for a while: the AWDL watcher can call
    /// many times a second.
    static var retryAfter = Date.distantPast
    static var enabled = false
    static var enabledCheckedAt = Date.distantPast

    /// Until the user allows it, launchd holds messages to the helper instead of failing them, so
    /// calling it then would wait forever. nil-equivalent for the CLI, which is not the app bundle.
    static var isEnabled: Bool {
        if Date().timeIntervalSince(enabledCheckedAt) > 30 {
            enabled = Helper.service.status == .enabled
            enabledCheckedAt = Date()
        }
        return enabled
    }

    public static func version() -> String? {
        call { proxy, done in proxy.version { done($0) } }
    }

    public static func setAWDL(up: Bool) -> Bool? {
        call { proxy, done in proxy.setAWDL(up: up) { done($0) } }
    }

    /// "" when it worked, otherwise what went wrong; nil without the helper.
    public static func forget(_ ssids: [String]) -> String? {
        call(timeout: 120) { proxy, done in proxy.forget(ssids) { done($0) } }
    }

    public static func linkCLI(_ link: Bool) -> Bool? {
        call { proxy, done in proxy.linkCLI(link) { done($0) } }
    }

    public static func removeLegacyRule() -> Bool? {
        call { proxy, done in proxy.removeLegacyRule { done($0) } }
    }

    /// After the user allows or disallows the helper, so the next call does not wait for the cache.
    public static func statusChanged() {
        lock.lock()
        defer { lock.unlock() }
        enabledCheckedAt = .distantPast
        retryAfter = .distantPast
    }

    static func call<T>(timeout: TimeInterval = 2, _ body: (HelperProtocol, @escaping (T) -> Void) -> Void) -> T? {
        lock.lock()
        defer { lock.unlock() }
        guard Date() >= retryAfter, isEnabled else { return nil }
        if connection == nil {
            let new = NSXPCConnection(machServiceName: Helper.label, options: .privileged)
            new.remoteObjectInterface = Helper.interface
            // Runs later on an XPC queue; by then a newer connection may have replaced this one.
            new.invalidationHandler = { [weak new] in
                lock.lock()
                if connection === new { connection = nil }
                lock.unlock()
            }
            new.resume()
            connection = new
        }
        // Asynchronous with a timeout rather than the synchronous proxy, which has none.
        var result: T?
        let answered = DispatchSemaphore(value: 0)
        let proxy = connection?.remoteObjectProxyWithErrorHandler { _ in answered.signal() } as? HelperProtocol
        if let proxy {
            body(proxy) { value in
                result = value
                answered.signal()
            }
        }
        if proxy == nil || answered.wait(timeout: .now() + timeout) == .timedOut || result == nil {
            connection?.invalidate()
            connection = nil
            retryAfter = Date().addingTimeInterval(60)
        }
        return result
    }
}
