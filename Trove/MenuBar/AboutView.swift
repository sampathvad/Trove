import SwiftUI

struct AboutView: View {
    var body: some View {
        VStack(spacing: 0) {
            // Header
            VStack(spacing: 12) {
                Group {
                    if let img = Bundle.main.image(forResource: "TroveLogo") {
                        Image(nsImage: img)
                            .renderingMode(.template)
                            .resizable()
                            .scaledToFit()
                            .foregroundStyle(.primary)
                    } else {
                        Image(nsImage: NSApp.applicationIconImage)
                            .resizable()
                            .scaledToFit()
                    }
                }
                .frame(width: 80, height: 80)

                Text("Trove")
                    .font(.system(size: 28, weight: .bold, design: .rounded))

                Text("Collecting, recalling, protecting, and reusing.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                Text("Version 0.1.0")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            .padding(.vertical, 28)
            .frame(maxWidth: .infinity)
            .background(Color.primary.opacity(0.03))

            Divider()

            // Description
            VStack(alignment: .leading, spacing: 16) {
                descSection("What is Trove?",
                    "Trove is a free, open-source clipboard manager for macOS. Every time you copy something — text, a link, an image, a color — Trove quietly keeps it. Summon your history anytime with ⌘⇧V.")

                descSection("Features",
                    "• Full clipboard history with instant search\n• Smart content detection (URLs, colors, code, JSON)\n• Sensitive content protection (passwords, API keys)\n• Pin important clips so they never disappear\n• Paste any clip with ⌘1 – ⌘9\n• Built-in text filters (UPPERCASE, Base64, JSON…)\n• Snippet expansion with custom triggers\n• AI actions with your own API key")

                descSection("Privacy",
                    "Everything stays on your Mac. No accounts, no servers, no telemetry. Sensitive content is detected and blocked automatically. Source code is public — you can verify every claim.")
            }
            .padding(24)

            Divider()

            // Footer
            HStack {
                Text("Built by Sampath Vadlapudi · MIT License")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Button("View on GitHub") {
                    NSWorkspace.shared.open(URL(string: "https://github.com")!)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 14)
        }
        .frame(width: 420)
    }

    private func descSection(_ title: String, _ body: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.headline)
            Text(body)
                .font(.callout)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        var rgb: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&rgb)
        self.init(
            red:   Double((rgb >> 16) & 0xFF) / 255,
            green: Double((rgb >> 8)  & 0xFF) / 255,
            blue:  Double( rgb        & 0xFF) / 255
        )
    }
}
