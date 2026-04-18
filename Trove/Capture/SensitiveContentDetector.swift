import Foundation

struct SensitiveContentDetector {
    static func isSensitive(_ text: String) -> Bool {
        return matchesCreditCard(text)
            || matchesSSN(text)
            || matchesAPIKey(text)
            || matchesPrivateKey(text)
            || matchesPassword(text)
            || matchesHighEntropyToken(text)
    }

    // MARK: - Credit card (Luhn)

    static func matchesCreditCard(_ s: String) -> Bool {
        let digits = s.filter { $0.isNumber }
        guard digits.count >= 13 && digits.count <= 19 else { return false }
        return luhn(digits)
    }

    private static func luhn(_ digits: String) -> Bool {
        var sum = 0
        for (index, char) in digits.reversed().enumerated() {
            guard let digit = char.wholeNumberValue else { return false }
            if index % 2 == 1 {
                let doubled = digit * 2
                sum += doubled > 9 ? doubled - 9 : doubled
            } else {
                sum += digit
            }
        }
        return sum % 10 == 0
    }

    // MARK: - SSN

    static func matchesSSN(_ s: String) -> Bool {
        let pattern = #"^\d{3}-\d{2}-\d{4}$"#
        return s.trimmingCharacters(in: .whitespaces).range(of: pattern, options: .regularExpression) != nil
    }

    // MARK: - API keys (prefix + regex)

    static func matchesAPIKey(_ s: String) -> Bool {
        let t = s.trimmingCharacters(in: .whitespacesAndNewlines)

        // Prefix-based
        let prefixes = [
            "sk-", "sk_live_", "sk_test_",          // OpenAI, Stripe secret
            "pk_live_", "pk_test_",                  // Stripe public
            "rk_live_", "rk_test_",                  // Stripe restricted
            "Bearer ",                               // OAuth tokens
            "ghp_", "gho_", "ghs_", "ghr_", "github_pat_",  // GitHub
            "xoxb-", "xoxp-", "xoxa-", "xoxs-",    // Slack
            "AIza",                                  // Google
            "AKIA",                                  // AWS Access Key
        ]
        if prefixes.contains(where: { t.hasPrefix($0) }) { return true }

        // Regex-based
        let patterns = [
            #"AKIA[0-9A-Z]{16}"#,                   // AWS Access Key ID
            #"[0-9a-zA-Z/+]{40}"#,                   // AWS Secret (base64, 40 chars)
            #"AIza[0-9A-Za-z\-_]{35}"#,              // Google API Key
            #"ya29\.[0-9A-Za-z\-_]+"#,               // Google OAuth token
            #"EAA[0-9A-Za-z]+"#,                     // Facebook access token
            #"AC[a-z0-9]{32}"#,                      // Twilio Account SID
            #"SK[a-z0-9]{32}"#,                      // Twilio Auth Token
            #"[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}"#, // UUID-format keys
        ]
        for pattern in patterns {
            if t.range(of: pattern, options: .regularExpression) != nil { return true }
        }
        return false
    }

    // MARK: - Private keys

    static func matchesPrivateKey(_ s: String) -> Bool {
        return s.contains("BEGIN RSA PRIVATE KEY")
            || s.contains("BEGIN PRIVATE KEY")
            || s.contains("BEGIN EC PRIVATE KEY")
            || s.contains("BEGIN OPENSSH PRIVATE KEY")
            || s.contains("BEGIN DSA PRIVATE KEY")
    }

    // MARK: - Password heuristic

    static func matchesPassword(_ s: String) -> Bool {
        let trimmed = s.trimmingCharacters(in: .whitespacesAndNewlines)
        // Single-line, no spaces, 12+ chars, high complexity
        guard !trimmed.contains(" "), trimmed.count >= 12, !trimmed.contains("\n") else { return false }
        let hasUpper   = trimmed.contains { $0.isUppercase }
        let hasLower   = trimmed.contains { $0.isLowercase }
        let hasDigit   = trimmed.contains { $0.isNumber }
        let hasSpecial = trimmed.contains { "!@#$%^&*()_+-=[]{}|;':\",./<>?`~\\".contains($0) }
        return [hasUpper, hasLower, hasDigit, hasSpecial].filter { $0 }.count >= 3
    }

    // MARK: - High-entropy token (40+ alphanum chars on one line)

    static func matchesHighEntropyToken(_ s: String) -> Bool {
        let trimmed = s.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count >= 40, !trimmed.contains(" "), !trimmed.contains("\n") else { return false }
        let alphanum = trimmed.filter { $0.isLetter || $0.isNumber }
        // >90% alphanumeric = likely a token/secret
        return Double(alphanum.count) / Double(trimmed.count) > 0.90
    }
}
