import Foundation

actor BlacklistService {
    static let shared = BlacklistService()
    private init() {}

    func isBlacklisted(_ bundleId: String) -> Bool {
        TroveSettings.blacklistedApps.contains(bundleId)
    }
}
