import Foundation

/// The parts that need root, done through the standard macOS administrator prompt: the sudoers
/// rule that lets the agent toggle awdl0, and the optional `hotspotly` link on the PATH.
public enum Setup {
    public static let sudoersPath = "/etc/sudoers.d/hotspotly"
    public static let cliLinkPath = "/usr/local/bin/hotspotly"

    public static var isRuleInstalled: Bool { FileManager.default.fileExists(atPath: sudoersPath) }

    /// The only root commands the agent ever runs.
    static var sudoersRule: String {
        "\(NSUserName()) ALL=(root) NOPASSWD: /sbin/ifconfig awdl0 down, /sbin/ifconfig awdl0 up\n"
    }

    public static func installRule() throws {
        let temp = FileManager.default.temporaryDirectory.appendingPathComponent("hotspotly.sudoers")
        try sudoersRule.write(to: temp, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(at: temp) }
        guard sh("/usr/sbin/visudo", ["-cf", temp.path]).status == 0 else {
            throw SetupError("the generated sudoers rule failed the visudo check")
        }
        try asAdmin("/usr/bin/install -m 0440 -o root -g wheel \(quoted(temp.path)) \(sudoersPath)")
    }

    /// The CLI ships inside the app; this only puts a link to it on the PATH.
    public static func cliIsLinked(to cli: String) -> Bool {
        (try? FileManager.default.destinationOfSymbolicLink(atPath: cliLinkPath)) == cli
    }

    public static func linkCLI(_ cli: String) throws {
        try asAdmin("/bin/mkdir -p /usr/local/bin && /bin/ln -sf \(quoted(cli)) \(cliLinkPath)")
    }

    public static func unlinkCLI() throws {
        try asAdmin("/bin/rm -f \(cliLinkPath)")
    }

    /// Forgets several remembered networks under one administrator prompt.
    public static func forget(_ ssids: [String]) throws {
        try asAdmin(ssids.map { "/usr/sbin/networksetup -removepreferredwirelessnetwork \(Net.wifiDevice) \(quoted($0))" }
            .joined(separator: "; "))
    }

    /// Removes everything outside the app bundle that needs root, in one prompt. awdl0 comes back up
    /// in the same root command: once the rule is gone the agent can no longer bring it down again.
    public static func removeAll(cli: String) throws {
        var command = "/sbin/ifconfig awdl0 up; /bin/rm -f \(sudoersPath)"
        if cliIsLinked(to: cli) { command += " \(cliLinkPath)" }
        try asAdmin(command)
    }

    /// Runs `command` as root after the system asks for an administrator's password.
    static func asAdmin(_ command: String) throws {
        let script = "do shell script \"\(command.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "\"", with: "\\\""))\" with administrator privileges"
        let result = sh("/usr/bin/osascript", ["-e", script])
        // -128 is the user pressing Cancel.
        guard result.status == 0 else {
            throw SetupError(result.output.contains("-128") ? "cancelled" : result.output)
        }
    }

    static func quoted(_ path: String) -> String {
        "'" + path.replacingOccurrences(of: "'", with: "'\\''") + "'"
    }
}

public struct SetupError: Error, CustomStringConvertible {
    public let description: String
    init(_ description: String) { self.description = description }
}
