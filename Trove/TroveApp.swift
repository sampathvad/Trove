import SwiftUI
import AppKit

@main
struct TroveApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @Environment(\.openSettings) private var openSettings

    var body: some Scene {
        Settings { SettingsView() }
            .commands {
                CommandGroup(replacing: .appSettings) {
                    Button("Settings…") { openSettings() }
                        .keyboardShortcut(",", modifiers: .command)
                }
            }
    }
}

// Notification used to ask SwiftUI to open Settings from AppKit code
extension Notification.Name {
    static let openTroveSettings = Notification.Name("openTroveSettings")
}

// Invisible SwiftUI view that listens for the notification and calls openSettings()
struct SettingsOpener: View {
    @Environment(\.openSettings) private var openSettings

    var body: some View {
        Color.clear
            .onReceive(NotificationCenter.default.publisher(for: .openTroveSettings)) { _ in
                openSettings()
            }
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var menuBarController: MenuBarController?
    private var clipboardMonitor: ClipboardMonitor?
    // Keep the settings opener window alive
    private var settingsOpenerWindow: NSWindow?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        // Host the SettingsOpener in a hidden offscreen window
        let win = NSWindow(
            contentRect: .zero,
            styleMask: [],
            backing: .buffered,
            defer: true
        )
        win.contentViewController = NSHostingController(rootView: SettingsOpener())
        win.setFrameOrigin(NSPoint(x: -9999, y: -9999))
        win.orderFront(nil)
        settingsOpenerWindow = win

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
        let nc = NSWorkspace.shared.notificationCenter
        nc.addObserver(forName: NSWorkspace.screensDidSleepNotification, object: nil, queue: .main) { [weak self] _ in
            Task { await self?.clipboardMonitor?.pause() }
            if TroveSettings.clearHistoryOnLock { Task { await ClipStore.shared.clearAll() } }
        }
        nc.addObserver(forName: NSWorkspace.screensDidWakeNotification, object: nil, queue: .main) { [weak self] _ in
            Task { await self?.clipboardMonitor?.resume() }
        }
    }

    private func showFirstRunIfNeeded() {
        guard !TroveSettings.hasShownFirstRun else { return }
        menuBarController?.showFirstRunPopover()
        TroveSettings.hasShownFirstRun = true
    }
}
