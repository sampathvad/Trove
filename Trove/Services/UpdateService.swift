import Foundation
import Combine
import Sparkle

/// Thin wrapper around Sparkle's `SPUStandardUpdaterController`.
///
/// Owns the single app-wide updater. Instantiating it starts Sparkle's
/// background scheduler, so it is created once from `AppDelegate` at launch
/// (and never under XCTest, which short-circuits startup). The feed URL and
/// the EdDSA public key that authenticates updates live in `Info.plist`
/// (`SUFeedURL`, `SUPublicEDKey`) — see `RELEASING.md` for how those are
/// produced and signed.
@MainActor
final class UpdateService: NSObject, ObservableObject {
    static let shared = UpdateService()

    private let controller: SPUStandardUpdaterController

    /// Mirrors Sparkle's own gate for whether a check can be initiated right
    /// now (false while a check/download is already in flight). Drives the
    /// enabled state of the menu item and the "Check Now" button.
    @Published private(set) var canCheckForUpdates = false

    /// Whether Sparkle silently checks for updates on its own schedule.
    var automaticallyChecksForUpdates: Bool {
        get { controller.updater.automaticallyChecksForUpdates }
        set { controller.updater.automaticallyChecksForUpdates = newValue }
    }

    private override init() {
        // `startingUpdater: true` boots the background scheduler immediately.
        controller = SPUStandardUpdaterController(
            startingUpdater: true,
            updaterDelegate: nil,
            userDriverDelegate: nil
        )
        super.init()
        // `canCheckForUpdates` is KVO-compliant; bridge it to @Published.
        controller.updater.publisher(for: \.canCheckForUpdates)
            .receive(on: RunLoop.main)
            .assign(to: &$canCheckForUpdates)
    }

    /// Shows Sparkle's standard "checking / up to date / update available" UI.
    func checkForUpdates() {
        controller.updater.checkForUpdates()
    }
}
