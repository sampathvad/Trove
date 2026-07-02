import XCTest
@testable import Trove

final class AIProviderTests: XCTestCase {

    override func setUp() {
        super.setUp()
        URLProtocolStub.reset()
    }

    override func tearDown() {
        URLProtocolStub.reset()
        super.tearDown()
    }

    // MARK: - Helpers

    private func ok(_ json: [String: Any]) throws -> (HTTPURLResponse, Data) {
        let data = try JSONSerialization.data(withJSONObject: json)
        let url = URL(string: "https://example.invalid")!
        let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!
        return (response, data)
    }

    private func okRaw(_ data: Data) -> (HTTPURLResponse, Data) {
        let url = URL(string: "https://example.invalid")!
        let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!
        return (response, data)
    }

    private func status(_ code: Int, _ json: [String: Any]) throws -> (HTTPURLResponse, Data) {
        let data = try JSONSerialization.data(withJSONObject: json)
        let url = URL(string: "https://example.invalid")!
        let response = HTTPURLResponse(url: url, statusCode: code, httpVersion: nil, headerFields: nil)!
        return (response, data)
    }

    private func keychain(_ value: String?) -> KeychainAccess {
        KeychainAccess(load: { _ in value })
    }

    // MARK: - OpenAIProvider

    func testOpenAIHappyPathReturnsUnwrappedContent() async throws {
        URLProtocolStub.handler = { [unowned self] _ in
            try self.ok([
                "choices": [
                    ["message": ["role": "assistant", "content": "  hello world  "]]
                ]
            ])
        }
        let provider = OpenAIProvider(session: URLProtocolStub.session(), keychain: keychain("sk-fake"))
        let result = try await provider.transform(prompt: "p", content: "c")
        XCTAssertEqual(result, "hello world")
    }

    func testOpenAIMissingKeyThrowsMissingAPIKey() async {
        let provider = OpenAIProvider(session: URLProtocolStub.session(), keychain: keychain(nil))
        do {
            _ = try await provider.transform(prompt: "p", content: "c")
            XCTFail("Expected missingAPIKey to throw")
        } catch let AIError.missingAPIKey(provider) {
            XCTAssertEqual(provider, "OpenAI")
        } catch {
            XCTFail("Expected AIError.missingAPIKey, got \(error)")
        }
    }

    func testOpenAIInvalidResponseShapeThrows() async {
        URLProtocolStub.handler = { [unowned self] _ in try self.ok([:]) }
        let provider = OpenAIProvider(session: URLProtocolStub.session(), keychain: keychain("sk-fake"))
        do {
            _ = try await provider.transform(prompt: "p", content: "c")
            XCTFail("Expected invalidResponse to throw")
        } catch AIError.invalidResponse {
            // expected
        } catch {
            XCTFail("Expected AIError.invalidResponse, got \(error)")
        }
    }

    func testOpenAIRequestShapeUsesBearerAuthAndModel() async throws {
        URLProtocolStub.handler = { [unowned self] _ in
            try self.ok(["choices": [["message": ["content": "ok"]]]])
        }
        let provider = OpenAIProvider(session: URLProtocolStub.session(), keychain: keychain("sk-test-123"))
        _ = try await provider.transform(prompt: "the prompt", content: "the content")

        XCTAssertEqual(URLProtocolStub.capturedRequests.count, 1)
        let req = URLProtocolStub.capturedRequests[0]
        XCTAssertEqual(req.httpMethod, "POST")
        XCTAssertEqual(req.url?.absoluteString, "https://api.openai.com/v1/chat/completions")
        XCTAssertEqual(req.value(forHTTPHeaderField: "Authorization"), "Bearer sk-test-123")
        XCTAssertEqual(req.value(forHTTPHeaderField: "Content-Type"), "application/json")

        let bodyData = req.bodyStreamData() ?? req.httpBody ?? Data()
        let body = try JSONSerialization.jsonObject(with: bodyData) as? [String: Any]
        XCTAssertEqual(body?["model"] as? String, "gpt-4o-mini")
        let messages = body?["messages"] as? [[String: String]]
        XCTAssertEqual(messages?.first?["role"], "user")
        XCTAssertEqual(messages?.first?["content"], "the prompt")
    }

    func testOpenAI401ThrowsHTTPErrorWithProviderMessage() async {
        URLProtocolStub.handler = { [unowned self] _ in
            try self.status(401, ["error": ["message": "Incorrect API key provided."]])
        }
        let provider = OpenAIProvider(session: URLProtocolStub.session(), keychain: keychain("sk-bad"))
        do {
            _ = try await provider.transform(prompt: "p", content: "c")
            XCTFail("Expected httpError to throw")
        } catch let AIError.httpError(provider, status, message) {
            XCTAssertEqual(provider, "OpenAI")
            XCTAssertEqual(status, 401)
            XCTAssertEqual(message, "Incorrect API key provided.")
        } catch {
            XCTFail("Expected AIError.httpError, got \(error)")
        }
    }

    // MARK: - AnthropicProvider

    func testAnthropicHappyPathReturnsFirstContentBlock() async throws {
        URLProtocolStub.handler = { [unowned self] _ in
            try self.ok([
                "content": [["type": "text", "text": "  claude says hi  "]]
            ])
        }
        let provider = AnthropicProvider(session: URLProtocolStub.session(), keychain: keychain("ant-fake"))
        let result = try await provider.transform(prompt: "p", content: "c")
        XCTAssertEqual(result, "claude says hi")
    }

    func testAnthropicMissingKeyThrowsMissingAPIKey() async {
        let provider = AnthropicProvider(session: URLProtocolStub.session(), keychain: keychain(nil))
        do {
            _ = try await provider.transform(prompt: "p", content: "c")
            XCTFail("Expected missingAPIKey to throw")
        } catch let AIError.missingAPIKey(provider) {
            XCTAssertEqual(provider, "Anthropic")
        } catch {
            XCTFail("Expected AIError.missingAPIKey, got \(error)")
        }
    }

    func testAnthropicInvalidResponseShapeThrows() async {
        URLProtocolStub.handler = { [unowned self] _ in try self.ok([:]) }
        let provider = AnthropicProvider(session: URLProtocolStub.session(), keychain: keychain("ant-fake"))
        do {
            _ = try await provider.transform(prompt: "p", content: "c")
            XCTFail("Expected invalidResponse to throw")
        } catch AIError.invalidResponse {
            // expected
        } catch {
            XCTFail("Expected AIError.invalidResponse, got \(error)")
        }
    }

    func testAnthropicRequestShapeUsesXAPIKeyHeaderAndVersion() async throws {
        URLProtocolStub.handler = { [unowned self] _ in
            try self.ok(["content": [["type": "text", "text": "ok"]]])
        }
        let provider = AnthropicProvider(session: URLProtocolStub.session(), keychain: keychain("ant-test-456"))
        _ = try await provider.transform(prompt: "ask claude", content: "c")

        XCTAssertEqual(URLProtocolStub.capturedRequests.count, 1)
        let req = URLProtocolStub.capturedRequests[0]
        XCTAssertEqual(req.httpMethod, "POST")
        XCTAssertEqual(req.url?.absoluteString, "https://api.anthropic.com/v1/messages")
        XCTAssertEqual(req.value(forHTTPHeaderField: "x-api-key"), "ant-test-456")
        XCTAssertEqual(req.value(forHTTPHeaderField: "anthropic-version"), "2023-06-01")
        XCTAssertEqual(req.value(forHTTPHeaderField: "Content-Type"), "application/json")
        XCTAssertNil(req.value(forHTTPHeaderField: "Authorization"), "Anthropic uses x-api-key, not Bearer")

        let bodyData = req.bodyStreamData() ?? req.httpBody ?? Data()
        let body = try JSONSerialization.jsonObject(with: bodyData) as? [String: Any]
        XCTAssertEqual(body?["model"] as? String, "claude-haiku-4-5-20251001")
        XCTAssertEqual(body?["max_tokens"] as? Int, 1024)
        let messages = body?["messages"] as? [[String: String]]
        XCTAssertEqual(messages?.first?["role"], "user")
        XCTAssertEqual(messages?.first?["content"], "ask claude")
    }

    func testAnthropic429ThrowsHTTPError() async {
        URLProtocolStub.handler = { [unowned self] _ in
            try self.status(429, ["type": "error", "error": ["type": "rate_limit_error", "message": "Overloaded"]])
        }
        let provider = AnthropicProvider(session: URLProtocolStub.session(), keychain: keychain("ant-key"))
        do {
            _ = try await provider.transform(prompt: "p", content: "c")
            XCTFail("Expected httpError to throw")
        } catch let AIError.httpError(provider, status, message) {
            XCTAssertEqual(provider, "Anthropic")
            XCTAssertEqual(status, 429)
            XCTAssertEqual(message, "Overloaded")
        } catch {
            XCTFail("Expected AIError.httpError, got \(error)")
        }
    }

    // MARK: - OllamaProvider

    func testOllamaHappyPathReturnsResponseField() async throws {
        URLProtocolStub.handler = { [unowned self] _ in
            try self.ok(["response": "  ollama replies  "])
        }
        let provider = OllamaProvider(session: URLProtocolStub.session(), baseURL: "http://localhost:11434", model: "llama3")
        let result = try await provider.transform(prompt: "p", content: "c")
        XCTAssertEqual(result, "ollama replies")
    }

    func testOllamaInvalidResponseShapeThrows() async {
        URLProtocolStub.handler = { [unowned self] _ in try self.ok([:]) }
        let provider = OllamaProvider(session: URLProtocolStub.session())
        do {
            _ = try await provider.transform(prompt: "p", content: "c")
            XCTFail("Expected invalidResponse to throw")
        } catch AIError.invalidResponse {
            // expected
        } catch {
            XCTFail("Expected AIError.invalidResponse, got \(error)")
        }
    }

    func testOllamaRequestShapeHasNoAuthHeaders() async throws {
        URLProtocolStub.handler = { [unowned self] _ in try self.ok(["response": "ok"]) }
        let provider = OllamaProvider(
            session: URLProtocolStub.session(),
            baseURL: "http://localhost:11434",
            model: "llama3"
        )
        _ = try await provider.transform(prompt: "p", content: "c")

        XCTAssertEqual(URLProtocolStub.capturedRequests.count, 1)
        let req = URLProtocolStub.capturedRequests[0]
        XCTAssertEqual(req.url?.absoluteString, "http://localhost:11434/api/generate")
        XCTAssertNil(req.value(forHTTPHeaderField: "Authorization"))
        XCTAssertNil(req.value(forHTTPHeaderField: "x-api-key"))

        let bodyData = req.bodyStreamData() ?? req.httpBody ?? Data()
        let body = try JSONSerialization.jsonObject(with: bodyData) as? [String: Any]
        XCTAssertEqual(body?["model"] as? String, "llama3")
        XCTAssertEqual(body?["stream"] as? Bool, false)
    }

    func testOllamaBaseURLIsRespected() async throws {
        URLProtocolStub.handler = { [unowned self] _ in try self.ok(["response": "ok"]) }
        let provider = OllamaProvider(
            session: URLProtocolStub.session(),
            baseURL: "http://example.invalid:9999",
            model: "llama3"
        )
        _ = try await provider.transform(prompt: "p", content: "c")

        XCTAssertEqual(URLProtocolStub.capturedRequests.first?.url?.absoluteString,
                       "http://example.invalid:9999/api/generate")
    }

    func testOllama500ThrowsHTTPErrorWithStringMessage() async {
        URLProtocolStub.handler = { [unowned self] _ in
            try self.status(500, ["error": "model 'llama3' not found"])
        }
        let provider = OllamaProvider(session: URLProtocolStub.session())
        do {
            _ = try await provider.transform(prompt: "p", content: "c")
            XCTFail("Expected httpError to throw")
        } catch let AIError.httpError(provider, status, message) {
            XCTAssertEqual(provider, "Ollama (local)")
            XCTAssertEqual(status, 500)
            XCTAssertEqual(message, "model 'llama3' not found")
        } catch {
            XCTFail("Expected AIError.httpError, got \(error)")
        }
    }
}

// MARK: - URLRequest body stream helper

private extension URLRequest {
    func bodyStreamData() -> Data? {
        guard let stream = httpBodyStream else { return nil }
        stream.open()
        defer { stream.close() }
        var data = Data()
        let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: 4096)
        defer { buffer.deallocate() }
        while stream.hasBytesAvailable {
            let read = stream.read(buffer, maxLength: 4096)
            if read <= 0 { break }
            data.append(buffer, count: read)
        }
        return data
    }
}
