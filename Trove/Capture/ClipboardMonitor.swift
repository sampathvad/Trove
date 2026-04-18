import AppKit

actor ClipboardMonitor {
    private var lastChangeCount: Int = 0
    private var isRunning = false
    private var monitorTask: Task<Void, Never>?

    func start() async {
        guard !isRunning else { return }
        isRunning = true
        // Read initial changeCount on main thread
        lastChangeCount = await MainActor.run { NSPasteboard.general.changeCount }
        monitorTask = Task { await poll() }
    }

    func pause() {
        monitorTask?.cancel()
        monitorTask = nil
    }

    func resume() {
        guard isRunning, monitorTask == nil else { return }
        monitorTask = Task { await poll() }
    }

    private func poll() async {
        while !Task.isCancelled {
            // Always read NSPasteboard on the main thread
            let currentCount = await MainActor.run { NSPasteboard.general.changeCount }
            if currentCount != lastChangeCount {
                lastChangeCount = currentCount
                await captureCurrentClipboard()
            }
            let ms = TroveSettings.pollingIntervalMs
            try? await Task.sleep(for: .milliseconds(ms))
        }
    }

    private func captureCurrentClipboard() async {
        // All NSPasteboard access on main thread
        let result = await MainActor.run { () -> (types: [NSPasteboard.PasteboardType], sourceApp: String?) in
            let pb = NSPasteboard.general
            let types = pb.types ?? []
            let sourceApp = NSWorkspace.shared.frontmostApplication?.bundleIdentifier
            return (types, sourceApp)
        }

        // Respect transient/concealed markers
        if result.types.contains(.init("org.nspasteboard.TransientType")) { return }
        if result.types.contains(.init("org.nspasteboard.ConcealedType")) { return }

        // Skip blacklisted apps
        if let app = result.sourceApp, await BlacklistService.shared.isBlacklisted(app) { return }

        // Extract clip content on main thread
        let clip = await MainActor.run {
            ClipExtractor.extract(from: NSPasteboard.general, sourceApp: result.sourceApp)
        }

        // Skip empty clips
        guard clip.content.previewText?.isEmpty == false ||
              (clip.type == .image || clip.type == .file) else { return }

        await ClipStore.shared.insert(clip)
    }
}
