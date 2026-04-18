import SwiftUI
import ServiceManagement
import AppKit

struct SettingsView: View {
    private enum Tab: String, CaseIterable {
        case general, clipboard, hotkeys, appearance, privacy, snippets, filters, ai, advanced
        var displayName: String { rawValue.capitalized }
        var icon: String {
            switch self {
            case .general: return "gearshape"
            case .clipboard: return "clipboard"
            case .hotkeys: return "keyboard"
            case .appearance: return "paintbrush"
            case .privacy: return "lock.shield"
            case .snippets: return "text.badge.plus"
            case .filters: return "wand.and.stars"
            case .ai: return "sparkles"
            case .advanced: return "wrench.and.screwdriver"
            }
        }
    }

    @State private var selectedTab: Tab = .general

    var body: some View {
        TabView(selection: $selectedTab) {
            ForEach(Tab.allCases, id: \.self) { tab in
                tabContent(for: tab)
                    .tabItem { Label(tab.displayName, systemImage: tab.icon) }
                    .tag(tab)
            }
        }
        .frame(width: 580, height: 460)
    }

    @ViewBuilder
    private func tabContent(for tab: Tab) -> some View {
        switch tab {
        case .general:    GeneralSettingsView()
        case .clipboard:  ClipboardSettingsView()
        case .hotkeys:    HotkeySettingsView()
        case .appearance: AppearanceSettingsView()
        case .privacy:    PrivacySettingsView()
        case .snippets:   SnippetsSettingsView()
        case .filters:    FiltersSettingsView()
        case .ai:         AISettingsView()
        case .advanced:   AdvancedSettingsView()
        }
    }
}

// MARK: - General

struct GeneralSettingsView: View {
    @State private var launchAtLogin = TroveSettings.launchAtLogin
    @State private var retentionDays = TroveSettings.historyRetentionDays
    @State private var maxHistory = TroveSettings.maxHistoryCount

    var body: some View {
        Form {
            Section {
                Toggle("Launch at login", isOn: $launchAtLogin)
                    .onChange(of: launchAtLogin) { _, v in
                        TroveSettings.launchAtLogin = v
                        try? v ? SMAppService.mainApp.register() : SMAppService.mainApp.unregister()
                    }
            }
            Section("History") {
                Picker("Keep clips for", selection: $retentionDays) {
                    Text("1 day").tag(1)
                    Text("7 days").tag(7)
                    Text("30 days").tag(30)
                    Text("90 days").tag(90)
                    Text("Forever").tag(0)
                }
                .onChange(of: retentionDays) { _, v in TroveSettings.historyRetentionDays = v }
                Picker("Maximum clips", selection: $maxHistory) {
                    Text("500").tag(500)
                    Text("1,000").tag(1000)
                    Text("5,000").tag(5000)
                    Text("Unlimited").tag(0)
                }
                .onChange(of: maxHistory) { _, v in TroveSettings.maxHistoryCount = v }
            }
        }
        .formStyle(.grouped)
        .padding()
    }
}

// MARK: - Clipboard

struct ClipboardSettingsView: View {
    @State private var captureImages = TroveSettings.captureImages
    @State private var captureFiles = TroveSettings.captureFiles
    @State private var captureRichText = TroveSettings.captureRichText
    @State private var maxSizeKB = TroveSettings.maxClipSizeKB

    var body: some View {
        Form {
            Section("What to capture") {
                Toggle("Text", isOn: .constant(true)).disabled(true)
                Toggle("Rich text", isOn: $captureRichText).onChange(of: captureRichText) { _, v in TroveSettings.captureRichText = v }
                Toggle("Images", isOn: $captureImages).onChange(of: captureImages) { _, v in TroveSettings.captureImages = v }
                Toggle("Files", isOn: $captureFiles).onChange(of: captureFiles) { _, v in TroveSettings.captureFiles = v }
            }
            Section("Limits") {
                Picker("Max clip size", selection: $maxSizeKB) {
                    Text("256 KB").tag(256)
                    Text("1 MB").tag(1024)
                    Text("5 MB").tag(5120)
                    Text("No limit").tag(0)
                }
                .onChange(of: maxSizeKB) { _, v in TroveSettings.maxClipSizeKB = v }
            }
        }
        .formStyle(.grouped)
        .padding()
    }
}

// MARK: - Hotkeys

struct HotkeySettingsView: View {
    @State private var keyCode = TroveSettings.openPanelKeyCode
    @State private var modifiers = TroveSettings.openPanelModifiers

    var body: some View {
        Form {
            Section("Global shortcuts") {
                ShortcutRecorderView(label: "Open Trove", keyCode: $keyCode, modifiers: $modifiers)
                    .onChange(of: keyCode) { _, v in
                        TroveSettings.openPanelKeyCode = v
                        reregister()
                    }
                    .onChange(of: modifiers) { _, v in
                        TroveSettings.openPanelModifiers = v
                        reregister()
                    }
            }
            Section("Panel shortcuts (when open)") {
                shortcutRow("Navigate", "↑ / ↓")
                shortcutRow("Paste selected", "↵")
                shortcutRow("Paste as plain text", "⌘⇧↵")
                shortcutRow("Detail preview", "Space / →")
                shortcutRow("Pin / unpin", "⌘P")
                shortcutRow("Delete", "⌘⌫")
                shortcutRow("Undo delete", "⌘Z")
                shortcutRow("Quick-paste 1–9", "⌘1 – ⌘9")
                shortcutRow("Focus search", "⌘K")
                shortcutRow("Dismiss", "Esc")
            }
        }
        .formStyle(.grouped)
        .padding()
    }

    private func shortcutRow(_ label: String, _ shortcut: String) -> some View {
        HStack {
            Text(label)
            Spacer()
            Text(shortcut).foregroundStyle(.secondary).font(.system(size: 12, design: .monospaced))
        }
    }

    private func reregister() {
        HotkeyService.shared.register(id: "openPanel", keyCode: keyCode, modifiers: modifiers) {
            Task { @MainActor in PanelController.shared.toggle() }
        }
    }
}

// MARK: - Appearance

struct AppearanceSettingsView: View {
    @State private var density = TroveSettings.panelDensity
    @State private var appearance = TroveSettings.appearanceMode
    @State private var position = TroveSettings.panelPosition
    @State private var showSource = TroveSettings.showSourceApp
    @State private var showTime = TroveSettings.showRelativeTime

    var body: some View {
        Form {
            Section("Theme") {
                Picker("Appearance", selection: $appearance) {
                    ForEach(AppearanceMode.allCases, id: \.self) { Text($0.displayName).tag($0) }
                }
                .onChange(of: appearance) { _, v in TroveSettings.appearanceMode = v }
                Picker("Density", selection: $density) {
                    ForEach(PanelDensity.allCases, id: \.self) { Text($0.rawValue.capitalized).tag($0) }
                }
                .onChange(of: density) { _, v in TroveSettings.panelDensity = v }
            }
            Section("Panel position") {
                Picker("Open at", selection: $position) {
                    ForEach(PanelPositionMode.allCases, id: \.self) { Text($0.displayName).tag($0) }
                }
                .onChange(of: position) { _, v in TroveSettings.panelPosition = v }
            }
            Section("Clip rows") {
                Toggle("Show source app", isOn: $showSource).onChange(of: showSource) { _, v in TroveSettings.showSourceApp = v }
                Toggle("Show relative time", isOn: $showTime).onChange(of: showTime) { _, v in TroveSettings.showRelativeTime = v }
            }
        }
        .formStyle(.grouped)
        .padding()
    }
}

// MARK: - Privacy

struct PrivacySettingsView: View {
    @State private var autoSkip = TroveSettings.autoSkipPasswords
    @State private var storeSensitive = TroveSettings.storeSensitiveClips
    @State private var clearOnLock = TroveSettings.clearHistoryOnLock
    @State private var blacklist = TroveSettings.blacklistedApps

    var body: some View {
        Form {
            Section("Sensitive content") {
                Toggle("Auto-skip detected passwords and tokens", isOn: $autoSkip)
                    .onChange(of: autoSkip) { _, v in TroveSettings.autoSkipPasswords = v }
                Toggle("Save sensitive clips anyway", isOn: $storeSensitive)
                    .disabled(autoSkip)
                    .onChange(of: storeSensitive) { _, v in TroveSettings.storeSensitiveClips = v }
                Toggle("Clear history when Mac locks", isOn: $clearOnLock)
                    .onChange(of: clearOnLock) { _, v in TroveSettings.clearHistoryOnLock = v }
            }
            Section {
                ForEach(blacklist, id: \.self) { bundleId in
                    HStack {
                        Text(bundleId.appDisplayName ?? bundleId)
                        Spacer()
                        Button { remove(bundleId) } label: {
                            Image(systemName: "minus.circle").foregroundStyle(.red)
                        }.buttonStyle(.plain)
                    }
                }
                Button("Add app…") { pickApp() }
            } header: {
                Text("Excluded apps")
            } footer: {
                Text("Trove won't capture from these apps.")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .padding()
    }

    private func remove(_ id: String) {
        blacklist.removeAll { $0 == id }
        TroveSettings.blacklistedApps = blacklist
    }

    private func pickApp() {
        let panel = NSOpenPanel()
        panel.directoryURL = URL(fileURLWithPath: "/Applications")
        panel.allowedContentTypes = [.applicationBundle]
        panel.prompt = "Exclude"
        if panel.runModal() == .OK, let url = panel.url {
            let id = Bundle(url: url)?.bundleIdentifier ?? url.deletingPathExtension().lastPathComponent
            if !blacklist.contains(id) { blacklist.append(id); TroveSettings.blacklistedApps = blacklist }
        }
    }
}

// MARK: - Snippets

struct SnippetsSettingsView: View {
    @State private var snippets: [Snippet] = []
    @State private var newTrigger = ""
    @State private var newContent = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            List {
                ForEach(snippets) { snippet in
                    HStack {
                        Text(snippet.trigger).font(.system(.body, design: .monospaced)).bold()
                        Text("→").foregroundStyle(.secondary)
                        Text(snippet.content).lineLimit(1).foregroundStyle(.secondary)
                        Spacer()
                    }
                }
                .onDelete { offsets in snippets.remove(atOffsets: offsets) }
            }
            Divider()
            HStack(spacing: 8) {
                TextField(";trigger", text: $newTrigger).frame(width: 100).textFieldStyle(.roundedBorder)
                TextField("Expansion text", text: $newContent).textFieldStyle(.roundedBorder)
                Button("Add") {
                    guard !newTrigger.isEmpty, !newContent.isEmpty else { return }
                    snippets.append(Snippet(id: UUID(), trigger: newTrigger, content: newContent, expandOn: .space, isEnabled: true))
                    newTrigger = ""; newContent = ""
                }.disabled(newTrigger.isEmpty || newContent.isEmpty)
            }
            .padding(12)
        }
        .frame(maxHeight: .infinity)
    }
}

// MARK: - Filters

struct FiltersSettingsView: View {
    @State private var selectedBuiltin: BuiltinFilter = .uppercase
    @State private var previewInput = "Hello World"

    var previewOutput: String { FilterEngine.applyBuiltin(selectedBuiltin, to: previewInput) }

    var body: some View {
        Form {
            Section("Built-in filters") {
                Picker("Filter", selection: $selectedBuiltin) {
                    ForEach(BuiltinFilter.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                }
                HStack(spacing: 12) {
                    VStack(alignment: .leading) {
                        Text("Input").font(.caption).foregroundStyle(.secondary)
                        TextField("Sample text", text: $previewInput).textFieldStyle(.roundedBorder)
                    }
                    Image(systemName: "arrow.right").foregroundStyle(.secondary)
                    VStack(alignment: .leading) {
                        Text("Output").font(.caption).foregroundStyle(.secondary)
                        Text(previewOutput)
                            .padding(6).background(Color.secondary.opacity(0.1))
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            }
        }
        .formStyle(.grouped)
        .padding()
    }
}

// MARK: - Sync

struct SyncSettingsView: View {
    @State private var syncEnabled = TroveSettings.iCloudSyncEnabled
    @State private var syncClips = TroveSettings.syncClips
    @State private var syncLimit = TroveSettings.syncHistoryLimit
    @StateObject private var syncSvc = SyncService.shared

    var body: some View {
        Form {
            Section {
                Toggle("Enable iCloud sync", isOn: $syncEnabled)
                    .onChange(of: syncEnabled) { _, v in
                        TroveSettings.iCloudSyncEnabled = v
                        if v { syncSvc.enable() }
                    }
                Text("Stored in your private iCloud database — only you can access it.")
                    .font(.caption).foregroundStyle(.secondary)
            }
            if syncEnabled {
                Section("What to sync") {
                    Toggle("Clips", isOn: $syncClips).onChange(of: syncClips) { _, v in TroveSettings.syncClips = v }
                    Picker("Sync last", selection: $syncLimit) {
                        Text("100 clips").tag(100)
                        Text("500 clips").tag(500)
                        Text("1,000 clips").tag(1000)
                    }
                    .onChange(of: syncLimit) { _, v in TroveSettings.syncHistoryLimit = v }
                }
                Section {
                    HStack {
                        switch syncSvc.syncStatus {
                        case .idle: Text("Idle").foregroundStyle(.secondary)
                        case .syncing: ProgressView().controlSize(.small); Text("Syncing…").foregroundStyle(.secondary)
                        case .error(let m): Image(systemName: "exclamationmark.triangle").foregroundStyle(.red); Text(m).foregroundStyle(.red)
                        }
                        Spacer()
                        Button("Sync now") { Task { await syncSvc.sync() } }
                    }
                }
            }
        }
        .formStyle(.grouped)
        .padding()
    }
}

// MARK: - AI

struct AISettingsView: View {
    @State private var aiEnabled = TroveSettings.aiEnabled
    @State private var provider = TroveSettings.aiProvider
    @State private var apiKey = ""
    @State private var keySaved = false

    var body: some View {
        Form {
            Section {
                Toggle("Enable AI actions", isOn: $aiEnabled)
                    .onChange(of: aiEnabled) { _, v in TroveSettings.aiEnabled = v }
                Text("Uses your own API key. Trove never charges for or proxies AI requests.")
                    .font(.caption).foregroundStyle(.secondary)
            }
            if aiEnabled {
                Section("Provider") {
                    Picker("AI provider", selection: $provider) {
                        Text("OpenAI").tag("openai")
                        Text("Anthropic").tag("anthropic")
                        Text("Ollama (local)").tag("ollama")
                    }
                    .onChange(of: provider) { _, v in TroveSettings.aiProvider = v }
                    if provider != "ollama" {
                        SecureField("API key", text: $apiKey).onSubmit { saveKey() }
                        Button("Save key") { saveKey() }.disabled(apiKey.isEmpty)
                        if keySaved { Label("Saved to Keychain", systemImage: "checkmark.seal.fill").foregroundStyle(.green).font(.caption) }
                    }
                }
            }
        }
        .formStyle(.grouped)
        .padding()
        .onAppear { apiKey = KeychainHelper.load(key: "trove.\(provider).apikey") ?? "" }
    }

    private func saveKey() {
        KeychainHelper.save(key: "trove.\(provider).apikey", value: apiKey)
        keySaved = true
    }
}

// MARK: - Advanced

struct AdvancedSettingsView: View {
    @State private var pollingInterval = TroveSettings.pollingIntervalMs
    @State private var showClearConfirm = false
    @State private var showResetConfirm = false

    var body: some View {
        Form {
            Section("Clipboard polling") {
                Picker("Check every", selection: $pollingInterval) {
                    Text("100 ms").tag(100)
                    Text("250 ms").tag(250)
                    Text("500 ms (default)").tag(500)
                    Text("1 second").tag(1000)
                }
                .onChange(of: pollingInterval) { _, v in TroveSettings.pollingIntervalMs = v }
            }
            Section("Data") {
                Button("Clear all history…", role: .destructive) { showClearConfirm = true }
                    .confirmationDialog("Clear all history?", isPresented: $showClearConfirm, titleVisibility: .visible) {
                        Button("Clear history", role: .destructive) { Task { await ClipStore.shared.clearAll() } }
                    } message: { Text("Deletes all clips that aren't pinned.") }

                Button("Reset all settings…", role: .destructive) { showResetConfirm = true }
                    .confirmationDialog("Reset all settings?", isPresented: $showResetConfirm, titleVisibility: .visible) {
                        Button("Reset", role: .destructive) { TroveSettings.resetAll() }
                    } message: { Text("All settings return to defaults. History is not affected.") }
            }
        }
        .formStyle(.grouped)
        .padding()
    }
}
