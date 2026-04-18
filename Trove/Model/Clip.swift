import Foundation
import AppKit

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
