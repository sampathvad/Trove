import Foundation
import os

/// Central `os.Logger` categories, so failures land in Console/`log stream`
/// with a subsystem filter instead of a bare `print()` that vanishes in a
/// shipped build. Usage: `Log.store.error("Insert failed: \(error)")`.
enum Log {
    private static let subsystem = Bundle.main.bundleIdentifier ?? "app.trove.Trove"

    static let store = Logger(subsystem: subsystem, category: "store")
    static let hotkeys = Logger(subsystem: subsystem, category: "hotkeys")
}
