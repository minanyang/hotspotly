import AppKit

/// The helper and in-app updates need the app in Applications. Opened from a disk image or from
/// Downloads, macOS runs it from a read-only copy (App Translocation) that Sparkle cannot replace.
enum MoveToApplications {
    static let destination = URL(fileURLWithPath: "/Applications/Hotspotly.app")

    /// Asks once per launch while the app runs from elsewhere. True when it moved and relaunched,
    /// so the caller should stop launching.
    static func offerIfNeeded() -> Bool {
        let running = Bundle.main.bundleURL
        let source = originalURL(of: running) ?? running
        let folder = source.deletingLastPathComponent().path
        let home = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Applications").path
        guard folder != "/Applications", folder != home else { return false }

        let alert = NSAlert()
        alert.messageText = L("Move Hotspotly to the Applications folder?")
        alert.informativeText = L("Its helper and updates only work from Applications.")
        alert.addButton(withTitle: L("Move to Applications"))
        alert.addButton(withTitle: L("Not Now"))
        NSApp.activate(ignoringOtherApps: true)
        guard alert.runModal() == .alertFirstButtonReturn else { return false }

        let files = FileManager.default
        do {
            if files.fileExists(atPath: destination.path) {
                try files.trashItem(at: destination, resultingItemURL: nil)
            }
            try files.copyItem(at: running, to: destination)
        } catch {
            SettingsModel.alert(L("Could not move Hotspotly"), L("Drag Hotspotly to the Applications folder, then open it from there."))
            return false
        }
        // Already checked by Gatekeeper; left in place, it would send the copy back to a read-only one.
        let xattr = Process()
        xattr.executableURL = URL(fileURLWithPath: "/usr/bin/xattr")
        xattr.arguments = ["-d", "-r", "com.apple.quarantine", destination.path]
        try? xattr.run()
        xattr.waitUntilExit()
        // A disk image is read-only; Downloads is not, and the old copy would only confuse later.
        try? files.trashItem(at: source, resultingItemURL: nil)

        let configuration = NSWorkspace.OpenConfiguration()
        configuration.createsNewApplicationInstance = true
        NSWorkspace.shared.openApplication(at: destination, configuration: configuration) { _, _ in
            DispatchQueue.main.async { NSApp.terminate(nil) }
        }
        return true
    }

    /// Where a translocated app really is. Security.framework exports this without a public header.
    static func originalURL(of url: URL) -> URL? {
        typealias IsTranslocated = @convention(c) (CFURL, UnsafeMutablePointer<Bool>, UnsafeMutablePointer<Unmanaged<CFError>?>?) -> Bool
        typealias OriginalPath = @convention(c) (CFURL, UnsafeMutablePointer<Unmanaged<CFError>?>?) -> Unmanaged<CFURL>?
        guard let security = dlopen("/System/Library/Frameworks/Security.framework/Security", RTLD_LAZY),
              let isSymbol = dlsym(security, "SecTranslocateIsTranslocatedURL"),
              let originalSymbol = dlsym(security, "SecTranslocateCreateOriginalPathForURL") else { return nil }
        var translocated = false
        guard unsafeBitCast(isSymbol, to: IsTranslocated.self)(url as CFURL, &translocated, nil), translocated,
              let original = unsafeBitCast(originalSymbol, to: OriginalPath.self)(url as CFURL, nil) else { return nil }
        return original.takeRetainedValue() as URL
    }
}
