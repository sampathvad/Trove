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

// MARK: - OpenAI Provider

struct OpenAIProvider: AIProvider {
    let name = "OpenAI"
    private let model = "gpt-4o-mini"

    func transform(prompt: String, content: String) async throws -> String {
        guard let key = KeychainHelper.load(key: "trove.openai.apikey") else {
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
        let (data, _) = try await URLSession.shared.data(for: req)
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

    func transform(prompt: String, content: String) async throws -> String {
        guard let key = KeychainHelper.load(key: "trove.anthropic.apikey") else {
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
        let (data, _) = try await URLSession.shared.data(for: req)
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

    func transform(prompt: String, content: String) async throws -> String {
        let body: [String: Any] = ["model": model, "prompt": prompt, "stream": false]
        var req = URLRequest(url: URL(string: "\(baseURL)/api/generate")!)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try JSONSerialization.data(withJSONObject: body)
        let (data, _) = try await URLSession.shared.data(for: req)
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        guard let response = json?["response"] as? String else { throw AIError.invalidResponse }
        return response.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

// MARK: - Error

enum AIError: LocalizedError {
    case missingAPIKey(String)
    case invalidResponse

    var errorDescription: String? {
        switch self {
        case .missingAPIKey(let p): return "No API key found for \(p). Add it in Settings → AI."
        case .invalidResponse: return "Unexpected response from AI provider."
        }
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
