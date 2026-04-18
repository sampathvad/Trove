import XCTest
@testable import Trove

final class FilterEngineTests: XCTestCase {

    // MARK: - Built-in filters

    func testPlainText()     { XCTAssertEqual(FilterEngine.applyBuiltin(.plainText, to: "Hello"), "Hello") }
    func testLowercase()     { XCTAssertEqual(FilterEngine.applyBuiltin(.lowercase, to: "Hello World"), "hello world") }
    func testUppercase()     { XCTAssertEqual(FilterEngine.applyBuiltin(.uppercase, to: "hello world"), "HELLO WORLD") }
    func testTitleCase()     { XCTAssertEqual(FilterEngine.applyBuiltin(.titleCase, to: "hello world"), "Hello World") }

    func testTrimWhitespace() {
        XCTAssertEqual(FilterEngine.applyBuiltin(.trimWhitespace, to: "  hello  "), "hello")
    }
    func testStripNewlines() {
        XCTAssertEqual(FilterEngine.applyBuiltin(.stripNewlines, to: "hello\nworld"), "hello world")
    }

    func testURLEncode() {
        XCTAssertEqual(FilterEngine.applyBuiltin(.urlEncode, to: "hello world"), "hello%20world")
    }
    func testURLDecode() {
        XCTAssertEqual(FilterEngine.applyBuiltin(.urlDecode, to: "hello%20world"), "hello world")
    }

    func testBase64Encode() {
        XCTAssertEqual(FilterEngine.applyBuiltin(.base64Encode, to: "hello"), "aGVsbG8=")
    }
    func testBase64Decode() {
        XCTAssertEqual(FilterEngine.applyBuiltin(.base64Decode, to: "aGVsbG8="), "hello")
    }
    func testBase64DecodeInvalid() {
        // Returns original string when decode fails
        XCTAssertEqual(FilterEngine.applyBuiltin(.base64Decode, to: "not-base64!"), "not-base64!")
    }

    func testJSONPretty() {
        let minified = #"{"key":"value"}"#
        let result = FilterEngine.applyBuiltin(.jsonPretty, to: minified)
        XCTAssertTrue(result.contains("\n"))
        XCTAssertTrue(result.contains("  "))
    }
    func testJSONMinify() {
        let pretty = "{\n  \"key\": \"value\"\n}"
        let result = FilterEngine.applyBuiltin(.jsonMinify, to: pretty)
        XCTAssertFalse(result.contains("\n"))
    }
    func testJSONPrettyInvalidInput() {
        let bad = "not json"
        XCTAssertEqual(FilterEngine.applyBuiltin(.jsonPretty, to: bad), bad)
    }

    func testStripHTML() {
        XCTAssertEqual(FilterEngine.applyBuiltin(.stripHTML, to: "<b>hello</b>"), "hello")
    }
    func testStripHTMLNested() {
        let html = "<div><p>Hello <strong>world</strong></p></div>"
        let result = FilterEngine.applyBuiltin(.stripHTML, to: html)
        XCTAssertTrue(result.contains("Hello"))
        XCTAssertFalse(result.contains("<"))
    }

    func testReverseText() {
        XCTAssertEqual(FilterEngine.applyBuiltin(.reverseText, to: "hello"), "olleh")
    }
    func testWordCount() {
        XCTAssertEqual(FilterEngine.applyBuiltin(.wordCount, to: "one two three"), "3 words")
    }

    // MARK: - Regex filter

    func testRegexReplaceDigits() {
        XCTAssertEqual(FilterEngine.applyRegex("\\d+", replacement: "#", to: "abc123def456"), "abc#def#")
    }
    func testRegexNoMatch() {
        XCTAssertEqual(FilterEngine.applyRegex("xyz", replacement: "!", to: "hello"), "hello")
    }
    func testRegexCaptureGroup() {
        XCTAssertEqual(FilterEngine.applyRegex("(\\w+)@(\\w+)", replacement: "$1 at $2", to: "user@host"), "user at host")
    }

    // MARK: - Math evaluation

    func testSimpleAddition()    { XCTAssertEqual(FilterEngine.evaluateMath("2 + 2"), "4") }
    func testMultiplication()    { XCTAssertEqual(FilterEngine.evaluateMath("3 * 4"), "12") }
    func testDivision()          { XCTAssertEqual(FilterEngine.evaluateMath("10 / 2"), "5") }
    func testInvalidExpression() { XCTAssertNil(FilterEngine.evaluateMath("not math")) }
}
