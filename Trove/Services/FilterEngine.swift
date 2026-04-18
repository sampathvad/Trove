import Foundation

struct FilterEngine {
    static func applyBuiltin(_ filter: BuiltinFilter, to text: String) -> String {
        switch filter {
        case .plainText:
            return text
        case .lowercase:
            return text.lowercased()
        case .uppercase:
            return text.uppercased()
        case .titleCase:
            return text.capitalized
        case .trimWhitespace:
            return text.trimmingCharacters(in: .whitespacesAndNewlines)
        case .stripNewlines:
            return text.components(separatedBy: .newlines).joined(separator: " ")
        case .urlEncode:
            return text.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? text
        case .urlDecode:
            return text.removingPercentEncoding ?? text
        case .base64Encode:
            return Data(text.utf8).base64EncodedString()
        case .base64Decode:
            guard let data = Data(base64Encoded: text),
                  let decoded = String(data: data, encoding: .utf8) else { return text }
            return decoded
        case .jsonPretty:
            guard let data = text.data(using: .utf8),
                  let obj = try? JSONSerialization.jsonObject(with: data),
                  let pretty = try? JSONSerialization.data(withJSONObject: obj, options: [.prettyPrinted]),
                  let str = String(data: pretty, encoding: .utf8) else { return text }
            return str
        case .jsonMinify:
            guard let data = text.data(using: .utf8),
                  let obj = try? JSONSerialization.jsonObject(with: data),
                  let minified = try? JSONSerialization.data(withJSONObject: obj),
                  let str = String(data: minified, encoding: .utf8) else { return text }
            return str
        case .stripHTML:
            guard let data = text.data(using: .utf8),
                  let attrStr = try? NSAttributedString(
                      data: data,
                      options: [.documentType: NSAttributedString.DocumentType.html,
                                .characterEncoding: String.Encoding.utf8.rawValue],
                      documentAttributes: nil
                  ) else {
                // Fallback: regex strip
                return text.replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
            }
            return attrStr.string
        case .reverseText:
            return String(text.reversed())
        case .wordCount:
            let count = text.components(separatedBy: .whitespacesAndNewlines).filter { !$0.isEmpty }.count
            return "\(count) words"
        }
    }

    static func applyRegex(_ pattern: String, replacement: String, to text: String) -> String {
        text.replacingOccurrences(
            of: pattern,
            with: replacement,
            options: .regularExpression
        )
    }

    static func evaluateMath(_ expression: String) -> String? {
        // NSExpression throws ObjC exceptions on invalid input — guard with basic validation
        let allowed = CharacterSet(charactersIn: "0123456789.+-*/() ")
        guard expression.unicodeScalars.allSatisfy({ allowed.contains($0) }) else { return nil }
        guard let result = NSExpression(format: expression)
            .expressionValue(with: nil, context: nil) as? NSNumber else { return nil }
        return result.stringValue
    }
}
