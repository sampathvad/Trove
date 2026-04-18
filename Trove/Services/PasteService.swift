import AppKit
import ApplicationServices

struct PasteService {

    static func paste(_ clip: Clip, asPlainText: Bool = false) {
        // Put content on clipboard first
        let pb = NSPasteboard.general
        pb.clearContents()

        if asPlainText, let text = clip.content.previewText {
            pb.setString(text, forType: .string)
        } else {
            switch clip.content {
            case .text(let s):      pb.setString(s, forType: .string)
            case .image(let data):  pb.setData(data, forType: .tiff)
            case .richText(let d):  pb.setData(d, forType: .rtf)
            case .file(let url):    pb.writeObjects([url as NSURL])
            }
        }

        // Only auto-paste if Accessibility is already granted — never prompt here
        if AXIsProcessTrusted() {
            simulatePaste()
        }
        // If not trusted, content is already on the clipboard — user presses ⌘V
    }

    static func simulatePaste() {
        let src = CGEventSource(stateID: .hidSystemState)
        let down = CGEvent(keyboardEventSource: src, virtualKey: 0x09, keyDown: true)
        let up   = CGEvent(keyboardEventSource: src, virtualKey: 0x09, keyDown: false)
        down?.flags = .maskCommand
        up?.flags   = .maskCommand
        down?.post(tap: .cghidEventTap)
        up?.post(tap: .cghidEventTap)
    }

    /// Call once at launch to request Accessibility — shows a friendly alert first
    @MainActor
    static func requestAccessibilityIfNeeded() {
        guard !AXIsProcessTrusted() else { return }

        let alert = NSAlert()
        alert.messageText = "Trove needs Accessibility access"
        alert.informativeText = "This lets Trove paste clips directly into any app when you press Enter. Without it, clips are still copied to your clipboard — just press ⌘V yourself after selecting.\n\nGrant access in System Settings → Privacy & Security → Accessibility."
        alert.addButton(withTitle: "Open System Settings")
        alert.addButton(withTitle: "Not now")
        alert.alertStyle = .informational

        if alert.runModal() == .alertFirstButtonReturn {
            NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!)
        }
    }
}
