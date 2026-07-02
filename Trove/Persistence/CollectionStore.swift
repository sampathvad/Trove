import Foundation

@MainActor
final class CollectionStore: ObservableObject {
    static let shared = CollectionStore()
    @Published private(set) var collections: [Collection] = []

    private init() {}

    func load() async {
        guard let db = ClipStore.shared.database else { return }
        do {
            let rows = try db.query("SELECT * FROM collections ORDER BY order_index ASC")
            collections = rows.compactMap(Collection.init)
        } catch { Log.store.error("Collection load failed: \(error.localizedDescription, privacy: .public)") }
    }

    func create(name: String) async {
        guard let db = ClipStore.shared.database else { return }
        let c = Collection(id: UUID(), name: name, order: collections.count, createdAt: Date())
        do {
            try db.run(
                "INSERT INTO collections (id, name, order_index, created_at) VALUES (?,?,?,?)",
                [.text(c.id.uuidString), .text(c.name), .int(c.order), .real(c.createdAt.timeIntervalSince1970)]
            )
            collections.append(c)
        } catch { Log.store.error("Create collection failed: \(error.localizedDescription, privacy: .public)") }
    }

    func rename(_ collection: Collection, to name: String) async {
        guard let db = ClipStore.shared.database else { return }
        do {
            try db.run("UPDATE collections SET name=? WHERE id=?", [.text(name), .text(collection.id.uuidString)])
            if let idx = collections.firstIndex(where: { $0.id == collection.id }) {
                collections[idx].name = name
            }
        } catch { Log.store.error("Rename collection failed: \(error.localizedDescription, privacy: .public)") }
    }

    func delete(_ collection: Collection) async {
        guard let db = ClipStore.shared.database else { return }
        do {
            try db.run("DELETE FROM collections WHERE id=?", [.text(collection.id.uuidString)])
            try db.run("UPDATE clips SET collection_id=NULL WHERE collection_id=?", [.text(collection.id.uuidString)])
            collections.removeAll { $0.id == collection.id }
        } catch { Log.store.error("Delete collection failed: \(error.localizedDescription, privacy: .public)") }
    }

    func assignClip(_ clip: Clip, to collection: Collection?) async {
        guard let db = ClipStore.shared.database else { return }
        let val: SQLValue = collection.map { .text($0.id.uuidString) } ?? .null
        try? db.run("UPDATE clips SET collection_id=? WHERE id=?", [val, .text(clip.id.uuidString)])
    }
}

extension Collection {
    init?(from row: [String: SQLValue]) {
        guard let idStr = row["id"]?.stringValue, let id = UUID(uuidString: idStr) else { return nil }
        self.id = id
        self.name = row["name"]?.stringValue ?? ""
        self.order = row["order_index"]?.intValue ?? 0
        self.createdAt = Date(timeIntervalSince1970: row["created_at"]?.realValue ?? 0)
    }
}
