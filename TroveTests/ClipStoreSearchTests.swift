import XCTest
@testable import Trove

final class ClipStoreSearchTests: XCTestCase {

    func testSingleTokenIsQuotedWithPrefix() {
        XCTAssertEqual(ClipStore.ftsMatchQuery("hello"), "\"hello\"*")
    }

    func testMultipleTokensEachQuotedAndPrefixed() {
        XCTAssertEqual(ClipStore.ftsMatchQuery("foo bar"), "\"foo\"* \"bar\"*")
    }

    func testEmbeddedQuotesAreDoubled() {
        // A stray double quote would otherwise make FTS5 throw a syntax error.
        XCTAssertEqual(ClipStore.ftsMatchQuery("a\"b"), "\"a\"\"b\"*")
    }

    func testFtsOperatorsAreTreatedAsLiteralText() {
        // Tokens like `NOT`, `foo:`, or `-x` must not act as FTS5 syntax.
        XCTAssertEqual(ClipStore.ftsMatchQuery("NOT foo:"), "\"NOT\"* \"foo:\"*")
        XCTAssertEqual(ClipStore.ftsMatchQuery("-x"), "\"-x\"*")
    }

    func testWhitespaceOnlyReturnsNil() {
        XCTAssertNil(ClipStore.ftsMatchQuery("   "))
        XCTAssertNil(ClipStore.ftsMatchQuery(""))
    }
}
