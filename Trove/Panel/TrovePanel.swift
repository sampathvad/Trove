import AppKit
import SwiftUI

extension Notification.Name {
    static let trovePanelShortcut = Notification.Name("TrovePanelShortcut")
}

final class TrovePanel: NSPanel {
    private var hasInstalledContent = false

    init() {
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: 620, height: 540),
            styleMask: [.nonactivatingPanel, .titled, .fullSizeContentView, .resizable],
            backing: .buffered,
            defer: true
        )
        isFloatingPanel = true
        level = .floating
        titlebarAppearsTransparent = true
        titleVisibility = .hidden
        isMovableByWindowBackground = true
        hidesOnDeactivate = false
        minSize = NSSize(width: 500, height: 400)
        standardWindowButton(.miniaturizeButton)?.isHidden = true
        standardWindowButton(.zoomButton)?.isHidden = true
    }

    /// Build the SwiftUI hierarchy the first time the panel is shown so the
    /// cold render cost doesn't land on the launch run loop.
    func installContentIfNeeded() {
        guard !hasInstalledContent else { return }
        hasInstalledContent = true
        let host = NSHostingController(rootView: PanelView())
        host.view.frame = NSRect(x: 0, y: 0, width: 620, height: 540)
        host.view.autoresizingMask = [.width, .height]
        contentViewController = host
    }

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}

@MainActor
final class PanelController {
    static let shared = PanelController()
    private lazy var panel: TrovePanel = TrovePanel()
    private var mouseMonitor: Any?
    private var keyMonitor: Any?

    private init() {}

    func toggle() { panel.isVisible ? close() : open() }

    func open() {
        panel.installContentIfNeeded()
        positionPanel()
        panel.setContentSize(NSSize(width: 620, height: 540))
        panel.makeKeyAndOrderFront(nil)
        startMouseMonitor()
        startKeyMonitor()
    }

    func close() {
        stopKeyMonitor()
        stopMouseMonitor()
        panel.orderOut(nil)
    }

    // Close panel then paste — gives the previous app time to reactivate
    func closeAndPaste(_ clip: Clip, asPlainText: Bool = false) {
        close()
        // Small delay lets the source app become active before we simulate Cmd+V
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            PasteService.paste(clip, asPlainText: asPlainText)
        }
    }

    // Close panel then paste raw text (e.g. AI-transformed output).
    func closeAndPasteText(_ text: String) {
        close()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            PasteService.pasteText(text)
        }
    }

    private func startMouseMonitor() {
        stopMouseMonitor()
        mouseMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            guard let self, self.panel.isVisible else { return }
            let mouse = NSEvent.mouseLocation
            if !self.panel.frame.contains(mouse) {
                self.close()
            }
        }
    }

    private func stopMouseMonitor() {
        if let m = mouseMonitor { NSEvent.removeMonitor(m) }
        mouseMonitor = nil
    }

    private static let shortcutChars: Set<String> = ["p", "k", "z", "\u{7F}", "1", "2", "3", "4", "5", "6", "7", "8", "9"]

    private func startKeyMonitor() {
        stopKeyMonitor()
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self, self.panel.isVisible, event.window === self.panel else { return event }
            let mods = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
            guard mods == .command || mods == [.command, .numericPad] else { return event }
            var chars = (event.charactersIgnoringModifiers ?? "").lowercased()
            if event.keyCode == 51 { chars = "\u{7F}" }
            guard !chars.isEmpty, Self.shortcutChars.contains(chars) else { return event }
            if event.isARepeat { return nil }
            NotificationCenter.default.post(name: .trovePanelShortcut, object: event)
            return nil
        }
    }

    private func stopKeyMonitor() {
        if let m = keyMonitor { NSEvent.removeMonitor(m) }
        keyMonitor = nil
    }

    private func positionPanel() {
        switch TroveSettings.panelPosition {
        case .centerScreen:
            panel.center()
        case .underCursor:
            let pt = NSEvent.mouseLocation
            panel.setFrameOrigin(clamp(NSPoint(
                x: pt.x - panel.frame.width / 2,
                y: pt.y - panel.frame.height - 8
            )))
        case .lastPosition:
            let x = TroveSettings.lastPanelX, y = TroveSettings.lastPanelY
            if x == 0 && y == 0 { panel.center() }
            else { panel.setFrameOrigin(clamp(NSPoint(x: x, y: y))) }
        }
    }

    private func clamp(_ o: NSPoint) -> NSPoint {
        guard let f = NSScreen.main?.visibleFrame else { return o }
        return NSPoint(
            x: min(max(o.x, f.minX), f.maxX - panel.frame.width),
            y: min(max(o.y, f.minY), f.maxY - panel.frame.height)
        )
    }
}
