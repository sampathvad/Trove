import Carbon
import AppKit
import SwiftUI

// Global handler store — needed because C callbacks can't capture Swift context
private var _hotkeyHandlers: [UInt32: () -> Void] = [:]
private var _hotkeyHandlerRef: EventHandlerRef?

// C-compatible global callback for Carbon hotkey events
private func carbonHotkeyCallback(
    _: EventHandlerCallRef?,
    event: EventRef?,
    _: UnsafeMutableRawPointer?
) -> OSStatus {
    var hkID = EventHotKeyID()
    GetEventParameter(
        event,
        EventParamName(kEventParamDirectObject),
        EventParamType(typeEventHotKeyID),
        nil,
        MemoryLayout<EventHotKeyID>.size,
        nil,
        &hkID
    )
    let id = hkID.id
    DispatchQueue.main.async { _hotkeyHandlers[id]?() }
    return noErr
}

final class HotkeyService {
    static let shared = HotkeyService()

    private var hotKeyRefs: [String: EventHotKeyRef?] = [:]
    private var idCounter: UInt32 = 1

    private init() {
        installCarbonHandler()
    }

    func register(id: String, keyCode: Int, modifiers: Int, handler: @escaping () -> Void) {
        unregister(id: id)

        let uid = idCounter; idCounter += 1
        let hkID = EventHotKeyID(signature: fourCC("TRVE"), id: uid)
        var ref: EventHotKeyRef?
        let status = RegisterEventHotKey(
            UInt32(keyCode),
            UInt32(modifiers),
            hkID,
            GetApplicationEventTarget(),
            0,
            &ref
        )
        if status == noErr {
            hotKeyRefs[id] = ref
            _hotkeyHandlers[uid] = handler
        } else {
            print("HotkeyService: RegisterEventHotKey failed with status \(status)")
        }
    }

    func unregister(id: String) {
        if let ref = hotKeyRefs[id], let r = ref {
            UnregisterEventHotKey(r)
        }
        hotKeyRefs.removeValue(forKey: id)
    }

    private func installCarbonHandler() {
        var eventType = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )
        InstallEventHandler(
            GetApplicationEventTarget(),
            carbonHotkeyCallback,
            1,
            &eventType,
            nil,
            &_hotkeyHandlerRef
        )
    }

    private func fourCC(_ s: String) -> OSType {
        var result: OSType = 0
        for c in s.unicodeScalars.prefix(4) { result = (result << 8) + OSType(c.value) }
        return result
    }
}

// MARK: - Shortcut Recorder View

struct ShortcutRecorderView: View {
    let label: String
    @Binding var keyCode: Int
    @Binding var modifiers: Int
    @State private var isRecording = false
    @State private var monitor: Any?

    var body: some View {
        HStack {
            Text(label)
            Spacer()
            Button(isRecording ? "Press shortcut…" : shortcutString) {
                isRecording = true
                monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
                    let mods = carbonMods(from: event.modifierFlags)
                    if mods != 0 && event.keyCode != 53 {
                        self.keyCode = Int(event.keyCode)
                        self.modifiers = mods
                    }
                    self.isRecording = false
                    if let m = self.monitor { NSEvent.removeMonitor(m); self.monitor = nil }
                    return nil
                }
            }
            .buttonStyle(.bordered)
            .background(isRecording ? Color.accentColor.opacity(0.1) : Color.clear)
        }
    }

    private var shortcutString: String {
        var parts = [String]()
        if modifiers & Int(cmdKey)     != 0 { parts.append("⌘") }
        if modifiers & Int(shiftKey)   != 0 { parts.append("⇧") }
        if modifiers & Int(optionKey)  != 0 { parts.append("⌥") }
        if modifiers & Int(controlKey) != 0 { parts.append("⌃") }
        if let k = keyName(keyCode) { parts.append(k) }
        return parts.isEmpty ? "Click to record" : parts.joined()
    }

    private func carbonMods(from flags: NSEvent.ModifierFlags) -> Int {
        var m = 0
        if flags.contains(.command) { m |= Int(cmdKey) }
        if flags.contains(.shift)   { m |= Int(shiftKey) }
        if flags.contains(.option)  { m |= Int(optionKey) }
        if flags.contains(.control) { m |= Int(controlKey) }
        return m
    }

    private func keyName(_ code: Int) -> String? {
        [0:"A",1:"S",2:"D",3:"F",4:"H",5:"G",6:"Z",7:"X",8:"C",9:"V",
         11:"B",12:"Q",13:"W",14:"E",15:"R",16:"Y",17:"T",
         31:"O",32:"U",34:"I",35:"P",37:"L",38:"J",40:"K",45:"N",46:"M",
         51:"⌫",123:"←",124:"→",125:"↓",126:"↑"][code]
    }
}
