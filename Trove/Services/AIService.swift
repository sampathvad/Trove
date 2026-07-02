import Foundation
import Security

// MARK: - Protocol

protocol AIProvider {
    var name: String { get }
    func transform(prompt: String, content: String) async throws -> String
}

// MARK: - Actions

enum AIAction: String, CaseIterable {
    case summarize      = "Summarize"
    case rewriteFormal  = "Rewrite (formal)"
    case rewriteCasual  = "Rewrite (casual)"
    case rewriteConcise = "Rewrite (concise)"
    case translate      = "Translate…"
    case fixGrammar     = "Fix grammar"
    case explainCode    = "Explain code"
    case extractActions = "Extract action items"
    case formatTable    = "Format as table"

    func prompt(for content: String) -> String {
        switch self {
        case .summarize:
            return "Summarize the following text concisely:\n\n\(content)"
        case .rewriteFormal:
            return "Rewrite the following in a formal, professional tone:\n\n\(content)"
        case .rewriteCasual:
            return "Rewrite the following in a casual, conversational tone:\n\n\(content)"
        case .rewriteConcise:
            return "Rewrite the following as concisely as possible, keeping all key information:\n\n\(content)"
        case .translate:
            return "Translate the following to English (or if already English, to Spanish):\n\n\(content)"
        case .fixGrammar:
            return "Fix any grammar, spelling, and punctuation errors in the following text. Return only the corrected text:\n\n\(content)"
        case .explainCode:
            return "Explain what this code does in plain English:\n\n\(content)"
        case .extractActions:
            return "Extract all action items from the following text as a numbered list:\n\n\(content)"
        case .formatTable:
            return "Format the following data as a Markdown table:\n\n\(content)"
        }
    }
}

// MARK: - Dependency seam

struct KeychainAccess {
    var load: (String) -> String?
    static let live = KeychainAccess(load: KeychainHelper.load)
}

// MARK: - OpenAI Provider

struct OpenAIProvider: AIProvider {
    let name = "OpenAI"
    private let model = "gpt-4o-mini"
    private let session: URLSession
    private let keychain: KeychainAccess

    init(session: URLSession = .shared, keychain: KeychainAccess = .live) {
        self.session = session
        self.keychain = keychain
    }

    func transform(prompt: String, content: String) async throws -> String {
        guard let key = keychain.load("trove.openai.apikey") else {
            throw AIError.missingAPIKey("OpenAI")
        }
        let body: [String: Any] = [
            "model": model,
            "messages": [["role": "user", "content": prompt]]
        ]
        var req = URLRequest(url: URL(string: "https://api.openai.com/v1/chat/completions")!)
        req.httpMethod = "POST"
        req.setValue("Bearer \(key)", forHTTPHeaderField: "Authorization")
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try JSONSerialization.data(withJSONObject: body)
        let (data, response) = try await session.data(for: req)
        try AIHTTP.ensureSuccess(response, data: data, provider: name)
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        guard let text = (json?["choices"] as? [[String: Any]])?.first?["message"] as? [String: Any],
              let content = text["content"] as? String else {
            throw AIError.invalidResponse
        }
        return content.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

// MARK: - Anthropic Provider

struct AnthropicProvider: AIProvider {
    let name = "Anthropic"
    private let model = "claude-haiku-4-5-20251001"
    private let session: URLSession
    private let keychain: KeychainAccess

    init(session: URLSession = .shared, keychain: KeychainAccess = .live) {
        self.session = session
        self.keychain = keychain
    }

    func transform(prompt: String, content: String) async throws -> String {
        guard let key = keychain.load("trove.anthropic.apikey") else {
            throw AIError.missingAPIKey("Anthropic")
        }
        let body: [String: Any] = [
            "model": model,
            "max_tokens": 1024,
            "messages": [["role": "user", "content": prompt]]
        ]
        var req = URLRequest(url: URL(string: "https://api.anthropic.com/v1/messages")!)
        req.httpMethod = "POST"
        req.setValue(key, forHTTPHeaderField: "x-api-key")
        req.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try JSONSerialization.data(withJSONObject: body)
        let (data, response) = try await session.data(for: req)
        try AIHTTP.ensureSuccess(response, data: data, provider: name)
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        guard let arr = json?["content"] as? [[String: Any]],
              let text = arr.first?["text"] as? String else {
            throw AIError.invalidResponse
        }
        return text.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

// MARK: - Ollama Provider (local)

struct OllamaProvider: AIProvider {
    let name = "Ollama (local)"
    var baseURL = "http://localhost:11434"
    var model = "llama3"
    private let session: URLSession

    init(session: URLSession = .shared, baseURL: String = "http://localhost:11434", model: String = "llama3") {
        self.session = session
        self.baseURL = baseURL
        self.model = model
    }

    func transform(prompt: String, content: String) async throws -> String {
        let body: [String: Any] = ["model": model, "prompt": prompt, "stream": false]
        var req = URLRequest(url: URL(string: "\(baseURL)/api/generate")!)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try JSONSerialization.data(withJSONObject: body)
        let (data, response) = try await session.data(for: req)
        try AIHTTP.ensureSuccess(response, data: data, provider: name)
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        guard let text = json?["response"] as? String else { throw AIError.invalidResponse }
        return text.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

// MARK: - Error

enum AIError: LocalizedError {
    case missingAPIKey(String)
    case invalidResponse
    case httpError(provider: String, status: Int, message: String?)

    var errorDescription: String? {
        switch self {
        case .missingAPIKey(let p): return "No API key found for \(p). Add it in Settings → AI."
        case .invalidResponse: return "Unexpected response from AI provider."
        case .httpError(let provider, let status, let message):
            let base: String
            switch status {
            case 401, 403:
                base = "\(provider) rejected the API key (HTTP \(status)). Check it in Settings → AI."
            case 429:
                base = "\(provider) rate limit reached (HTTP \(status)). Try again shortly."
            case 500..<600:
                base = "\(provider) had a server error (HTTP \(status)). Try again later."
            default:
                base = "\(provider) request failed (HTTP \(status))."
            }
            if let message, !message.isEmpty { return "\(base) \(message)" }
            return base
        }
    }
}

// MARK: - HTTP status handling

enum AIHTTP {
    /// Throws `AIError.httpError` for any non-2xx response, pulling a human
    /// message out of the provider's error body when one is present. A
    /// non-HTTP response (e.g. a stub) is treated as success.
    static func ensureSuccess(_ response: URLResponse, data: Data, provider: String) throws {
        guard let http = response as? HTTPURLResponse else { return }
        guard !(200..<300).contains(http.statusCode) else { return }
        throw AIError.httpError(provider: provider, status: http.statusCode,
                                message: errorMessage(from: data))
    }

    /// Best-effort extraction of an error string across provider shapes:
    /// OpenAI/Anthropic `{"error": {"message": …}}`, Ollama `{"error": "…"}`,
    /// or a top-level `{"message": …}`.
    private static func errorMessage(from data: Data) -> String? {
        guard let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return nil }
        if let err = obj["error"] as? [String: Any], let message = err["message"] as? String {
            return message
        }
        if let message = obj["error"] as? String { return message }
        if let message = obj["message"] as? String { return message }
        return nil
    }
}

// MARK: - Keychain helper

enum KeychainHelper {
    static func save(key: String, value: String) {
        let data = Data(value.utf8)
        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrAccount: key,
            kSecValueData: data
        ]
        SecItemDelete(query as CFDictionary)
        SecItemAdd(query as CFDictionary, nil)
    }

    static func load(key: String) -> String? {
        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrAccount: key,
            kSecReturnData: true,
            kSecMatchLimit: kSecMatchLimitOne
        ]
        var result: AnyObject?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
              let data = result as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    static func delete(key: String) {
        let query: [CFString: Any] = [kSecClass: kSecClassGenericPassword, kSecAttrAccount: key]
        SecItemDelete(query as CFDictionary)
    }
}
