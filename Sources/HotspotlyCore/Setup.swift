import Foundation

/// Paths outside the app bundle. The privileged helper changes them; versions before it used a
/// sudoers rule, which the helper removes once the user allows it.
public enum Setup {
    public static let sudoersPath = "/etc/sudoers.d/hotspotly"
    public static let cliLinkPath = "/usr/local/bin/hotspotly"

    /// The rule from versions before the helper; the agent still uses it until the helper is allowed.
    public static var isRuleInstalled: Bool { FileManager.default.fileExists(atPath: sudoersPath) }

    /// The CLI ships inside the app; this only puts a link to it on the PATH.
    public static func cliIsLinked(to cli: String) -> Bool {
        (try? FileManager.default.destinationOfSymbolicLink(atPath: cliLinkPath)) == cli
    }

    /// For uninstalling without the helper: removes what needs root in one administrator prompt.
    /// awdl0 comes back up in the same command, since nothing can bring it back afterwards.
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
}

public struct SetupError: Error, CustomStringConvertible {
    public let description: String
    init(_ description: String) { self.description = description }
}
