import SwiftUI
import AppKit

@main
struct TroveApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        Settings { SettingsView() }
            .commands {
                CommandGroup(replacing: .appSettings) {
                    Button("Settings…") {
                        NotificationCenter.default.post(name: .openTroveSettings, object: nil)
                    }
                    .keyboardShortcut(",", modifiers: .command)
                }
            }
    }
}

extension Notification.Name {
    static let openTroveSettings = Notification.Name("openTroveSettings")
}

@available(macOS 14.0, *)
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
    private var settingsOpenerWindow: NSWindow?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        setupSettingsOpener()

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

    private func setupSettingsOpener() {
        if #available(macOS 14.0, *) {
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
        } else {
            NotificationCenter.default.addObserver(
                forName: .openTroveSettings,
                object: nil,
                queue: .main
            ) { _ in
                NSApp.sendAction(Selector(("showPreferencesWindow:")), to: nil, from: nil)
            }
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
