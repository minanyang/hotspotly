import Foundation

/// Sets up the LaunchAgent that runs the agent, and the sudoers rule that lets it toggle awdl0.
public enum Installer {
    public static let label = "io.github.minanyang.steadywifi"
    public static let sudoersPath = "/etc/sudoers.d/steadywifi"

    /// The user the agent runs as. Normally whoever runs the CLI; the pkg's postinstall
    /// runs as root and names the console user instead.
    struct Target {
        let name: String
        let uid: uid_t
        let gid: gid_t
        let home: URL

        static var current: Target {
            Target(name: NSUserName(), uid: getuid(), gid: getgid(), home: Store.home)
        }

        static func named(_ name: String) throws -> Target {
            guard let pw = getpwnam(name) else { throw InstallError("no such user '\(name)'") }
            return Target(name: name, uid: pw.pointee.pw_uid, gid: pw.pointee.pw_gid,
                          home: URL(fileURLWithPath: String(cString: pw.pointee.pw_dir)))
        }

        var plistURL: URL { home.appendingPathComponent("Library/LaunchAgents/\(Installer.label).plist") }
        var logURL: URL { home.appendingPathComponent("Library/Logs/steadywifi.log") }
        var domain: String { "gui/\(uid)" }
    }

    /// `user` is only accepted when running as root (the pkg's postinstall).
    public static func install(executable: String, user: String? = nil) throws {
        let asRoot = getuid() == 0
        if user != nil && !asRoot { throw InstallError("--user requires running as root") }
        if asRoot && user == nil { throw InstallError("as root, pass --user <name> for the user the agent runs as") }
        let target = try user.map(Target.named) ?? .current

        try installSudoersRule(for: target, asRoot: asRoot)

        let plist: [String: Any] = [
            "Label": label,
            "ProgramArguments": [executable, "run"],
            "RunAtLoad": true,
            "KeepAlive": true,
            "StandardErrorPath": target.logURL.path,
        ]
        let data = try PropertyListSerialization.data(fromPropertyList: plist, format: .xml, options: 0)
        let dir = target.plistURL.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        try data.write(to: target.plistURL)
        if asRoot {
            chown(dir.path, target.uid, target.gid)
            chown(target.plistURL.path, target.uid, target.gid)
        }

        sh("/bin/launchctl", ["bootout", "\(target.domain)/\(label)"])
        let result = sh("/bin/launchctl", ["bootstrap", target.domain, target.plistURL.path])
        // As root with nobody logged in there is no gui domain yet; launchd loads the plist at next login.
        guard result.status == 0 || asRoot else { throw InstallError("launchctl bootstrap failed: \(result.output)") }
    }

    public static func uninstall() {
        let target = Target.current
        sh("/bin/launchctl", ["bootout", "\(target.domain)/\(label)"])
        try? FileManager.default.removeItem(at: target.plistURL)
        _ = Net.setAWDL(up: true)
        if FileManager.default.fileExists(atPath: sudoersPath) {
            interactive("/usr/bin/sudo", ["/bin/rm", "-f", sudoersPath])
        }
    }

    public static var isInstalled: Bool {
        FileManager.default.fileExists(atPath: Target.current.plistURL.path)
    }

    /// The only root commands the agent ever runs.
    static func sudoersRule(for target: Target) -> String {
        "\(target.name) ALL=(root) NOPASSWD: /sbin/ifconfig awdl0 down, /sbin/ifconfig awdl0 up\n"
    }

    static func installSudoersRule(for target: Target, asRoot: Bool) throws {
        let temp = FileManager.default.temporaryDirectory.appendingPathComponent("steadywifi.sudoers")
        try sudoersRule(for: target).write(to: temp, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(at: temp) }

        guard sh("/usr/sbin/visudo", ["-cf", temp.path]).status == 0 else {
            throw InstallError("generated sudoers rule failed visudo check")
        }
        let installArgs = ["-m", "0440", "-o", "root", "-g", "wheel", temp.path, sudoersPath]
        let status: Int32
        if asRoot {
            status = interactive("/usr/bin/install", installArgs)
        } else {
            print("Adding \(sudoersPath) (allows only `ifconfig awdl0 up|down`); sudo may ask for your password.")
            status = interactive("/usr/bin/sudo", ["/usr/bin/install"] + installArgs)
        }
        guard status == 0 else { throw InstallError("could not install \(sudoersPath)") }
    }
}

public struct InstallError: Error, CustomStringConvertible {
    public let description: String
    init(_ description: String) { self.description = description }
}
