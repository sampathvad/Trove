import SwiftUI
import AppKit

@main
struct TroveApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        Settings { SettingsView().background(SettingsActionBridge()) }
            .commands {
                CommandGroup(replacing: .appSettings) {
                    SettingsLink()
                        .keyboardShortcut(",", modifiers: .command)
                }
            }
    }
}

// Captures SwiftUI's openSettings action so AppKit code can call it.
private struct SettingsActionBridge: View {
    @Environment(\.openSettings) private var openSettings
    var body: some View {
        Color.clear.onAppear {
            SettingsActionStore.shared.open = { openSettings() }
        }
    }
}

@MainActor
final class SettingsActionStore {
    static let shared = SettingsActionStore()
    var open: (() -> Void)?
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
}
