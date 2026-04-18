import SwiftUI
import AppKit

struct DetailPreviewView: View {
    let clip: Clip
    let onClose: () -> Void

    @State private var isEditing = false
    @State private var editText = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            Divider()
            content
            Divider()
            metadata
        }
        .background(.regularMaterial)
    }

    private var header: some View {
        HStack {
            Image(systemName: clip.type.iconName)
                .foregroundStyle(.secondary)
            Text(clip.type.displayName)
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer()
            Button { onClose() } label: {
                Image(systemName: "xmark").font(.caption)
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    @ViewBuilder
    private var content: some View {
        switch clip.content {
        case .text(let s):
            if isEditing {
                TextEditor(text: $editText)
                    .font(.system(size: 12, design: .monospaced))
                    .padding(8)
                    .frame(maxHeight: .infinity)
                    .onAppear { editText = s }
                    .onKeyPress(.return, phases: .down) { event in
                        guard event.modifiers == .command else { return .ignored }
                        Task { await ClipStore.shared.updateContent(clip, newText: editText) }
                        isEditing = false
                        return .handled
                    }
            } else {
                ScrollView {
                    Text(s)
                        .font(.system(size: 12, design: .monospaced))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(8)
                        .textSelection(.enabled)
                }
                .frame(maxHeight: .infinity)
                .onKeyPress(.init("e"), phases: .down) { _ in
                    isEditing = true; return .handled
                }
            }

        case .richText(let data):
            if let attrStr = try? NSAttributedString(
                data: data,
                options: [.documentType: NSAttributedString.DocumentType.rtf],
                documentAttributes: nil
            ) {
                ScrollView {
                    Text(AttributedString(attrStr))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(8)
                        .textSelection(.enabled)
                }
                .frame(maxHeight: .infinity)
            }

        case .image(let data):
            if let img = NSImage(data: data) {
                ScrollView {
                    Image(nsImage: img)
                        .resizable()
                        .scaledToFit()
                        .padding(8)
                }
                .frame(maxHeight: .infinity)
            }

        case .file(let url):
            VStack(spacing: 8) {
                Image(nsImage: NSWorkspace.shared.icon(forFile: url.path))
                    .resizable()
                    .frame(width: 64, height: 64)
                Text(url.lastPathComponent)
                    .font(.headline)
                Text(url.path)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                Button("Show in Finder") { NSWorkspace.shared.selectFile(url.path, inFileViewerRootedAtPath: "") }
                    .buttonStyle(.bordered)
            }
            .padding()
            .frame(maxHeight: .infinity)
        }
    }

    private var metadata: some View {
        VStack(alignment: .leading, spacing: 4) {
            if let chars = clip.metadata.characterCount {
                metaRow("Characters", "\(chars)")
            }
            if let dims = clip.metadata.dimensions {
                metaRow("Size", "\(Int(dims.width)) × \(Int(dims.height))")
            }
            if let bytes = clip.metadata.fileSize {
                metaRow("File size", ByteCountFormatter.string(fromByteCount: Int64(bytes), countStyle: .file))
            }
            if let app = clip.sourceApp?.appDisplayName {
                metaRow("Source", app)
            }
            metaRow("Copied", clip.createdAt.formatted(date: .abbreviated, time: .shortened))

            if case .text = clip.content {
                HStack {
                    Spacer()
                    Button(isEditing ? "Cancel" : "Edit") {
                        if isEditing {
                            isEditing = false
                        } else {
                            editText = clip.content.previewText ?? ""
                            isEditing = true
                        }
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    if isEditing {
                        Button("Save") {
                            Task { await ClipStore.shared.updateContent(clip, newText: editText) }
                            isEditing = false
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.small)
                    }
                }
            }
        }
        .padding(8)
    }

    private func metaRow(_ label: String, _ value: String) -> some View {
        HStack(alignment: .top) {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(width: 80, alignment: .leading)
            Text(value)
                .font(.caption)
                .foregroundStyle(.primary)
        }
    }
}
