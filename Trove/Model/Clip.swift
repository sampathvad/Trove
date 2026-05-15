import Foundation
import AppKit
import CryptoKit

struct Clip: Identifiable, Codable, Equatable {
    let id: UUID
    let content: ClipContent
    let type: ClipType
    let metadata: ClipMetadata
    let createdAt: Date
    let sourceApp: String?
    var isPinned: Bool
    var collectionId: UUID?
    let isSensitive: Bool

    init(
        id: UUID = UUID(),
        content: ClipContent,
        type: ClipType,
        metadata: ClipMetadata = ClipMetadata(),
        createdAt: Date = Date(),
        sourceApp: String? = nil,
        isPinned: Bool = false,
        collectionId: UUID? = nil,
        isSensitive: Bool = false
    ) {
        self.id = id
        self.content = content
        self.type = type
        self.metadata = metadata
        self.createdAt = createdAt
        self.sourceApp = sourceApp
        self.isPinned = isPinned
        self.collectionId = collectionId
        self.isSensitive = isSensitive
    }
}

enum ClipContent: Codable, Equatable {
    case text(String)
    case image(Data)
    case file(URL)
    case richText(Data) // NSAttributedString archived data

    var previewText: String? {
        switch self {
        case .text(let s): return s
        case .richText(let d):
            return (try? NSAttributedString(data: d, options: [.documentType: NSAttributedString.DocumentType.rtf], documentAttributes: nil))?.string
        case .image: return nil
        case .file(let url): return url.lastPathComponent
        }
    }

    // Stable hash used to dedupe re-copied clips. Hashes the *visible* text
    // (after RTF→plain decoding + whitespace trim) so styled copies of the
    // same string collapse into one row. Images and files still hash their
    // raw bytes / URL. The `V1:` prefix versions the scheme for future
    // schema bumps (see ClipStore.rehashAllIfNeeded).
    var contentHash: String {
        var hasher = SHA256()
        hasher.update(data: Data("V1:".utf8))
        switch self {
        case .text(let s):
            hasher.update(data: Data("T:".utf8))
            hasher.update(data: Data(Self.normalizeText(s).utf8))
        case .richText(let d):
            let plain = (try? NSAttributedString(
                data: d,
                options: [.documentType: NSAttributedString.DocumentType.rtf],
                documentAttributes: nil
            ))?.string ?? ""
            if plain.isEmpty {
                hasher.update(data: Data("R-blob:".utf8))
                hasher.update(data: d)
            } else {
                hasher.update(data: Data("T:".utf8))
                hasher.update(data: Data(Self.normalizeText(plain).utf8))
            }
        case .image(let d):
            hasher.update(data: Data("I:".utf8))
            hasher.update(data: d)
        case .file(let url):
            hasher.update(data: Data("F:".utf8))
            hasher.update(data: Data(url.absoluteString.utf8))
        }
        return hasher.finalize().map { String(format: "%02x", $0) }.joined()
    }

    private static func normalizeText(_ s: String) -> String {
        s.replacingOccurrences(of: "\r\n", with: "\n")
         .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

enum ClipType: String, Codable, CaseIterable {
    case url, email, phoneNumber, hexColor, rgbColor, hslColor
    case json, code, number, date, math
    case plainText, richText
    case image, file

    var displayName: String {
        switch self {
        case .url: return "Link"
        case .email: return "Email"
        case .phoneNumber: return "Phone"
        case .hexColor, .rgbColor, .hslColor: return "Color"
        case .json: return "JSON"
        case .code: return "Code"
        case .number: return "Number"
        case .date: return "Date"
        case .math: return "Math"
        case .plainText: return "Text"
        case .richText: return "Rich text"
        case .image: return "Image"
        case .file: return "File"
        }
    }

    var filterChip: FilterChip? {
        switch self {
        case .url: return .links
        case .email, .phoneNumber: return .text
        case .hexColor, .rgbColor, .hslColor: return .colors
        case .json, .code: return .code
        case .number, .date, .math, .plainText: return .text
        case .richText: return .text
        case .image: return .images
        case .file: return .files
        }
    }
}

enum FilterChip: String, CaseIterable {
    case all, text, links, images, code, colors, files

    var displayName: String { rawValue.capitalized }
}

struct ClipMetadata: Codable, Equatable {
    var characterCount: Int?
    var dimensions: CGSize?
    var fileSize: Int?
    var language: String?
    var colorSpace: String?
    var copyCount: Int?
}

struct Collection: Identifiable, Codable {
    let id: UUID
    var name: String
    var order: Int
    var createdAt: Date
}

struct Snippet: Identifiable, Codable {
    let id: UUID
    var trigger: String
    var content: String
    var expandOn: ExpansionTrigger
    var isEnabled: Bool

    enum ExpansionTrigger: String, Codable {
        case space, `return`, immediate
    }
}
