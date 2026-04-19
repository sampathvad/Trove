import XCTest
@testable import Trove

final class SQLiteDBTests: XCTestCase {
    var db: SQLiteDB!

    override func setUpWithError() throws {
        try super.setUpWithError()
        db = try SQLiteDB(path: ":memory:")
        try db.exec("CREATE TABLE test (id INTEGER PRIMARY KEY, name TEXT, value REAL, data BLOB)")
    }

    func testInsertAndQuery() throws {
        try db.run("INSERT INTO test (name, value) VALUES (?, ?)", [.text("hello"), .real(3.14)])
        let rows = try db.query("SELECT * FROM test")
        XCTAssertEqual(rows.count, 1)
        XCTAssertEqual(rows[0]["name"]?.stringValue, "hello")
        let val = try XCTUnwrap(rows[0]["value"]?.realValue)
        XCTAssertEqual(val, 3.14, accuracy: 0.001)
    }

    func testNullValue() throws {
        try db.run("INSERT INTO test (name) VALUES (?)", [.null])
        let rows = try db.query("SELECT name FROM test")
        XCTAssertEqual(rows[0]["name"], .null)
    }

    func testBlobRoundTrip() throws {
        let original = Data([0x01, 0x02, 0x03, 0xFF])
        try db.run("INSERT INTO test (data) VALUES (?)", [.blob(original)])
        let rows = try db.query("SELECT data FROM test")
        let retrieved = try XCTUnwrap(rows[0]["data"]?.blobValue)
        XCTAssertEqual(retrieved, original)
    }

    func testIntegerValue() throws {
        try db.run("INSERT INTO test (id, name) VALUES (?, ?)", [.int(42), .text("test")])
        let rows = try db.query("SELECT id FROM test")
        XCTAssertEqual(rows[0]["id"]?.intValue, 42)
    }

    func testMultipleRows() throws {
        for i in 1...5 {
            try db.run("INSERT INTO test (name, value) VALUES (?, ?)", [.text("row\(i)"), .real(Double(i))])
        }
        let rows = try db.query("SELECT * FROM test ORDER BY id")
        XCTAssertEqual(rows.count, 5)
        XCTAssertEqual(rows[4]["name"]?.stringValue, "row5")
    }

    func testTransaction() throws {
        try db.transaction {
            try db.run("INSERT INTO test (name) VALUES (?)", [.text("tx1")])
            try db.run("INSERT INTO test (name) VALUES (?)", [.text("tx2")])
        }
        let rows = try db.query("SELECT * FROM test")
        XCTAssertEqual(rows.count, 2)
    }

    func testTransactionRollbackOnError() {
        try? db.transaction {
            try db.run("INSERT INTO test (name) VALUES (?)", [.text("before")])
            throw NSError(domain: "test", code: 1)
        }
        let rows = (try? db.query("SELECT * FROM test")) ?? []
        XCTAssertEqual(rows.count, 0)  // rolled back
    }

    func testParameterizedQueryPreventsInjection() throws {
        let malicious = "'; DROP TABLE test; --"
        try db.run("INSERT INTO test (name) VALUES (?)", [.text(malicious)])
        let rows = try db.query("SELECT * FROM test")
        XCTAssertEqual(rows.count, 1)
        XCTAssertEqual(rows[0]["name"]?.stringValue, malicious)
        // Table still exists
        let check = try db.query("SELECT name FROM sqlite_master WHERE type='table' AND name='test'")
        XCTAssertFalse(check.isEmpty)
    }
}
