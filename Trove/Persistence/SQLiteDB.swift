import Foundation
import SQLite3

// Minimal SQLite wrapper — replaces GRDB dependency

final class SQLiteDB {
    private var db: OpaquePointer?

    init(path: String) throws {
        if sqlite3_open(path, &db) != SQLITE_OK {
            throw DBError.openFailed(String(cString: sqlite3_errmsg(db)))
        }
        try exec("PRAGMA journal_mode=WAL")
        try exec("PRAGMA foreign_keys=ON")
    }

    deinit { sqlite3_close(db) }

    // MARK: - Execute

    func exec(_ sql: String) throws {
        var err: UnsafeMutablePointer<CChar>?
        if sqlite3_exec(db, sql, nil, nil, &err) != SQLITE_OK {
            let msg = err.map { String(cString: $0) } ?? "unknown"
            sqlite3_free(err)
            throw DBError.execFailed(msg)
        }
    }

    // MARK: - Query

    func query(_ sql: String, _ args: [SQLValue] = []) throws -> [[String: SQLValue]] {
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
            throw DBError.prepareFailed(String(cString: sqlite3_errmsg(db)))
        }
        defer { sqlite3_finalize(stmt) }
        bind(args, to: stmt)

        var rows: [[String: SQLValue]] = []
        let colCount = sqlite3_column_count(stmt)
        while sqlite3_step(stmt) == SQLITE_ROW {
            var row: [String: SQLValue] = [:]
            for i in 0..<colCount {
                let name = String(cString: sqlite3_column_name(stmt, i))
                row[name] = value(stmt, col: i)
            }
            rows.append(row)
        }
        return rows
    }

    func run(_ sql: String, _ args: [SQLValue] = []) throws {
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
            throw DBError.prepareFailed(String(cString: sqlite3_errmsg(db)))
        }
        defer { sqlite3_finalize(stmt) }
        bind(args, to: stmt)
        let rc = sqlite3_step(stmt)
        if rc != SQLITE_DONE && rc != SQLITE_ROW {
            throw DBError.stepFailed(String(cString: sqlite3_errmsg(db)))
        }
    }

    // MARK: - Helpers

    private func bind(_ args: [SQLValue], to stmt: OpaquePointer?) {
        for (i, arg) in args.enumerated() {
            let idx = Int32(i + 1)
            switch arg {
            case .null:
                sqlite3_bind_null(stmt, idx)
            case .int(let v):
                sqlite3_bind_int64(stmt, idx, Int64(v))
            case .real(let v):
                sqlite3_bind_double(stmt, idx, v)
            case .text(let v):
                sqlite3_bind_text(stmt, idx, (v as NSString).utf8String, -1, nil)
            case .blob(let v):
                // SQLITE_TRANSIENT (-1) tells SQLite to copy the data immediately
                let transient = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
                _ = v.withUnsafeBytes { ptr in
                    sqlite3_bind_blob(stmt, idx, ptr.baseAddress, Int32(v.count), transient)
                }
            }
        }
    }

    private func value(_ stmt: OpaquePointer?, col: Int32) -> SQLValue {
        switch sqlite3_column_type(stmt, col) {
        case SQLITE_INTEGER: return .int(Int(sqlite3_column_int64(stmt, col)))
        case SQLITE_FLOAT:   return .real(sqlite3_column_double(stmt, col))
        case SQLITE_TEXT:    return .text(String(cString: sqlite3_column_text(stmt, col)))
        case SQLITE_BLOB:
            let bytes = sqlite3_column_blob(stmt, col)
            let count = Int(sqlite3_column_bytes(stmt, col))
            if let bytes, count > 0 {
                return .blob(Data(bytes: bytes, count: count))
            }
            return .blob(Data())
        default: return .null
        }
    }

    // MARK: - Transaction

    func transaction<T>(_ block: () throws -> T) throws -> T {
        try exec("BEGIN")
        do {
            let result = try block()
            try exec("COMMIT")
            return result
        } catch {
            try? exec("ROLLBACK")
            throw error
        }
    }
}

// MARK: - Types

enum SQLValue {
    case null
    case int(Int)
    case real(Double)
    case text(String)
    case blob(Data)

    var stringValue: String? { if case .text(let s) = self { return s }; return nil }
    var intValue: Int? { if case .int(let i) = self { return i }; return nil }
    var realValue: Double? { if case .real(let r) = self { return r }; return nil }
    var blobValue: Data? { if case .blob(let d) = self { return d }; return nil }
}

extension SQLValue: Equatable {
    public static func == (lhs: SQLValue, rhs: SQLValue) -> Bool {
        switch (lhs, rhs) {
        case (.null, .null): return true
        case (.int(let a), .int(let b)): return a == b
        case (.real(let a), .real(let b)): return a == b
        case (.text(let a), .text(let b)): return a == b
        case (.blob(let a), .blob(let b)): return a == b
        default: return false
        }
    }
}

enum DBError: LocalizedError {
    case openFailed(String)
    case execFailed(String)
    case prepareFailed(String)
    case stepFailed(String)

    var errorDescription: String? {
        switch self {
        case .openFailed(let m): return "DB open: \(m)"
        case .execFailed(let m): return "DB exec: \(m)"
        case .prepareFailed(let m): return "DB prepare: \(m)"
        case .stepFailed(let m): return "DB step: \(m)"
        }
    }
}
