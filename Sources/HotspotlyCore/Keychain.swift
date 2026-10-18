import Foundation

/// Wi-Fi passwords of pinned networks, kept in the login keychain because networksetup cannot read
/// the ones macOS keeps in the System keychain. Goes through /usr/bin/security so the item's access
/// list names that tool rather than this binary, whose ad-hoc signature changes with every build.
public enum Keychain {
    static let service = "io.github.minanyang.hotspotly"

    /// "" for an open network.
    public static func password(for ssid: String) -> String? {
        let result = sh("/usr/bin/security", ["find-generic-password", "-s", service, "-a", ssid, "-w"])
        return result.status == 0 ? result.output : nil
    }

    public static func save(_ password: String, for ssid: String) {
        sh("/usr/bin/security", ["add-generic-password", "-U", "-s", service, "-a", ssid, "-w", password])
    }
}
