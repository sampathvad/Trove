import Foundation

extension Bundle {
    /// The user-facing marketing version (`CFBundleShortVersionString`),
    /// e.g. "0.1.11". Falls back to "—" if the key is somehow absent.
    static var appVersion: String {
        main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "—"
    }
}
