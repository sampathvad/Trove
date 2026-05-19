import Foundation
import AppKit

@MainActor
final class ClipStore: ObservableObject {
    static let shared = ClipStore()

    @Published private(set) var clips: [Clip] = []

    var database: SQLiteDB? { db }

    private var db: SQLiteDB?
    private var undoStack: [(Clip, Int)] = []
    private var pendingDeleteTimers: [UUID: Task<Void, Never>] = [:]

    private init() {}

    // MARK: - Setup

    func setup() async {
        do {
            let appSupport = FileManager.default
                .urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
                .appendingPathComponent("Trove")
            try FileManager.default.createDirectory(at: appSupport, withIntermediateDirectories: true)
            let dbPath = appSupport.appendingPathComponent("trove.db").path
            db = try SQLiteDB(path: dbPath)
            // Restrict DB + sidecar files to owner-only (-rw-------).
            // SQLite WAL mode also writes -wal and -shm files alongside the main DB.
            for suffix in ["", "-wal", "-shm"] {
                let path = dbPath + suffix
                if FileManager.default.fileExists(atPath: path) {
                    try? FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: path)
                }
            }
            try migrate()
            await loadRecent()
            pruneExpired()
            vacuumIfStale()
        } catch {
            print("ClipStore setup failed: \(error)")
        }
    }

    private func vacuumIfStale() {
        let key = "trove.lastVacuumAt"
        let now = Date().timeIntervalSince1970
        let last = UserDefaults.standard.double(forKey: key)
        // Vacuum at most once every 7 days; reclaims pages so DELETE + secure_delete actually frees space.
        if now - last < 7 * 86400 { return }
        try? db?.exec("VACUUM")
        UserDefaults.standard.set(now, forKey: key)
    }

    // MARK: - Insert

    func insert(_ clip: Clip) async {
        guard let db else { return }

        // Block sensitive clips unless user opted in
        if clip.isSensitive && !TroveSettings.storeSensitiveClips {
            AuditLog.blocked(reason: "sensitive \(clip.type.rawValue)", sourceApp: clip.sourceApp)
            return
        }

        let hash = clip.content.contentHash

        // If this content already exists, bump it instead of inserting a duplicate row.
        if let existingId = (try? db.query(
            "SELECT id FROM clips WHERE content_hash=? LIMIT 1",
            [.text(hash)]
        ))?.first?["id"]?.stringValue.flatMap(UUID.init(uuidString:)) {
            await bumpExisting(id: existingId, sourceApp: clip.sourceApp)
            return
        }

        let searchableText = clip.content.previewText ?? ""
        // Sensitive clips auto-expire in 5 minutes
        let expiryAt: SQLValue = clip.isSensitive
            ? .real(Date().addingTimeInterval(300).timeIntervalSince1970)
            : .null

        do {
            try db.run("""
                INSERT OR IGNORE INTO clips
                    (id, content, type, metadata, created_at, source_app, is_pinned, collection_id, is_sensitive, expiry_at, content_hash)
                VALUES (?,?,?,?,?,?,?,?,?,?,?)
            """, [
                .text(clip.id.uuidString),
                .blob(encode(clip.content)),
                .text(clip.type.rawValue),
                .blob(encode(clip.metadata)),
                .real(clip.createdAt.timeIntervalSince1970),
                clip.sourceApp.map { .text($0) } ?? .null,
                .int(clip.isPinned ? 1 : 0),
                clip.collectionId.map { .text($0.uuidString) } ?? .null,
                .int(clip.isSensitive ? 1 : 0),
                expiryAt,
                .text(hash)
            ])
            try db.run("""
                INSERT OR IGNORE INTO clips_fts (id, searchable_text, source_app)
                VALUES (?,?,?)
            """, [.text(clip.id.uuidString), .text(searchableText), .text(clip.sourceApp ?? "")])
            enforceHistoryLimit()
            await loadRecent()
            AuditLog.captured(type: clip.type.rawValue, sourceApp: clip.sourceApp,
                              charCount: clip.metadata.characterCount)
        } catch {
            print("Insert failed: \(error)")
        }
    }

    // MARK: - Soft delete / undo

    func softDelete(_ clip: Clip) -> Int? {
        guard let idx = clips.firstIndex(where: { $0.id == clip.id }) else { return nil }
        clips.remove(at: idx)
        undoStack.append((clip, idx))
        let task = Task {
            try? await Task.sleep(for: .seconds(5))
            guard !Task.isCancelled else { return }
            await self.permanentlyDelete(clip)
            self.undoStack.removeAll { $0.0.id == clip.id }
            self.pendingDeleteTimers.removeValue(forKey: clip.id)
        }
        pendingDeleteTimers[clip.id] = task
        return idx
    }

    func undoDelete() {
        guard let (clip, idx) = undoStack.last else { return }
        undoStack.removeLast()
        pendingDeleteTimers[clip.id]?.cancel()
        pendingDeleteTimers.removeValue(forKey: clip.id)
        clips.insert(clip, at: min(idx, clips.count))
        Task { await self.persistInsert(clip) }
    }

    private func permanentlyDelete(_ clip: Clip) async {
        try? db?.run("DELETE FROM clips WHERE id=?", [.text(clip.id.uuidString)])
        try? db?.run("DELETE FROM clips_fts WHERE id=?", [.text(clip.id.uuidString)])
    }

    func delete(_ clip: Clip) async {
        try? db?.run("DELETE FROM clips WHERE id=?", [.text(clip.id.uuidString)])
        try? db?.run("DELETE FROM clips_fts WHERE id=?", [.text(clip.id.uuidString)])
        clips.removeAll { $0.id == clip.id }
    }

    // MARK: - Pin

    func togglePin(_ clip: Clip) async {
        let newValue = !clip.isPinned
        try? db?.run("UPDATE clips SET is_pinned=? WHERE id=?",
                     [.int(newValue ? 1 : 0), .text(clip.id.uuidString)])
        if let idx = clips.firstIndex(where: { $0.id == clip.id }) {
            clips[idx].isPinned = newValue
        }
    }

    // MARK: - Update content

    func updateContent(_ clip: Clip, newText: String) async {
        let updated = Clip(
            id: clip.id, content: .text(newText),
            type: TypeDetector.detect(newText),
            metadata: ClipMetadata(characterCount: newText.count),
            createdAt: clip.createdAt, sourceApp: clip.sourceApp,
            isPinned: clip.isPinned, collectionId: clip.collectionId,
            isSensitive: clip.isSensitive
        )
        try? db?.run("UPDATE clips SET content=?,type=?,metadata=? WHERE id=?", [
            .blob(encode(updated.content)),
            .text(updated.type.rawValue),
            .blob(encode(updated.metadata)),
            .text(clip.id.uuidString)
        ])
        try? db?.run("UPDATE clips_fts SET searchable_text=? WHERE id=?",
                     [.text(newText), .text(clip.id.uuidString)])
        if let idx = clips.firstIndex(where: { $0.id == clip.id }) { clips[idx] = updated }
    }

    // MARK: - Search

    func search(_ query: String) async -> [Clip] {
        guard let db, !query.isEmpty else { return clips }
        let limit = max(TroveSettings.maxHistoryCount, 500)
        // FTS5 match
        if query.count >= 2 {
            let rows = (try? db.query("""
                SELECT c.* FROM clips c
                JOIN clips_fts f ON c.id=f.id
                WHERE clips_fts MATCH ?
                ORDER BY c.is_pinned DESC, c.created_at DESC LIMIT ?
            """, [.text("\(query)*"), .int(limit)])) ?? []
            if !rows.isEmpty { return rows.compactMap(Self.clip) }
        }
        // LIKE fallback
        let rows = (try? db.query("""
            SELECT * FROM clips
            WHERE id IN (SELECT id FROM clips_fts WHERE searchable_text LIKE ?)
            ORDER BY is_pinned DESC, created_at DESC LIMIT ?
        """, [.text("%\(query)%"), .int(limit)])) ?? []
        return rows.compactMap(Self.clip)
    }

    // MARK: - Clear all

    func clearAll() async {
        try? db?.run("DELETE FROM clips WHERE is_pinned=0")
        try? db?.run("DELETE FROM clips_fts")
        clips.removeAll { !$0.isPinned }
    }

    // MARK: - Private helpers

    private func loadRecent() async {
        let limit = TroveSettings.maxHistoryCount > 0 ? TroveSettings.maxHistoryCount : 5000
        let rows = (try? db?.query(
            "SELECT * FROM clips ORDER BY is_pinned DESC, created_at DESC LIMIT ?",
            [.int(limit)])) ?? []
        // Decode JSON blobs off the main actor — at 5k clips this would
        // otherwise pin the main thread for a second or two during launch.
        let decoded = await Task.detached(priority: .userInitiated) {
            rows.compactMap(Self.clip)
        }.value
        clips = decoded
    }

    private func enforceHistoryLimit() {
        let limit = TroveSettings.maxHistoryCount
        guard limit > 0 else { return }
        try? db?.run("""
            DELETE FROM clips WHERE is_pinned=0 AND id NOT IN (
                SELECT id FROM clips WHERE is_pinned=0 ORDER BY created_at DESC LIMIT ?
            )
        """, [.int(limit)])
    }

    private func pruneExpired() {
        let now = Date().timeIntervalSince1970
        // Delete clips past their expiry_at (sensitive clips auto-expire in 5 min)
        try? db?.run("DELETE FROM clips WHERE expiry_at IS NOT NULL AND expiry_at < ?", [.real(now)])
        // Delete old clips beyond retention period
        let days = TroveSettings.historyRetentionDays
        guard days > 0 else { return }
        let cutoff = Date().addingTimeInterval(-Double(days) * 86400)
        try? db?.run("DELETE FROM clips WHERE is_pinned=0 AND created_at<?",
                     [.real(cutoff.timeIntervalSince1970)])
    }

    private func persistInsert(_ clip: Clip) async {
        let text = clip.content.previewText ?? ""
        try? db?.run("""
            INSERT OR IGNORE INTO clips
                (id,content,type,metadata,created_at,source_app,is_pinned,collection_id,is_sensitive,content_hash)
            VALUES (?,?,?,?,?,?,?,?,?,?)
        """, [
            .text(clip.id.uuidString), .blob(encode(clip.content)),
            .text(clip.type.rawValue), .blob(encode(clip.metadata)),
            .real(clip.createdAt.timeIntervalSince1970),
            clip.sourceApp.map { .text($0) } ?? .null,
            .int(clip.isPinned ? 1 : 0),
            clip.collectionId.map { .text($0.uuidString) } ?? .null,
            .int(clip.isSensitive ? 1 : 0),
            .text(clip.content.contentHash)
        ])
        try? db?.run("INSERT OR IGNORE INTO clips_fts(id,searchable_text,source_app) VALUES(?,?,?)",
                     [.text(clip.id.uuidString), .text(text), .text(clip.sourceApp ?? "")])
    }

    private func bumpExisting(id: UUID, sourceApp: String?) async {
        guard let db else { return }
        let now = Date()

        // Read existing row from DB (covers clips not in the recent in-memory window).
        let existing = (try? db.query(
            "SELECT type, metadata, is_sensitive FROM clips WHERE id=? LIMIT 1",
            [.text(id.uuidString)]
        ))?.first

        var meta: ClipMetadata = existing?["metadata"]?.blobValue
            .flatMap { try? JSONDecoder().decode(ClipMetadata.self, from: $0) }
            ?? ClipMetadata()
        meta.copyCount = (meta.copyCount ?? 1) + 1

        let isSensitive = existing?["is_sensitive"]?.intValue == 1

        if isSensitive {
            // Refresh expiry so a repeatedly-copied sensitive clip doesn't vanish mid-use.
            try? db.run(
                "UPDATE clips SET created_at=?, metadata=?, expiry_at=? WHERE id=?",
                [
                    .real(now.timeIntervalSince1970),
                    .blob(encode(meta)),
                    .real(now.addingTimeInterval(300).timeIntervalSince1970),
                    .text(id.uuidString)
                ]
            )
        } else {
            try? db.run(
                "UPDATE clips SET created_at=?, metadata=? WHERE id=?",
                [
                    .real(now.timeIntervalSince1970),
                    .blob(encode(meta)),
                    .text(id.uuidString)
                ]
            )
        }

        await loadRecent()
        AuditLog.captured(type: existing?["type"]?.stringValue ?? "duplicate",
                          sourceApp: sourceApp,
                          charCount: meta.characterCount)
    }

    private func encode<T: Encodable>(_ value: T) -> Data {
        (try? JSONEncoder().encode(value)) ?? Data()
    }

    nonisolated private static func clip(from row: [String: SQLValue]) -> Clip? {
        guard let idStr = row["id"]?.stringValue, let id = UUID(uuidString: idStr),
              let contentData = row["content"]?.blobValue,
              let content = try? JSONDecoder().decode(ClipContent.self, from: contentData)
        else { return nil }
        let metadata = row["metadata"]?.blobValue
            .flatMap { try? JSONDecoder().decode(ClipMetadata.self, from: $0) } ?? ClipMetadata()
        return Clip(
            id: id, content: content,
            type: row["type"]?.stringValue.flatMap(ClipType.init) ?? .plainText,
            metadata: metadata,
            createdAt: Date(timeIntervalSince1970: row["created_at"]?.realValue ?? 0),
            sourceApp: row["source_app"]?.stringValue,
            isPinned: row["is_pinned"]?.intValue == 1,
            collectionId: row["collection_id"]?.stringValue.flatMap(UUID.init),
            isSensitive: row["is_sensitive"]?.intValue == 1
        )
    }

    // MARK: - Migration

    private func migrate() throws {
        // Create tables (without expiry_at for backwards compat)
        try db?.exec("""
            CREATE TABLE IF NOT EXISTS clips (
                id TEXT PRIMARY KEY,
                content BLOB NOT NULL,
                type TEXT NOT NULL,
                metadata BLOB,
                created_at REAL NOT NULL,
                source_app TEXT,
                is_pinned INTEGER NOT NULL DEFAULT 0,
                collection_id TEXT,
                is_sensitive INTEGER NOT NULL DEFAULT 0
            );
            CREATE INDEX IF NOT EXISTS idx_clips_created ON clips(created_at DESC);
            CREATE INDEX IF NOT EXISTS idx_clips_type ON clips(type);
            CREATE INDEX IF NOT EXISTS idx_clips_pinned ON clips(is_pinned) WHERE is_pinned=1;

            CREATE VIRTUAL TABLE IF NOT EXISTS clips_fts USING fts5(
                id UNINDEXED, searchable_text, source_app,
                tokenize='porter unicode61 remove_diacritics 2'
            );

            CREATE TABLE IF NOT EXISTS collections (
                id TEXT PRIMARY KEY, name TEXT NOT NULL,
                order_index INTEGER NOT NULL, created_at REAL NOT NULL
            );
            CREATE TABLE IF NOT EXISTS snippets (
                id TEXT PRIMARY KEY, trigger TEXT NOT NULL UNIQUE,
                content TEXT NOT NULL, expand_on TEXT NOT NULL,
                is_enabled INTEGER NOT NULL DEFAULT 1
            );
            CREATE TABLE IF NOT EXISTS filters (
                id TEXT PRIMARY KEY, name TEXT NOT NULL,
                kind TEXT NOT NULL, definition TEXT NOT NULL,
                is_enabled INTEGER NOT NULL DEFAULT 1
            );
            CREATE TABLE IF NOT EXISTS workspaces (
                id TEXT PRIMARY KEY, name TEXT NOT NULL,
                icon TEXT NOT NULL DEFAULT 'tray',
                order_index INTEGER NOT NULL, created_at REAL NOT NULL
            );
        """)

        // Incremental migrations — ALTER TABLE is safe to attempt; ignore if column exists
        addColumnIfMissing(table: "clips", column: "expiry_at", type: "REAL")
        try? db?.exec("CREATE INDEX IF NOT EXISTS idx_clips_expiry ON clips(expiry_at) WHERE expiry_at IS NOT NULL;")

        addColumnIfMissing(table: "clips", column: "content_hash", type: "TEXT")
        try? db?.exec("CREATE INDEX IF NOT EXISTS idx_clips_content_hash ON clips(content_hash);")
        backfillContentHashesIfNeeded()
        rehashAllIfNeeded()
    }

    private static let currentHashSchemaVersion = 1
    private static let hashSchemaVersionKey = "troveClipHashSchemaVersion"

    /// Re-compute `content_hash` for every existing row when the hash scheme
    /// changes (e.g., V1 normalizes RTF→plain text). Collapses rows that
    /// were fragmented by the old scheme into a single survivor, summing
    /// their `copyCount`. Keyed on `troveClipHashSchemaVersion` so it runs
    /// exactly once per scheme bump.
    private func rehashAllIfNeeded() {
        guard let db else { return }
        let stored = UserDefaults.standard.integer(forKey: Self.hashSchemaVersionKey)
        guard stored < Self.currentHashSchemaVersion else { return }

        let rows = (try? db.query(
            "SELECT id, content, metadata, created_at, is_pinned FROM clips"
        )) ?? []
        guard !rows.isEmpty else {
            UserDefaults.standard.set(Self.currentHashSchemaVersion, forKey: Self.hashSchemaVersionKey)
            return
        }

        struct RehashRow {
            let id: String
            let metadata: ClipMetadata
            let createdAt: Double
            let isPinned: Bool
        }

        var buckets: [String: [RehashRow]] = [:]
        for row in rows {
            guard let id = row["id"]?.stringValue,
                  let blob = row["content"]?.blobValue,
                  let content = try? JSONDecoder().decode(ClipContent.self, from: blob)
            else { continue }
            let metadata = row["metadata"]?.blobValue
                .flatMap { try? JSONDecoder().decode(ClipMetadata.self, from: $0) } ?? ClipMetadata()
            let createdAt = row["created_at"]?.realValue ?? 0
            let isPinned = row["is_pinned"]?.intValue == 1
            buckets[content.contentHash, default: []].append(
                RehashRow(id: id, metadata: metadata, createdAt: createdAt, isPinned: isPinned)
            )
        }

        do {
            try db.transaction {
                for (hash, group) in buckets {
                    if group.count == 1 {
                        try db.run(
                            "UPDATE clips SET content_hash=? WHERE id=?",
                            [.text(hash), .text(group[0].id)]
                        )
                    } else {
                        // Pinned survives over unpinned; then most-recent wins.
                        let sorted = group.sorted {
                            if $0.isPinned != $1.isPinned { return $0.isPinned }
                            return $0.createdAt > $1.createdAt
                        }
                        let survivor = sorted[0]
                        let totalCount = sorted.reduce(0) { $0 + ($1.metadata.copyCount ?? 1) }
                        var newMeta = survivor.metadata
                        newMeta.copyCount = totalCount
                        let metaBlob = (try? JSONEncoder().encode(newMeta)) ?? Data()
                        try db.run(
                            "UPDATE clips SET content_hash=?, metadata=? WHERE id=?",
                            [.text(hash), .blob(metaBlob), .text(survivor.id)]
                        )
                        for loser in sorted.dropFirst() {
                            try db.run("DELETE FROM clips WHERE id=?", [.text(loser.id)])
                            try db.run("DELETE FROM clips_fts WHERE id=?", [.text(loser.id)])
                        }
                    }
                }
                return ()
            }
            UserDefaults.standard.set(Self.currentHashSchemaVersion, forKey: Self.hashSchemaVersionKey)
        } catch {
            print("rehashAllIfNeeded failed: \(error)")
        }
    }

    private func backfillContentHashesIfNeeded() {
        guard let db else { return }
        let rows = (try? db.query("SELECT id, content FROM clips WHERE content_hash IS NULL")) ?? []
        guard !rows.isEmpty else { return }
        for row in rows {
            guard let id = row["id"]?.stringValue,
                  let blob = row["content"]?.blobValue,
                  let content = try? JSONDecoder().decode(ClipContent.self, from: blob)
            else { continue }
            try? db.run("UPDATE clips SET content_hash=? WHERE id=?",
                        [.text(content.contentHash), .text(id)])
        }
    }

    private func addColumnIfMissing(table: String, column: String, type: String) {
        guard let db else { return }
        let existing = (try? db.query("PRAGMA table_info(\(table))"))?.compactMap { $0["name"]?.stringValue } ?? []
        guard !existing.contains(column) else { return }
        try? db.exec("ALTER TABLE \(table) ADD COLUMN \(column) \(type)")
    }
}
