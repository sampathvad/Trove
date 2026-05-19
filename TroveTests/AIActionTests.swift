import XCTest
@testable import Trove

final class AIActionTests: XCTestCase {

    private let sample = "The quick brown fox jumps over the lazy dog."

    func testSummarizePromptMentionsSummarizeAndIncludesContent() {
        let p = AIAction.summarize.prompt(for: sample)
        XCTAssertTrue(p.lowercased().contains("summarize"))
        XCTAssertTrue(p.contains(sample))
    }

    func testRewriteFormalPromptMentionsFormalTone() {
        let p = AIAction.rewriteFormal.prompt(for: sample)
        XCTAssertTrue(p.lowercased().contains("formal"))
        XCTAssertTrue(p.contains(sample))
    }

    func testRewriteCasualPromptMentionsCasualTone() {
        let p = AIAction.rewriteCasual.prompt(for: sample)
        XCTAssertTrue(p.lowercased().contains("casual"))
        XCTAssertTrue(p.contains(sample))
    }

    func testRewriteConcisePromptMentionsConcise() {
        let p = AIAction.rewriteConcise.prompt(for: sample)
        XCTAssertTrue(p.lowercased().contains("concise"))
        XCTAssertTrue(p.contains(sample))
    }

    func testTranslatePromptMentionsTranslate() {
        let p = AIAction.translate.prompt(for: sample)
        XCTAssertTrue(p.lowercased().contains("translate"))
        XCTAssertTrue(p.contains(sample))
    }

    func testFixGrammarPromptMentionsGrammar() {
        let p = AIAction.fixGrammar.prompt(for: sample)
        XCTAssertTrue(p.lowercased().contains("grammar"))
        XCTAssertTrue(p.contains(sample))
    }

    func testExplainCodePromptMentionsExplain() {
        let p = AIAction.explainCode.prompt(for: sample)
        XCTAssertTrue(p.lowercased().contains("explain"))
        XCTAssertTrue(p.contains(sample))
    }

    func testExtractActionsPromptMentionsActionItems() {
        let p = AIAction.extractActions.prompt(for: sample)
        XCTAssertTrue(p.lowercased().contains("action items"))
        XCTAssertTrue(p.contains(sample))
    }

    func testFormatTablePromptMentionsTable() {
        let p = AIAction.formatTable.prompt(for: sample)
        XCTAssertTrue(p.lowercased().contains("table"))
        XCTAssertTrue(p.contains(sample))
    }

    func testEveryActionEmbedsTheContentVerbatim() {
        for action in AIAction.allCases {
            let p = action.prompt(for: sample)
            XCTAssertTrue(
                p.contains(sample),
                "\(action.rawValue) prompt should embed the input content verbatim"
            )
            XCTAssertFalse(
                p.isEmpty,
                "\(action.rawValue) prompt should not be empty"
            )
        }
    }

    func testPromptsAreDistinctAcrossActions() {
        let prompts = AIAction.allCases.map { $0.prompt(for: sample) }
        XCTAssertEqual(Set(prompts).count, prompts.count, "Each action should produce a distinct prompt")
    }
}
