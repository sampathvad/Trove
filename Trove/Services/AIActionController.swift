import Foundation
import SwiftUI

/// Drives a single AI action for the panel: resolves the configured provider,
/// runs the action on a clip's text, and publishes the running/result/failure
/// phase for `AIActionOverlay` to render. One action runs at a time — starting
/// a new one cancels any in flight.
@MainActor
final class AIActionController: ObservableObject {
    enum Phase: Equatable {
        case running(AIAction)
        case result(AIAction, String)
        case failure(AIAction, String)

        var action: AIAction {
            switch self {
            case .running(let a), .result(let a, _), .failure(let a, _): return a
            }
        }
    }

    @Published private(set) var phase: Phase?
    /// Name of the provider handling the active request, for the overlay's
    /// "Asking <provider>…" line.
    @Published private(set) var providerName = ""

    private var task: Task<Void, Never>?

    var isActive: Bool { phase != nil }

    func run(_ action: AIAction, on clip: Clip) {
        guard let text = clip.content.previewText, !text.isEmpty else { return }
        let provider = Self.currentProvider()
        providerName = provider.name
        phase = .running(action)
        task?.cancel()
        task = Task { [weak self] in
            do {
                let output = try await provider.transform(prompt: action.prompt(for: text), content: text)
                guard let self, !Task.isCancelled else { return }
                self.phase = .result(action, output)
            } catch is CancellationError {
                return
            } catch {
                guard let self, !Task.isCancelled else { return }
                let message = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
                self.phase = .failure(action, message)
            }
        }
    }

    func dismiss() {
        task?.cancel()
        task = nil
        phase = nil
    }

    /// Maps the `aiProvider` setting to a live provider (keys from Keychain).
    static func currentProvider() -> AIProvider {
        switch TroveSettings.aiProvider {
        case "anthropic": return AnthropicProvider()
        case "ollama":    return OllamaProvider()
        default:          return OpenAIProvider()
        }
    }
}
