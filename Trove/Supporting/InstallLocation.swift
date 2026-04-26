import AppKit

enum InstallLocation {
    private static let skipKey = "installLocationPromptSkipped"

    /// Returns true if the app is relaunching itself from /Applications and the
    /// caller should bail out of further startup work.
    @MainActor
    static func promptToMoveIfNeeded() -> Bool {
        let bundleURL = Bundle.main.bundleURL
        let path = bundleURL.path

        // Already installed correctly.
        if path.hasPrefix("/Applications/") || path.hasPrefix("\(NSHomeDirectory())/Applications/") {
            return false
        }

        // Skip during XCTest runs — the modal alert would block the test host
        // process and the runner times out at "Test runner never began executing
        // tests after launching".
        let env = ProcessInfo.processInfo.environment
        if env["XCTestConfigurationFilePath"] != nil ||
           env["XCTestSessionIdentifier"] != nil ||
           env["XCTestBundlePath"] != nil ||
           NSClassFromString("XCTestCase") != nil {
            return false
        }

        // Don't nag in DEBUG builds running from DerivedData.
        #if DEBUG
        if path.contains("/DerivedData/") || path.contains("/Build/Products/") {
            return false
        }
        #endif

        // Honor a previous "Don't move" choice.
        if UserDefaults.standard.bool(forKey: skipKey) {
            return false
        }

        let isFromDMG = path.hasPrefix("/Volumes/")
        return showAlert(bundleURL: bundleURL, isFromDMG: isFromDMG)
    }

    @MainActor
    private static func showAlert(bundleURL: URL, isFromDMG: Bool) -> Bool {
        let alert = NSAlert()
        alert.messageText = "Move Trove to Applications?"
        alert.informativeText = """
        Trove needs to live in the Applications folder so it can launch automatically at login and keep capturing your clipboard after restarts.

        Running from \(isFromDMG ? "the disk image" : "this location") will cause Trove to disappear after a reboot.
        """
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Move to Applications")
        alert.addButton(withTitle: "Don't Move")

        NSApp.activate(ignoringOtherApps: true)
        let response = alert.runModal()

        switch response {
        case .alertFirstButtonReturn:
            if moveAndRelaunch(from: bundleURL) {
                NSApp.terminate(nil)
                return true
            }
            return false
        default:
            UserDefaults.standard.set(true, forKey: skipKey)
            return false
        }
    }

    @MainActor
    private static func moveAndRelaunch(from source: URL) -> Bool {
        let destination = URL(fileURLWithPath: "/Applications")
            .appendingPathComponent(source.lastPathComponent)
        let fm = FileManager.default

        do {
            if fm.fileExists(atPath: destination.path) {
                try fm.removeItem(at: destination)
            }
            try fm.copyItem(at: source, to: destination)
        } catch {
            let alert = NSAlert()
            alert.messageText = "Couldn't move Trove"
            alert.informativeText = "Please drag Trove.app into your Applications folder manually.\n\n\(error.localizedDescription)"
            alert.alertStyle = .critical
            alert.addButton(withTitle: "OK")
            alert.runModal()
            return false
        }

        // Strip quarantine so Gatekeeper doesn't re-block on first launch from /Applications.
        let xattr = Process()
        xattr.launchPath = "/usr/bin/xattr"
        xattr.arguments = ["-dr", "com.apple.quarantine", destination.path]
        try? xattr.run()
        xattr.waitUntilExit()

        let task = Process()
        task.launchPath = "/usr/bin/open"
        task.arguments = [destination.path]
        try? task.run()
        return true
    }
}
