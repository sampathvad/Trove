import SwiftUI

struct FirstRunView: View {
    let onDismiss: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Trove")
                .font(.headline)
            Text("Collecting, recalling, protecting, and reusing your clipboard.")
                .font(.body).foregroundStyle(.secondary)
            Text("Press **⌘⇧V** to open anytime.")
                .font(.body)
                .foregroundStyle(.secondary)
            Text("To paste directly into any app when you press Enter, Trove needs Accessibility access. Without it, clips are still copied — just press ⌘V yourself.")
                .font(.caption)
                .foregroundStyle(.secondary)
            Button("Continue") {
                onDismiss()
                PasteService.requestAccessibilityIfNeeded()
            }
            .keyboardShortcut(.defaultAction)
        }
        .padding(20)
        .frame(width: 280)
    }
}
