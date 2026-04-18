import SwiftUI
import AppKit

struct ClipRow: View {
    let clip: Clip
    let index: Int?
    var isSelected: Bool = false
    var isMultiSelected: Bool = false
    var searchText: String = ""
    @State private var isHovered = false

    var body: some View {
        HStack(spacing: 10) {
            typeIcon
            preview
            Spacer()
            trailing
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(rowBackground)
        .onHover { isHovered = $0 }
        .contextMenu { contextMenu }
    }

    private var rowBackground: some View {
        Group {
            if isSelected {
                Color.accentColor.opacity(0.12)
            } else if isMultiSelected {
                Color.accentColor.opacity(0.08)
            } else if isHovered {
                Color.primary.opacity(0.05)
            } else {
                Color.clear
            }
        }
    }

    private var typeIcon: some View {
        ZStack {
            if clip.type == .hexColor || clip.type == .rgbColor || clip.type == .hslColor,
               let color = clip.parsedColor {
                RoundedRectangle(cornerRadius: 4)
                    .fill(color)
                    .frame(width: 20, height: 20)
            } else {
                Image(systemName: clip.type.iconName)
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
                    .frame(width: 20)
            }
        }
    }

    private var preview: some View {
        VStack(alignment: .leading, spacing: 2) {
            highlightedPreview
            HStack(spacing: 6) {
                if let app = clip.sourceApp?.appDisplayName {
                    Text(app)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Text(clip.createdAt.relativeFormatted)
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
        }
    }

    @ViewBuilder
    private var highlightedPreview: some View {
        let text = clip.content.previewText ?? clip.type.displayName
        if searchText.isEmpty {
            Text(text).lineLimit(2).font(.system(size: 13)).foregroundStyle(.primary)
        } else {
            Text(attributedPreview(text: text, query: searchText))
                .lineLimit(2).font(.system(size: 13))
        }
    }

    private func attributedPreview(text: String, query: String) -> AttributedString {
        var attributed = AttributedString(text)
        let lower = text.lowercased()
        let q = query.lowercased()
        var searchStart = lower.startIndex
        while let range = lower.range(of: q, range: searchStart..<lower.endIndex) {
            let start = AttributedString.Index(range.lowerBound, within: attributed)
            let end = AttributedString.Index(range.upperBound, within: attributed)
            if let s = start, let e = end {
                attributed[s..<e].font = .system(size: 13, weight: .bold)
                attributed[s..<e].foregroundColor = .primary
            }
            searchStart = range.upperBound
        }
        return attributed
    }

    private var trailing: some View {
        HStack(spacing: 6) {
            if clip.isPinned {
                Image(systemName: "pin.fill")
                    .font(.caption)
                    .foregroundStyle(Color.accentColor)
            }
            if let idx = index, idx <= 9 {
                Text("⌘\(idx)")
                    .font(.caption2)
                    .foregroundStyle(.quaternary)
                    .monospacedDigit()
            }
        }
    }

    @ViewBuilder
    private var contextMenu: some View {
        Button("Paste") {
            PanelController.shared.closeAndPaste(clip)
        }
        Button("Paste as plain text") {
            PanelController.shared.closeAndPaste(clip, asPlainText: true)
        }
        Divider()
        Button(clip.isPinned ? "Unpin" : "Pin") {
            Task { await ClipStore.shared.togglePin(clip) }
        }

        // Smart actions by type
        if clip.type == .url, let url = URL(string: clip.content.previewText ?? "") {
            Divider()
            Button("Open in browser") { NSWorkspace.shared.open(url) }
            Button("Copy as Markdown") {
                let md = "[\(url.host ?? url.absoluteString)](\(url.absoluteString))"
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(md, forType: .string)
            }
        }

        if clip.type == .json {
            Divider()
            Button("Pretty-print JSON") { applyFilter(.jsonPretty) }
            Button("Minify JSON") { applyFilter(.jsonMinify) }
        }

        if clip.type == .image {
            Divider()
            Button("Extract text (OCR)") { performOCR() }
            Button("Save as file…") { saveImage() }
            Button("Copy as Base64") { copyBase64() }
        }

        Divider()
        Button("Delete", role: .destructive) {
            _ = ClipStore.shared.softDelete(clip)
        }
    }

    private func applyFilter(_ kind: BuiltinFilter) {
        guard let text = clip.content.previewText else { return }
        let result = FilterEngine.applyBuiltin(kind, to: text)
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(result, forType: .string)
    }

    private func performOCR() {
        guard case .image(let data) = clip.content,
              let image = NSImage(data: data) else { return }
        Task {
            if let text = await ImageOCR.extract(from: image) {
                await MainActor.run {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(text, forType: .string)
                }
            }
        }
    }

    private func saveImage() {
        guard case .image(let data) = clip.content else { return }
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.png, .jpeg]
        panel.nameFieldStringValue = "clip.png"
        if panel.runModal() == .OK, let url = panel.url {
            try? data.write(to: url)
        }
    }

    private func copyBase64() {
        guard case .image(let data) = clip.content else { return }
        let b64 = "data:image/png;base64,\(data.base64EncodedString())"
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(b64, forType: .string)
    }
}

extension Clip {
    var parsedColor: Color? {
        guard let text = content.previewText else { return nil }
        return NSColor.parse(text).map { Color($0) }
    }
}

extension ClipType {
    var iconName: String {
        switch self {
        case .url: return "link"
        case .email: return "envelope"
        case .phoneNumber: return "phone"
        case .hexColor, .rgbColor, .hslColor: return "paintpalette"
        case .json: return "curlybraces"
        case .code: return "chevron.left.forwardslash.chevron.right"
        case .number: return "number"
        case .date: return "calendar"
        case .math: return "function"
        case .plainText: return "doc.text"
        case .richText: return "doc.richtext"
        case .image: return "photo"
        case .file: return "doc"
        }
    }
}

extension String {
    var appDisplayName: String? {
        NSWorkspace.shared.urlForApplication(withBundleIdentifier: self)
            .map { $0.deletingPathExtension().lastPathComponent }
    }
}

extension Date {
    var relativeFormatted: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: self, relativeTo: Date())
    }
}
