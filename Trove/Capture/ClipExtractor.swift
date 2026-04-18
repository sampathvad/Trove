import AppKit
import Foundation

struct ClipExtractor {
    static func extract(from pb: NSPasteboard, sourceApp: String?) -> Clip {
        // Images
        if let image = NSImage(pasteboard: pb), let data = image.tiffRepresentation {
            return Clip(
                content: .image(data),
                type: .image,
                metadata: imageMetadata(for: image),
                sourceApp: sourceApp
            )
        }

        // Files
        if let urls = pb.readObjects(forClasses: [NSURL.self], options: [.urlReadingFileURLsOnly: true]) as? [URL],
           let url = urls.first {
            return Clip(
                content: .file(url),
                type: .file,
                metadata: fileMetadata(for: url),
                sourceApp: sourceApp
            )
        }

        // Rich text
        if let rtfData = pb.data(forType: .rtf) {
            let plainText = (try? NSAttributedString(
                data: rtfData,
                options: [.documentType: NSAttributedString.DocumentType.rtf],
                documentAttributes: nil
            ))?.string ?? ""
            let sensitive = SensitiveContentDetector.isSensitive(plainText)
            return Clip(
                content: .richText(rtfData),
                type: .richText,
                metadata: ClipMetadata(characterCount: plainText.count),
                sourceApp: sourceApp,
                isSensitive: sensitive
            )
        }

        // Plain text (most common)
        if let text = pb.string(forType: .string) {
            let detectedType = TypeDetector.detect(text)
            let sensitive = SensitiveContentDetector.isSensitive(text)
            return Clip(
                content: .text(text),
                type: detectedType,
                metadata: ClipMetadata(characterCount: text.count),
                sourceApp: sourceApp,
                isSensitive: sensitive
            )
        }

        // Fallback: empty text clip
        return Clip(content: .text(""), type: .plainText, sourceApp: sourceApp)
    }

    private static func imageMetadata(for image: NSImage) -> ClipMetadata {
        ClipMetadata(dimensions: image.size)
    }

    private static func fileMetadata(for url: URL) -> ClipMetadata {
        let size = (try? url.resourceValues(forKeys: [.fileSizeKey]))?.fileSize
        return ClipMetadata(fileSize: size)
    }
}
