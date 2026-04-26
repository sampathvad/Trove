import Foundation

// Append-only audit log — records metadata only, never clip content
enum AuditLog {
    private static let maxSizeBytes = 1_048_576  // 1 MB

    static func captured(type: String, sourceApp: String?, charCount: Int?) {
        let chars = charCount.map { "\($0) chars" } ?? "unknown size"
        write("CAPTURED \(type) from \(sourceApp ?? "unknown") (\(chars))")
    }

    static func blocked(reason: String, sourceApp: String?) {
        write("BLOCKED \(reason) from \(sourceApp ?? "unknown")")
    }

    static func pasted(clipId: UUID) {
        write("PASTED clip \(clipId.uuidString.prefix(8))")
    }

    static func deleted(clipId: UUID) {
        write("DELETED clip \(clipId.uuidString.prefix(8))")
    }

    static func aiAction(_ action: String, clipId: UUID, provider: String) {
        write("AI \(action) on clip \(clipId.uuidString.prefix(8)) via \(provider)")
    }

    static func launchAtLoginFailed(error: Error) {
        write("LAUNCH_AT_LOGIN_FAILED \(error.localizedDescription)")
    }

    // MARK: - Private

    private static func write(_ message: String) {
        guard let url = logURL else { return }
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        let line = "[\(formatter.string(from: Date()))] \(message)\n"
        guard let data = line.data(using: .utf8) else { return }

        do {
            try FileManager.default.createDirectory(at: url.deletingLastPathComponent(),
                                                    withIntermediateDirectories: true)
            if FileManager.default.fileExists(atPath: url.path) {
                let attrs = try FileManager.default.attributesOfItem(atPath: url.path)
                let size = attrs[.size] as? Int ?? 0
                if size > maxSizeBytes { rotateLog(at: url) }
                let handle = try FileHandle(forWritingTo: url)
                handle.seekToEndOfFile()
                handle.write(data)
                handle.closeFile()
            } else {
                try data.write(to: url, options: .atomic)
            }
        } catch {
            // Audit log failure is non-fatal
        }
    }

    private static func rotateLog(at url: URL) {
        let rotated = url.deletingPathExtension().appendingPathExtension("1.log")
        try? FileManager.default.removeItem(at: rotated)
        try? FileManager.default.moveItem(at: url, to: rotated)
    }

    private static var logURL: URL? {
        FileManager.default
            .urls(for: .libraryDirectory, in: .userDomainMask)
            .first?
            .appendingPathComponent("Logs/Trove/audit.log")
    }
}
