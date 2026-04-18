import AppKit
import SwiftUI

@MainActor
final class MenuBarController {
    private var statusItem: NSStatusItem
    private let panelController: PanelController
    private weak var monitor: ClipboardMonitor?
    private var isPaused = false
    private var pauseMenuItem: NSMenuItem?
    private var aboutWindow: NSWindow?

    init(panelController: PanelController, monitor: ClipboardMonitor? = nil) {
        self.panelController = panelController
        self.monitor = monitor
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        setupButton()
        setupMenu()
    }

    func setMonitor(_ m: ClipboardMonitor) {
        monitor = m
    }

    private func setupButton() {
        guard let button = statusItem.button else { return }
        button.image = menuBarIcon()
        button.action = #selector(statusItemClicked)
        button.action = #selector(statusItemClicked)
        button.target = self
        button.sendAction(on: [.leftMouseUp, .rightMouseUp])
    }

    @objc private func statusItemClicked(_ sender: NSStatusBarButton) {
        let event = NSApp.currentEvent
        if event?.type == .rightMouseUp {
            statusItem.menu?.popUp(positioning: nil, at: .zero, in: sender)
        } else if event?.modifierFlags.contains(.option) == true {
            NSApp.activate(ignoringOtherApps: true)
        } else {
            panelController.toggle()
        }
    }

    private func setupMenu() {
        let menu = NSMenu()

        menu.addItem(withTitle: "Open Trove", action: #selector(openPanel), keyEquivalent: "")
            .target = self

        menu.addItem(.separator())

        let pauseItem = NSMenuItem(title: "Pause capturing", action: #selector(toggleCapture), keyEquivalent: "")
        pauseItem.target = self
        menu.addItem(pauseItem)
        pauseMenuItem = pauseItem

        menu.addItem(.separator())

        menu.addItem(withTitle: "Settings…", action: #selector(openSettings), keyEquivalent: ",")
            .target = self

        menu.addItem(withTitle: "Clear history", action: #selector(clearHistory), keyEquivalent: "")
            .target = self

        menu.addItem(.separator())

        menu.addItem(withTitle: "About Trove", action: #selector(openAbout), keyEquivalent: "")
            .target = self
        menu.addItem(.separator())
        menu.addItem(withTitle: "Quit Trove", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")

        statusItem.menu = menu
    }

    @objc private func openPanel() { panelController.open() }

    @objc private func toggleCapture() {
        isPaused.toggle()
        Task {
            if isPaused {
                await monitor?.pause()
            } else {
                await monitor?.resume()
            }
        }
        pauseMenuItem?.title = isPaused ? "Resume capturing" : "Pause capturing"
        updateIcon()
    }

    @objc private func openAbout() {
        if aboutWindow == nil {
            let window = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 420, height: 560),
                styleMask: [.titled, .closable],
                backing: .buffered,
                defer: false
            )
            window.title = "About Trove"
            window.contentViewController = NSHostingController(rootView: AboutView())
            window.center()
            window.isReleasedWhenClosed = false
            // Return to accessory when window closes
            NotificationCenter.default.addObserver(
                forName: NSWindow.willCloseNotification,
                object: window, queue: .main
            ) { _ in
                NSApp.setActivationPolicy(.accessory)
            }
            aboutWindow = window
        }
        // Temporarily become a regular app so the window appears in front
        NSApp.setActivationPolicy(.regular)
        aboutWindow?.orderFrontRegardless()
        aboutWindow?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc private func openSettings() {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
    }

    @objc private func clearHistory() {
        let alert = NSAlert()
        alert.messageText = "Clear all history?"
        alert.informativeText = "This will delete all clips that aren't pinned. This can't be undone."
        alert.addButton(withTitle: "Clear history")
        alert.addButton(withTitle: "Cancel")
        alert.alertStyle = .warning
        if alert.runModal() == .alertFirstButtonReturn {
            Task { await ClipStore.shared.clearAll() }
        }
    }

    private func updateIcon() {
        statusItem.button?.image = menuBarIcon()
        statusItem.button?.alphaValue = isPaused ? 0.4 : 1.0
    }

    private func menuBarIcon() -> NSImage {
        let icon = NSImage(size: NSSize(width: 22, height: 22), flipped: false) { _ in
            // Load @2x if available, else @1x
            let img = Bundle.main.image(forResource: "MenuBarIcon@2x")
                   ?? Bundle.main.image(forResource: "MenuBarIcon")
                   ?? NSImage(systemSymbolName: "archivebox", accessibilityDescription: nil)!
            img.draw(in: NSRect(x: 0, y: 0, width: 22, height: 22))
            return true
        }
        // isTemplate = true makes macOS render it white in dark mode, dark in light mode
        icon.isTemplate = true
        return icon
    }

    func showFirstRunPopover() {
        guard let button = statusItem.button else { return }
        let popover = NSPopover()
        popover.contentViewController = NSHostingController(rootView: FirstRunView {
            popover.close()
        })
        popover.behavior = .transient
        popover.show(relativeTo: button.bounds, of: button, preferredEdge: .maxY)
    }
}
