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
            Button("Got it") { onDismiss() }
                .keyboardShortcut(.defaultAction)
        }
        .padding(20)
        .frame(width: 260)
    }
}
