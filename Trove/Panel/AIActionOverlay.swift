import SwiftUI
import AppKit

/// Bottom card in the panel that shows an AI action's progress, result, or
/// error. Presented while `controller.isActive`.
struct AIActionOverlay: View {
    @ObservedObject var controller: AIActionController
    /// Paste the given text into the frontmost app (closes the panel).
    var onPaste: (String) -> Void

    @State private var didCopy = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            header
            Divider()
            content
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(.separator, lineWidth: 0.5))
        .shadow(radius: 10, y: 2)
        .padding(12)
    }

    private var header: some View {
        HStack(spacing: 8) {
            Image(systemName: "sparkles").foregroundStyle(.tint)
            Text(controller.phase?.action.rawValue ?? "AI")
                .font(.headline)
            Spacer()
            Button { controller.dismiss() } label: {
                Image(systemName: "xmark").font(.caption.weight(.semibold))
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private var content: some View {
        switch controller.phase {
        case .running:
            HStack(spacing: 8) {
                ProgressView().controlSize(.small)
                Text("Asking \(controller.providerName)…")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
            .padding(.vertical, 4)

        case .result(_, let output):
            ScrollView {
                Text(output)
                    .font(.system(size: 12))
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(maxHeight: 200)

            HStack(spacing: 8) {
                Button {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(output, forType: .string)
                    didCopy = true
                } label: {
                    Label(didCopy ? "Copied" : "Copy", systemImage: didCopy ? "checkmark" : "doc.on.doc")
                }
                .buttonStyle(.bordered)
                .controlSize(.small)

                Button {
                    onPaste(output)
                } label: {
                    Label("Paste", systemImage: "arrow.down.doc")
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)

                Spacer()
            }

        case .failure(_, let message):
            HStack(alignment: .top, spacing: 8) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(.orange)
                Text(message)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

        case nil:
            EmptyView()
        }
    }
}
