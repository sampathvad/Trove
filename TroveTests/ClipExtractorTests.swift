import XCTest
import AppKit
@testable import Trove

final class ClipExtractorTests: XCTestCase {

    // Helper: build a test pasteboard with plain text
    private func pasteboard(with string: String) -> NSPasteboard {
        let pb = NSPasteboard.general
        pb.clearContents()
        pb.setString(string, forType: .string)
        return pb
    }

    func testExtractsPlainText() {
        let pb = pasteboard(with: "Hello world")
        let clip = ClipExtractor.extract(from: pb, sourceApp: nil)
        XCTAssertEqual(clip.content.previewText, "Hello world")
        XCTAssertEqual(clip.type, .plainText)
    }

    func testDetectsURL() {
        let pb = pasteboard(with: "https://example.com")
        let clip = ClipExtractor.extract(from: pb, sourceApp: nil)
        XCTAssertEqual(clip.type, .url)
    }

    func testDetectsEmail() {
        let pb = pasteboard(with: "user@example.com")
        let clip = ClipExtractor.extract(from: pb, sourceApp: nil)
        XCTAssertEqual(clip.type, .email)
    }

    func testDetectsHexColor() {
        let pb = pasteboard(with: "#D89A2A")
        let clip = ClipExtractor.extract(from: pb, sourceApp: nil)
        XCTAssertEqual(clip.type, .hexColor)
    }

    func testDetectsJSON() {
        let pb = pasteboard(with: #"{"key":"value"}"#)
        let clip = ClipExtractor.extract(from: pb, sourceApp: nil)
        XCTAssertEqual(clip.type, .json)
    }

    func testSensitiveTextFlagged() {
        let pb = pasteboard(with: "4532015112830366")  // valid Luhn
        let clip = ClipExtractor.extract(from: pb, sourceApp: nil)
        XCTAssertTrue(clip.isSensitive)
    }

    func testNonSensitiveNotFlagged() {
        let pb = pasteboard(with: "Hello, this is normal text.")
        let clip = ClipExtractor.extract(from: pb, sourceApp: nil)
        XCTAssertFalse(clip.isSensitive)
    }

    func testSourceAppPreserved() {
        let pb = pasteboard(with: "test")
        let clip = ClipExtractor.extract(from: pb, sourceApp: "com.apple.Safari")
        XCTAssertEqual(clip.sourceApp, "com.apple.Safari")
    }

    func testCharacterCountInMetadata() {
        let text = "Hello"
        let pb = pasteboard(with: text)
        let clip = ClipExtractor.extract(from: pb, sourceApp: nil)
        XCTAssertEqual(clip.metadata.characterCount, text.count)
    }
}
