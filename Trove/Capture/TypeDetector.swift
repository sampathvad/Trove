import Foundation

struct TypeDetector {
    static func detect(_ text: String) -> ClipType {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return .plainText }

        if isURL(trimmed) { return .url }
        if isEmail(trimmed) { return .email }
        if isHexColor(trimmed) { return .hexColor }
        if isRGBColor(trimmed) { return .rgbColor }
        if isHSLColor(trimmed) { return .hslColor }
        if isJSON(trimmed) { return .json }
        // Date before phone/math — dates look like numbers/phone numbers
        if parseDate(trimmed) != nil { return .date }
        if isPhoneNumber(trimmed) { return .phoneNumber }
        // Plain number before math — "-99" is a number, not math
        if Double(trimmed) != nil { return .number }
        if isMathExpression(trimmed) { return .math }
        if isCode(trimmed) { return .code }
        return .plainText
    }

    // MARK: - Detectors

    static func isURL(_ s: String) -> Bool {
        guard let url = URL(string: s) else { return false }
        return ["https", "http", "ftp", "ssh", "file"].contains(url.scheme ?? "")
    }

    static func isEmail(_ s: String) -> Bool {
        let pattern = #"^[A-Z0-9a-z._%+\-]+@[A-Za-z0-9.\-]+\.[A-Za-z]{2,}$"#
        return s.range(of: pattern, options: .regularExpression) != nil
    }

    static func isPhoneNumber(_ s: String) -> Bool {
        let digits = s.filter { $0.isNumber }
        guard digits.count >= 7 && digits.count <= 15 else { return false }
        let pattern = #"^[\d\s\-\+\(\)\.]{7,20}$"#
        return s.range(of: pattern, options: .regularExpression) != nil
    }

    static func isHexColor(_ s: String) -> Bool {
        let pattern = #"^#([0-9A-Fa-f]{3}|[0-9A-Fa-f]{6}|[0-9A-Fa-f]{8})$"#
        return s.range(of: pattern, options: .regularExpression) != nil
    }

    static func isRGBColor(_ s: String) -> Bool {
        let pattern = #"^rgba?\(\s*\d{1,3}\s*,\s*\d{1,3}\s*,\s*\d{1,3}(\s*,\s*[\d.]+)?\s*\)$"#
        return s.range(of: pattern, options: .regularExpression) != nil
    }

    static func isHSLColor(_ s: String) -> Bool {
        let pattern = #"^hsla?\(\s*\d{1,3}\s*,\s*\d{1,3}%\s*,\s*\d{1,3}%(\s*,\s*[\d.]+)?\s*\)$"#
        return s.range(of: pattern, options: .regularExpression) != nil
    }

    static func isJSON(_ s: String) -> Bool {
        guard s.hasPrefix("{") || s.hasPrefix("[") else { return false }
        return (try? JSONSerialization.jsonObject(with: Data(s.utf8))) != nil
    }

    static func isMathExpression(_ s: String) -> Bool {
        // Single line with arithmetic ops and no letters (except common math fns)
        guard !s.contains("\n") else { return false }
        let pattern = #"^[\d\s\+\-\*\/\(\)\.\^%,]+$"#
        return s.range(of: pattern, options: .regularExpression) != nil && s.contains(where: { "+-*/".contains($0) })
    }

    static func parseDate(_ s: String) -> Date? {
        let formats = [
            "yyyy-MM-dd", "MM/dd/yyyy", "dd/MM/yyyy",
            "MMMM d, yyyy", "MMM d, yyyy", "d MMM yyyy",
            "yyyy-MM-dd'T'HH:mm:ssZ", "EEE, dd MMM yyyy HH:mm:ss z"
        ]
        let f = DateFormatter()
        for fmt in formats {
            f.dateFormat = fmt
            if let d = f.date(from: s) { return d }
        }
        return nil
    }

    static func isCode(_ s: String) -> Bool {
        let lines = s.components(separatedBy: .newlines)
        guard lines.count >= 2 else { return false }
        let markers = ["{", "}", ";", "=>", "->", "func ", "def ", "class ",
                       "import ", "const ", "let ", "var ", "//", "/*",
                       "fn ", "pub ", "struct ", "enum ", "interface ",
                       "return ", "if (", "for (", "while (", "elif "]
        let matchCount = markers.filter { s.contains($0) }.count
        return matchCount >= 2
    }

    // MARK: - Language detection (best-effort scoring)

    static func detectLanguage(_ s: String) -> String? {
        var scores: [String: Int] = [:]
        let patterns: [(String, String, [String])] = [
            ("Swift",      "swift",      ["func ", "var ", "let ", "guard ", "struct ", "@State", "some View", "import SwiftUI"]),
            ("Python",     "python",     ["def ", "import ", "elif ", "print(", "self.", "class ", "#!", "lambda "]),
            ("JavaScript", "javascript", ["const ", "=>", "function ", "console.log", "require(", "module.exports", "async ", "await "]),
            ("TypeScript", "typescript", ["interface ", ": string", ": number", ": boolean", "type ", "as ", "implements "]),
            ("Rust",       "rust",       ["fn ", "let mut", "impl ", "pub ", "match ", "use std", "::"]),
            ("Go",         "go",         ["func ", "package ", "import (", ":=", "fmt.Print", "var ", "goroutine"]),
            ("Java",       "java",       ["public class", "private ", "void ", "System.out", "@Override", "extends ", "implements "]),
            ("C/C++",      "cpp",        ["#include", "int main(", "printf(", "std::", "nullptr", "void ", "->"]),
            ("HTML",       "html",       ["<html", "<div", "<span", "<!DOCTYPE", "<head", "<body", "<p>"]),
            ("CSS",        "css",        ["{", "}", "px;", "em;", "rem;", "color:", "font-size:", "margin:"]),
            ("SQL",        "sql",        ["SELECT ", "FROM ", "WHERE ", "INSERT INTO", "UPDATE ", "CREATE TABLE", "JOIN "]),
            ("Shell",      "shell",      ["#!/", "echo ", "grep ", "awk ", "sed ", "chmod ", "export "]),
            ("JSON",       "json",       ["{\"", "\":\"", "\":{"]),
        ]
        for (name, _, keywords) in patterns {
            scores[name] = keywords.filter { s.contains($0) }.count
        }
        return scores.filter { $0.value >= 2 }.max(by: { $0.value < $1.value })?.key
    }
}
