import Foundation

struct TroveFilter: Identifiable, Codable {
    let id: UUID
    var name: String
    var kind: FilterKind
    var definition: String
    var isEnabled: Bool

    enum FilterKind: String, Codable, CaseIterable {
        case builtin, regex, shellScript
    }
}

enum BuiltinFilter: String, CaseIterable {
    case plainText      = "Plain text"
    case lowercase      = "lowercase"
    case uppercase      = "UPPERCASE"
    case titleCase      = "Title Case"
    case trimWhitespace = "Trim whitespace"
    case stripNewlines  = "Strip newlines"
    case urlEncode      = "URL encode"
    case urlDecode      = "URL decode"
    case base64Encode   = "Base64 encode"
    case base64Decode   = "Base64 decode"
    case jsonPretty     = "JSON pretty"
    case jsonMinify     = "JSON minify"
    case stripHTML      = "Strip HTML tags"
    case reverseText    = "Reverse"
    case wordCount      = "Word count"
}
