import XCTest
@testable import Trove

final class TypeDetectorTests: XCTestCase {

    // MARK: - URL
    func testHTTPSURL() { XCTAssertEqual(TypeDetector.detect("https://example.com"), .url) }
    func testHTTPURL()  { XCTAssertEqual(TypeDetector.detect("http://foo.bar/path?q=1"), .url) }
    func testNotURL()   { XCTAssertNotEqual(TypeDetector.detect("not a url"), .url) }

    // MARK: - Email
    func testValidEmail()   { XCTAssertEqual(TypeDetector.detect("user@example.com"), .email) }
    func testInvalidEmail() { XCTAssertNotEqual(TypeDetector.detect("notanemail"), .email) }
    func testEmailWithPlus(){ XCTAssertEqual(TypeDetector.detect("user+tag@example.co.uk"), .email) }

    // MARK: - Phone
    func testUSPhone()          { XCTAssertEqual(TypeDetector.detect("+1 (555) 123-4567"), .phoneNumber) }
    func testShortNotPhone()    { XCTAssertNotEqual(TypeDetector.detect("123"), .phoneNumber) }

    // MARK: - Colors
    func testHexColor6()  { XCTAssertEqual(TypeDetector.detect("#D89A2A"), .hexColor) }
    func testHexColor3()  { XCTAssertEqual(TypeDetector.detect("#fff"), .hexColor) }
    func testHexColor8()  { XCTAssertEqual(TypeDetector.detect("#AABBCCDD"), .hexColor) }
    func testBadHex()     { XCTAssertNotEqual(TypeDetector.detect("#ZZZZZZ"), .hexColor) }
    func testRGBColor()   { XCTAssertEqual(TypeDetector.detect("rgb(255, 128, 0)"), .rgbColor) }
    func testRGBAColor()  { XCTAssertEqual(TypeDetector.detect("rgba(255, 128, 0, 0.5)"), .rgbColor) }
    func testHSLColor()   { XCTAssertEqual(TypeDetector.detect("hsl(120, 50%, 75%)"), .hslColor) }

    // MARK: - JSON
    func testJSONObject() { XCTAssertEqual(TypeDetector.detect(#"{"key": "value"}"#), .json) }
    func testJSONArray()  { XCTAssertEqual(TypeDetector.detect("[1, 2, 3]"), .json) }
    func testBadJSON()    { XCTAssertNotEqual(TypeDetector.detect("not json"), .json) }

    // MARK: - Number
    func testInteger()  { XCTAssertEqual(TypeDetector.detect("42"), .number) }
    func testFloat()    { XCTAssertEqual(TypeDetector.detect("3.14"), .number) }
    func testNegative() { XCTAssertEqual(TypeDetector.detect("-99"), .number) }

    // MARK: - Math
    func testAddition()       { XCTAssertEqual(TypeDetector.detect("3 + 4"), .math) }
    func testMixedArithmetic(){ XCTAssertEqual(TypeDetector.detect("100 / 5 * 2"), .math) }
    func testParentheses()    { XCTAssertEqual(TypeDetector.detect("(2 + 3) * 4"), .math) }

    // MARK: - Date
    func testISODate()       { XCTAssertEqual(TypeDetector.detect("2026-04-18"), .date) }
    func testSlashDate()     { XCTAssertEqual(TypeDetector.detect("04/18/2026"), .date) }
    func testLongDate()      { XCTAssertEqual(TypeDetector.detect("April 18, 2026"), .date) }

    // MARK: - Code
    func testSwiftCode() {
        let code = "func hello() {\n    print(\"world\")\n}"
        XCTAssertEqual(TypeDetector.detect(code), .code)
    }
    func testPythonCode() {
        let code = "def greet():\n    print('hello')\n    return True"
        XCTAssertEqual(TypeDetector.detect(code), .code)
    }

    // MARK: - Language detection
    func testDetectsSwift() {
        let code = "import SwiftUI\nfunc foo() -> String {\n    let x = \"bar\"\n    guard !x.isEmpty else { return \"\" }\n    return x\n}"
        XCTAssertEqual(TypeDetector.detectLanguage(code), "Swift")
    }
    func testDetectsSQL() {
        let code = "SELECT id, name FROM users WHERE id = 1;"
        XCTAssertEqual(TypeDetector.detectLanguage(code), "SQL")
    }

    // MARK: - Plain text fallback
    func testPlainText() { XCTAssertEqual(TypeDetector.detect("Hello, world!"), .plainText) }
    func testEmptyString(){ XCTAssertEqual(TypeDetector.detect(""), .plainText) }
}
