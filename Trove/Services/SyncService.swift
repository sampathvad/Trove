import CloudKit
import Foundation

@MainActor
final class SyncService: ObservableObject {
    static let shared = SyncService()
    private let db = CKContainer(identifier: "iCloud.app.trove.Trove").privateCloudDatabase

    @Published var syncStatus: SyncStatus = .idle
    enum SyncStatus { case idle, syncing, error(String) }

    private init() {}

    func enable() { Task { await sync() } }

    func sync() async {
        guard TroveSettings.iCloudSyncEnabled else { return }
        syncStatus = .syncing
        do {
            try await pushClips()
            try await pullClips()
            syncStatus = .idle
        } catch {
            syncStatus = .error(error.localizedDescription)
        }
    }

    private func pushClips() async throws {
        guard TroveSettings.syncClips else { return }
        let clips = Array(ClipStore.shared.clips.prefix(TroveSettings.syncHistoryLimit))
        let records = clips.compactMap(clipToRecord)
        let op = CKModifyRecordsOperation(recordsToSave: records, recordIDsToDelete: nil)
        op.savePolicy = .changedKeys
        try await withCheckedThrowingContinuation { (c: CheckedContinuation<Void, Error>) in
            op.modifyRecordsResultBlock = { result in
                switch result {
                case .success: c.resume()
                case .failure(let e): c.resume(throwing: e)
                }
            }
            db.add(op)
        }
    }

    private func pullClips() async throws {
        guard TroveSettings.syncClips else { return }
        let query = CKQuery(recordType: "Clip", predicate: NSPredicate(value: true))
        query.sortDescriptors = [NSSortDescriptor(key: "createdAt", ascending: false)]
        let (results, _) = try await db.records(matching: query, resultsLimit: TroveSettings.syncHistoryLimit)
        for (_, result) in results {
            if case .success(let record) = result, let clip = recordToClip(record) {
                await ClipStore.shared.insert(clip)
            }
        }
    }

    private func clipToRecord(_ clip: Clip) -> CKRecord? {
        let record = CKRecord(recordType: "Clip", recordID: .init(recordName: clip.id.uuidString))
        record["contentType"] = clip.type.rawValue as CKRecordValue
        record["sourceApp"] = (clip.sourceApp ?? "") as CKRecordValue
        record["isPinned"] = clip.isPinned as CKRecordValue
        record["createdAt"] = clip.createdAt as CKRecordValue
        record["isSensitive"] = clip.isSensitive as CKRecordValue
        if let text = clip.content.previewText { record["text"] = text as CKRecordValue }
        return record
    }

    private func recordToClip(_ record: CKRecord) -> Clip? {
        let id = UUID(uuidString: record.recordID.recordName) ?? UUID()
        let type = ClipType(rawValue: record["contentType"] as? String ?? "") ?? .plainText
        return Clip(
            id: id, content: .text(record["text"] as? String ?? ""),
            type: type,
            createdAt: record["createdAt"] as? Date ?? Date(),
            sourceApp: record["sourceApp"] as? String,
            isPinned: record["isPinned"] as? Bool ?? false,
            isSensitive: record["isSensitive"] as? Bool ?? false
        )
    }
}
