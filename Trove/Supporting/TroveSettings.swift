import Foundation
import AppKit
import Carbon

// Type-safe UserDefaults wrapper — replaces Defaults package

enum TroveSettings {
    private static let ud = UserDefaults.standard

    // MARK: - General
    static var hasShownFirstRun: Bool {
        get { ud.bool(forKey: "hasShownFirstRun") }
        set { ud.set(newValue, forKey: "hasShownFirstRun") }
    }
    static var launchAtLogin: Bool {
        get { ud.object(forKey: "launchAtLogin") as? Bool ?? true }
        set { ud.set(newValue, forKey: "launchAtLogin") }
    }
    static var pollingIntervalMs: Int {
        get { ud.object(forKey: "pollingIntervalMs") as? Int ?? 500 }
        set { ud.set(newValue, forKey: "pollingIntervalMs") }
    }
    static var maxHistoryCount: Int {
        get { ud.object(forKey: "maxHistoryCount") as? Int ?? 1000 }
        set { ud.set(newValue, forKey: "maxHistoryCount") }
    }
    static var historyRetentionDays: Int {
        get { ud.object(forKey: "historyRetentionDays") as? Int ?? 30 }
        set { ud.set(newValue, forKey: "historyRetentionDays") }
    }

    // MARK: - Capture
    static var storeSensitiveClips: Bool {
        get { ud.bool(forKey: "storeSensitiveClips") }
        set { ud.set(newValue, forKey: "storeSensitiveClips") }
    }
    static var blacklistedApps: [String] {
        get { ud.stringArray(forKey: "blacklistedApps") ?? defaultBlacklist }
        set { ud.set(newValue, forKey: "blacklistedApps") }
    }
    static let defaultBlacklist = [
        "com.1password.1password", "com.1password.1password7",
        "com.agilebits.onepassword7", "com.bitwarden.desktop",
        "com.dashlane.dashlane", "com.lastpass.LastPass",
        "com.apple.keychainaccess", "com.apple.Passwords",
        "com.enpass.Enpass", "com.keepassium.mac",
    ]
    static var captureImages: Bool {
        get { ud.object(forKey: "captureImages") as? Bool ?? true }
        set { ud.set(newValue, forKey: "captureImages") }
    }
    static var captureFiles: Bool {
        get { ud.object(forKey: "captureFiles") as? Bool ?? true }
        set { ud.set(newValue, forKey: "captureFiles") }
    }
    static var captureRichText: Bool {
        get { ud.object(forKey: "captureRichText") as? Bool ?? true }
        set { ud.set(newValue, forKey: "captureRichText") }
    }
    static var maxClipSizeKB: Int {
        get { ud.object(forKey: "maxClipSizeKB") as? Int ?? 1024 }
        set { ud.set(newValue, forKey: "maxClipSizeKB") }
    }
    static var autoSkipPasswords: Bool {
        get { ud.object(forKey: "autoSkipPasswords") as? Bool ?? true }
        set { ud.set(newValue, forKey: "autoSkipPasswords") }
    }
    static var clearHistoryOnLock: Bool {
        get { ud.bool(forKey: "clearHistoryOnLock") }
        set { ud.set(newValue, forKey: "clearHistoryOnLock") }
    }

    // MARK: - Panel
    static var panelWidth: Double {
        get { ud.object(forKey: "panelWidth") as? Double ?? 560 }
        set { ud.set(newValue, forKey: "panelWidth") }
    }
    static var panelDensity: PanelDensity {
        get { PanelDensity(rawValue: ud.string(forKey: "panelDensity") ?? "") ?? .comfortable }
        set { ud.set(newValue.rawValue, forKey: "panelDensity") }
    }
    static var panelPosition: PanelPositionMode {
        get { PanelPositionMode(rawValue: ud.string(forKey: "panelPosition") ?? "") ?? .centerScreen }
        set { ud.set(newValue.rawValue, forKey: "panelPosition") }
    }
    static var lastPanelX: Double {
        get { ud.double(forKey: "lastPanelX") }
        set { ud.set(newValue, forKey: "lastPanelX") }
    }
    static var lastPanelY: Double {
        get { ud.double(forKey: "lastPanelY") }
        set { ud.set(newValue, forKey: "lastPanelY") }
    }
    static var showSourceApp: Bool {
        get { ud.object(forKey: "showSourceApp") as? Bool ?? true }
        set { ud.set(newValue, forKey: "showSourceApp") }
    }
    static var showRelativeTime: Bool {
        get { ud.object(forKey: "showRelativeTime") as? Bool ?? true }
        set { ud.set(newValue, forKey: "showRelativeTime") }
    }
    static var appearanceMode: AppearanceMode {
        get { AppearanceMode(rawValue: ud.string(forKey: "appearanceMode") ?? "") ?? .auto }
        set { ud.set(newValue.rawValue, forKey: "appearanceMode") }
    }

    // MARK: - Snippets
    static var snippetTriggerPrefix: String {
        get { ud.string(forKey: "snippetTriggerPrefix") ?? ";" }
        set { ud.set(newValue, forKey: "snippetTriggerPrefix") }
    }

    // MARK: - Sync
    static var iCloudSyncEnabled: Bool {
        get { ud.bool(forKey: "iCloudSyncEnabled") }
        set { ud.set(newValue, forKey: "iCloudSyncEnabled") }
    }
    static var syncClips: Bool {
        get { ud.object(forKey: "syncClips") as? Bool ?? true }
        set { ud.set(newValue, forKey: "syncClips") }
    }
    static var syncSnippets: Bool {
        get { ud.object(forKey: "syncSnippets") as? Bool ?? true }
        set { ud.set(newValue, forKey: "syncSnippets") }
    }
    static var syncFilters: Bool {
        get { ud.object(forKey: "syncFilters") as? Bool ?? true }
        set { ud.set(newValue, forKey: "syncFilters") }
    }
    static var syncHistoryLimit: Int {
        get { ud.object(forKey: "syncHistoryLimit") as? Int ?? 500 }
        set { ud.set(newValue, forKey: "syncHistoryLimit") }
    }

    // MARK: - AI
    static var aiEnabled: Bool {
        get { ud.bool(forKey: "aiEnabled") }
        set { ud.set(newValue, forKey: "aiEnabled") }
    }
    static var aiProvider: String {
        get { ud.string(forKey: "aiProvider") ?? "openai" }
        set { ud.set(newValue, forKey: "aiProvider") }
    }

    // MARK: - Hotkeys (stored as keyCode + modifiers)
    static var openPanelKeyCode: Int {
        get { ud.object(forKey: "openPanelKeyCode") as? Int ?? 9 } // V
        set { ud.set(newValue, forKey: "openPanelKeyCode") }
    }
    static var openPanelModifiers: Int {
        get { ud.object(forKey: "openPanelModifiers") as? Int ?? Int(cmdKey | shiftKey) }
        set { ud.set(newValue, forKey: "openPanelModifiers") }
    }

    // MARK: - Reset
    static func resetAll() {
        let domain = Bundle.main.bundleIdentifier ?? "app.trove.Trove"
        UserDefaults.standard.removePersistentDomain(forName: domain)
    }
}

// MARK: - Enums

enum PanelDensity: String, CaseIterable {
    case compact, comfortable, spacious
    var rowHeight: Double {
        switch self {
        case .compact: return 40
        case .comfortable: return 56
        case .spacious: return 72
        }
    }
}

enum AppearanceMode: String, CaseIterable {
    case auto, light, dark
    var displayName: String { rawValue.capitalized }
}

enum PanelPositionMode: String, CaseIterable {
    case underCursor, centerScreen, lastPosition
    var displayName: String {
        switch self {
        case .underCursor: return "Under cursor"
        case .centerScreen: return "Center of screen"
        case .lastPosition: return "Last position"
        }
    }
}
