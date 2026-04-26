import SwiftUI
import AppKit
import ServiceManagement

@main
struct TroveApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        Settings { SettingsView() }
            .commands {
                CommandGroup(replacing: .appSettings) {
                    SettingsLink()
                        .keyboardShortcut(",", modifiers: .command)
                }
            }
    }
}

extension Notification.Name {
    static let openTroveSettings = Notification.Name("openTroveSettings")
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var menuBarController: MenuBarController?
    private var clipboardMonitor: ClipboardMonitor?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        // When the app is launched as a unit-test host, XCTest is about to
        // inject the test bundle. Skip all real startup work: it would block
        // the main thread, request accessibility permissions, and otherwise
        // confuse the test runner into timing out.
        if isRunningTests { return }

        if InstallLocation.promptToMoveIfNeeded() { return }

        Task {
            await ClipStore.shared.setup()
            await CollectionStore.shared.load()
        }

        let monitor = ClipboardMonitor()
        clipboardMonitor = monitor
        menuBarController = MenuBarController(panelController: PanelController.shared)
        menuBarController?.setMonitor(monitor)
        Task { await monitor.start() }

        registerHotkeys()
        SnippetExpander.shared.start()
        observeScreenLock()
        showFirstRunIfNeeded()
        syncLaunchAtLogin()

        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            PasteService.requestAccessibilityIfNeeded()
        }
    }

    private func registerHotkeys() {
        HotkeyService.shared.register(
            id: "openPanel",
            keyCode: TroveSettings.openPanelKeyCode,
            modifiers: TroveSettings.openPanelModifiers
        ) {
            PanelController.shared.toggle()
        }
    }

    private func observeScreenLock() {
        let workspaceCenter = NSWorkspace.shared.notificationCenter
        workspaceCenter.addObserver(forName: NSWorkspace.screensDidSleepNotification, object: nil, queue: .main) { [weak self] _ in
            Task { await self?.clipboardMonitor?.pause() }
            if TroveSettings.clearHistoryOnLock { Task { await ClipStore.shared.clearAll() } }
        }
        workspaceCenter.addObserver(forName: NSWorkspace.screensDidWakeNotification, object: nil, queue: .main) { [weak self] _ in
            Task { await self?.clipboardMonitor?.resume() }
        }
    }

    private func showFirstRunIfNeeded() {
        guard !TroveSettings.hasShownFirstRun else { return }
        menuBarController?.showFirstRunPopover()
        TroveSettings.hasShownFirstRun = true
    }

    private var isRunningTests: Bool {
        let env = ProcessInfo.processInfo.environment
        return env["XCTestConfigurationFilePath"] != nil
            || env["XCTestSessionIdentifier"] != nil
            || env["XCTestBundlePath"] != nil
            || NSClassFromString("XCTestCase") != nil
    }

    private func syncLaunchAtLogin() {
        let service = SMAppService.mainApp
        if TroveSettings.launchAtLogin {
            if service.status != .enabled {
                do {
                    try service.register()
                } catch {
                    AuditLog.launchAtLoginFailed(error: error)
                }
            }
        } else {
            if service.status == .enabled {
                do {
                    try service.unregister()
                } catch {
                    AuditLog.launchAtLoginFailed(error: error)
                }
            }
        }
    }
}
