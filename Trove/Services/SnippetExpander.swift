import AppKit
import Carbon

@MainActor
final class SnippetExpander {
    static let shared = SnippetExpander()
    private var eventTap: CFMachPort?
    private var typedBuffer = ""
    private(set) var snippets: [Snippet] = []

    private init() {}

    func start() {
        let mask = CGEventMask(1 << CGEventType.keyDown.rawValue)
        eventTap = CGEvent.tapCreate(
            tap: .cgAnnotatedSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: mask,
            callback: { proxy, type, event, refcon -> Unmanaged<CGEvent>? in
                guard let refcon else { return Unmanaged.passRetained(event) }
                let expander = Unmanaged<SnippetExpander>.fromOpaque(refcon).takeUnretainedValue()
                return expander.handleEvent(proxy: proxy, event: event)
            },
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        )
        guard let tap = eventTap else { return }
        let src = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), src, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
    }

    func stop() {
        if let tap = eventTap { CGEvent.tapEnable(tap: tap, enable: false) }
    }

    func update(_ newSnippets: [Snippet]) {
        snippets = newSnippets.filter { $0.isEnabled }
    }

    private func handleEvent(proxy: CGEventTapProxy, event: CGEvent) -> Unmanaged<CGEvent>? {
        guard let nsEvent = NSEvent(cgEvent: event) else { return Unmanaged.passRetained(event) }
        let char = nsEvent.characters ?? ""
        let isExpansion = [" ", "\n", "\t"].contains(char)

        if isExpansion {
            let prefix = TroveSettings.snippetTriggerPrefix
            if typedBuffer.hasPrefix(prefix) {
                let trigger = String(typedBuffer.dropFirst(prefix.count))
                if let snippet = snippets.first(where: { $0.trigger == trigger }) {
                    expand(snippet, deleteCount: typedBuffer.count)
                    typedBuffer = ""
                    return nil
                }
            }
            typedBuffer = ""
        } else if char == "\u{08}" {
            if !typedBuffer.isEmpty { typedBuffer.removeLast() }
        } else if !char.isEmpty && !nsEvent.modifierFlags.contains([.command, .control]) {
            typedBuffer.append(contentsOf: char)
            if typedBuffer.count > 64 { typedBuffer = String(typedBuffer.suffix(64)) }
        }
        return Unmanaged.passRetained(event)
    }

    private func expand(_ snippet: Snippet, deleteCount: Int) {
        for _ in 0..<deleteCount { simulateKey(51) } // delete key
        var content = snippet.content
        let df = DateFormatter()
        df.dateStyle = .short; df.timeStyle = .none
        content = content.replacingOccurrences(of: "{date}", with: df.string(from: Date()))
        df.dateStyle = .none; df.timeStyle = .short
        content = content.replacingOccurrences(of: "{time}", with: df.string(from: Date()))
        if let clip = NSPasteboard.general.string(forType: .string) {
            content = content.replacingOccurrences(of: "{clipboard}", with: clip)
        }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(content, forType: .string)
        PasteService.simulatePaste()
    }

    private func simulateKey(_ keyCode: CGKeyCode) {
        let src = CGEventSource(stateID: .hidSystemState)
        CGEvent(keyboardEventSource: src, virtualKey: keyCode, keyDown: true)?.post(tap: .cghidEventTap)
        CGEvent(keyboardEventSource: src, virtualKey: keyCode, keyDown: false)?.post(tap: .cghidEventTap)
    }
}
