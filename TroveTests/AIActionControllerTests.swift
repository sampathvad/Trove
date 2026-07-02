import XCTest
@testable import Trove

@MainActor
final class AIActionControllerTests: XCTestCase {

    func testCurrentProviderMapsSettingToProvider() {
        let original = TroveSettings.aiProvider
        defer { TroveSettings.aiProvider = original }

        TroveSettings.aiProvider = "openai"
        XCTAssertEqual(AIActionController.currentProvider().name, "OpenAI")

        TroveSettings.aiProvider = "anthropic"
        XCTAssertEqual(AIActionController.currentProvider().name, "Anthropic")

        TroveSettings.aiProvider = "ollama"
        XCTAssertEqual(AIActionController.currentProvider().name, "Ollama (local)")
    }

    func testUnknownProviderFallsBackToOpenAI() {
        let original = TroveSettings.aiProvider
        defer { TroveSettings.aiProvider = original }

        TroveSettings.aiProvider = "not-a-provider"
        XCTAssertEqual(AIActionController.currentProvider().name, "OpenAI")
    }
}
