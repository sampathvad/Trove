import XCTest
import AppKit
@testable import Trove

final class ClipDedupTests: XCTestCase {

    private func rtfData(_ s: String) -> Data {
        let attr = NSAttributedString(string: s, attributes: [.font: NSFont.systemFont(ofSize: 13)])
        return (try? attr.data(
            from: NSRange(location: 0, length: attr.length),
            documentAttributes: [.documentType: NSAttributedString.DocumentType.rtf]
        )) ?? Data()
    }

    func testTextAndRichTextOfSameStringHashEqual() {
        let plain = ClipContent.text("hello world")
        let rich = ClipContent.richText(rtfData("hello world"))
        XCTAssertEqual(plain.contentHash, rich.contentHash)
    }

    func testWhitespaceTrimNormalizes() {
        XCTAssertEqual(
            ClipContent.text("hello").contentHash,
            ClipContent.text("  hello\n").contentHash
        )
    }

    func testDifferentTextDiffersInHash() {
        XCTAssertNotEqual(
            ClipContent.text("hello").contentHash,
            ClipContent.text("hello world").contentHash
        )
    }

    func testImageHashStableForSameBytes() {
        let d1 = Data([0xDE, 0xAD, 0xBE, 0xEF])
        let d2 = Data([0xDE, 0xAD, 0xBE, 0xEF])
        let d3 = Data([0xCA, 0xFE, 0xBA, 0xBE])
        XCTAssertEqual(ClipContent.image(d1).contentHash, ClipContent.image(d2).contentHash)
        XCTAssertNotEqual(ClipContent.image(d1).contentHash, ClipContent.image(d3).contentHash)
    }

    func testFileAndTextWithSameStringDoNotCollide() {
        let text = ClipContent.text("readme.md")
        let file = ClipContent.file(URL(fileURLWithPath: "/tmp/readme.md"))
        XCTAssertNotEqual(text.contentHash, file.contentHash)
    }

    func testTwoRTFEncodingsOfSameStringHashEqual() {
        // Two separately-built RTF blobs for the same visible string. Even if
        // the underlying RTF bytes differ (timestamps, generator strings),
        // the dedup hash must match because we hash decoded plain text.
        let a = ClipContent.richText(rtfData("identical text"))
        let b = ClipContent.richText(rtfData("identical text"))
        XCTAssertEqual(a.contentHash, b.contentHash)
    }
}
