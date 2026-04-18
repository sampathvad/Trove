# Trove — Tech Stack Reference

Implementation patterns, data model, and technical decisions. Read this when writing Swift code, designing the data layer, or setting up the project.

## Project structure (recommended)

```
Trove/
├── Trove/                          # Main app target
│   ├── TroveApp.swift              # App entry point
│   ├── Capture/                    # Clipboard capture engine
│   ├── Panel/                      # Floating history panel
│   ├── Settings/                   # Settings window
│   ├── MenuBar/                    # Menu bar icon + menu
│   ├── Model/                      # Clip, Collection, Filter, Snippet models
│   ├── Persistence/                # GRDB + SQLite + FTS5
│   ├── Services/                   # Hotkey, notifications, sync
│   ├── Resources/                  # Assets, Localizable.strings
│   └── Supporting/                 # Extensions, utilities
├── TroveKit/                       # Framework with shared logic (reusable on iOS)
├── TroveTests/                     # Unit tests
├── TroveUITests/                   # Snapshot and UI tests
└── Package.swift                   # Swift Package Manager dependencies
```

## Dependencies

Prefer Swift Package Manager. Keep the dependency list small.

| Package | Purpose | Why this one |
|---------|---------|--------------|
| `GRDB.swift` | SQLite wrapper | Actively maintained, async/await native, good concurrency |
| `HotKey` or `MASShortcut` | Global hotkey | Both well-tested; pick one |
| `Sparkle` | Auto-updates (direct build) | Standard for macOS |
| `KeyboardShortcuts` (Sindre Sorhus) | Shortcut recording UI | Better UX than `MASShortcut` for user-facing rebinding |
| `Defaults` (Sindre Sorhus) | Type-safe `UserDefaults` | Cleaner than raw `UserDefaults` |

Avoid:
- Electron / React Native / anything non-native.
- Heavy reactive frameworks (RxSwift, Combine-heavy architectures). SwiftUI's built-in state is enough.
- Analytics SDKs. Don't ship them at all.

## Data model

### Core entities

```swift
struct Clip: Identifiable, Codable {
    let id: UUID
    let content: ClipContent            // .text, .image, .file, .richText
    let type: ClipType                  // .url, .color, .code, .json, .email, .number, .plainText, .richText, .image, .file
    let metadata: ClipMetadata
    let createdAt: Date
    let sourceApp: String?              // e.g., "com.apple.Safari"
    let isPinned: Bool
    let collectionId: UUID?
    let isSensitive: Bool               // auto-detected passwords, cards, tokens
}

enum ClipContent: Codable {
    case text(String)
    case image(Data)                    // stored as file reference if > threshold
    case file(URL)                      // stored as URL bookmark
    case richText(AttributedString)
}

struct ClipMetadata: Codable {
    var characterCount: Int?
    var dimensions: CGSize?             // for images
    var fileSize: Int?                  // bytes
    var language: String?               // detected code language
    var colorSpace: String?             // for color clips
}

struct Collection: Identifiable, Codable {
    let id: UUID
    var name: String
    var order: Int
    var shortcut: KeyboardShortcut?
    var createdAt: Date
}

struct Snippet: Identifiable, Codable {
    let id: UUID
    var trigger: String                 // e.g., "sig"
    var content: String
    var expandOn: ExpansionTrigger      // .space, .return, .immediate
    var isEnabled: Bool
}

struct Filter: Identifiable, Codable {
    let id: UUID
    var name: String
    var kind: FilterKind                // .builtin, .regex, .shellScript
    var definition: String
    var shortcut: KeyboardShortcut?
}
```

### SQLite schema

```sql
CREATE TABLE clips (
    id TEXT PRIMARY KEY,
    content BLOB NOT NULL,              -- JSON-encoded ClipContent
    type TEXT NOT NULL,                 -- matches ClipType enum
    metadata BLOB,                      -- JSON-encoded ClipMetadata
    created_at REAL NOT NULL,           -- unix timestamp
    source_app TEXT,
    is_pinned INTEGER NOT NULL DEFAULT 0,
    collection_id TEXT,
    is_sensitive INTEGER NOT NULL DEFAULT 0,
    FOREIGN KEY (collection_id) REFERENCES collections(id)
);

CREATE INDEX idx_clips_created_at ON clips(created_at DESC);
CREATE INDEX idx_clips_type ON clips(type);
CREATE INDEX idx_clips_pinned ON clips(is_pinned) WHERE is_pinned = 1;

-- Full-text search virtual table
CREATE VIRTUAL TABLE clips_fts USING fts5(
    id UNINDEXED,
    searchable_text,                    -- plain text extracted from content
    source_app,
    tokenize = 'porter unicode61 remove_diacritics 2'
);

-- Keep FTS in sync with main table via triggers
CREATE TRIGGER clips_ai AFTER INSERT ON clips BEGIN
    INSERT INTO clips_fts(id, searchable_text, source_app)
    VALUES (new.id, json_extract(new.content, '$.text'), new.source_app);
END;

CREATE TABLE collections (
    id TEXT PRIMARY KEY,
    name TEXT NOT NULL,
    order_index INTEGER NOT NULL,
    shortcut TEXT,
    created_at REAL NOT NULL
);

CREATE TABLE snippets (
    id TEXT PRIMARY KEY,
    trigger TEXT NOT NULL UNIQUE,
    content TEXT NOT NULL,
    expand_on TEXT NOT NULL,
    is_enabled INTEGER NOT NULL DEFAULT 1
);

CREATE TABLE filters (
    id TEXT PRIMARY KEY,
    name TEXT NOT NULL,
    kind TEXT NOT NULL,
    definition TEXT NOT NULL,
    shortcut TEXT
);
```

### Why SQLite + FTS5

- Sub-50ms search for 10,000+ clips is achievable with FTS5's `porter` tokenizer.
- WAL (write-ahead logging) mode gives crash-safe writes with concurrent reads.
- Schema migrations are straightforward with GRDB's `DatabaseMigrator`.
- Works identically on iOS for the Phase 3 companion (shared code via `TroveKit`).

### Large content handling

Don't store blobs over ~1 MB directly in the database. Write large images and files to a content-addressed blob store on disk:

```
~/Library/Containers/app.trove.Trove/Data/Library/Application Support/Trove/
├── trove.db                        # SQLite database
├── trove.db-wal
├── trove.db-shm
└── blobs/
    ├── a8/f3/a8f3d9e2...png       # content-addressed by SHA256 prefix
    └── b2/41/b241e7a9...pdf
```

The database stores the blob SHA; the blob store holds the bytes. Cleanup scans blobs with no referencing clip on app launch (debounced to avoid startup cost).

## Clipboard capture engine

### Polling approach

`NSPasteboard` doesn't have a native change notification — poll `changeCount`:

```swift
actor ClipboardMonitor {
    private var lastChangeCount = NSPasteboard.general.changeCount
    private let pollInterval: TimeInterval = 0.5  // 500ms — configurable, min 100ms

    func start() async {
        while !Task.isCancelled {
            let currentCount = NSPasteboard.general.changeCount
            if currentCount != lastChangeCount {
                lastChangeCount = currentCount
                await captureCurrentClipboard()
            }
            try? await Task.sleep(for: .milliseconds(Int(pollInterval * 1000)))
        }
    }

    private func captureCurrentClipboard() async {
        let pb = NSPasteboard.general

        // Respect transient/concealed markers
        guard !pb.types?.contains(.transient) ?? false,
              !pb.types?.contains(.concealed) ?? false else { return }

        // Skip if source app is blacklisted
        if let sourceApp = NSWorkspace.shared.frontmostApplication?.bundleIdentifier,
           await BlacklistService.shared.isBlacklisted(sourceApp) { return }

        // Extract content, detect type, persist
        let clip = await ClipExtractor.extract(from: pb)
        await ClipStore.shared.insert(clip)
    }
}
```

### Type detection

Detect content type at capture time, not render time. Store the detected type. UI reads it.

```swift
enum ClipType: String, Codable {
    case url, email, phoneNumber, hexColor, rgbColor, hslColor
    case json, code, number, date, math
    case plainText, richText
    case image, file
}

struct TypeDetector {
    static func detect(_ text: String) -> ClipType {
        if text.isURL { return .url }
        if text.isEmail { return .email }
        if text.isHexColor { return .hexColor }
        if text.isRgbColor { return .rgbColor }
        if let _ = try? JSONSerialization.jsonObject(with: Data(text.utf8)) { return .json }
        if text.isCode { return .code }  // heuristic: contains ;, {, }, fn, etc.
        if Double(text.trimmingCharacters(in: .whitespaces)) != nil { return .number }
        return .plainText
    }
}
```

### Sensitive-content detection

Run a quick regex pass on text clips at capture. If the content matches known patterns (credit cards via Luhn, API key prefixes, SSN format), mark `isSensitive = true` and either skip storage or mark the clip for auto-expiry.

## Global hotkey

Use `KeyboardShortcuts` package for recording and firing. Non-activating panel so the user's focus stays in the source app.

```swift
extension KeyboardShortcuts.Name {
    static let openPanel = Self("openPanel", default: .init(.v, modifiers: [.command, .shift]))
    static let pasteAsPlainText = Self("pasteAsPlainText", default: .init(.v, modifiers: [.command, .shift, .option]))
}

// In AppDelegate / App init:
KeyboardShortcuts.onKeyUp(for: .openPanel) {
    PanelController.shared.toggle()
}
```

## The floating panel

SwiftUI alone can't do a non-activating floating panel on macOS. Wrap `NSPanel`:

```swift
final class TrovePanel: NSPanel {
    init<Content: View>(@ViewBuilder content: () -> Content) {
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: 560, height: 480),
            styleMask: [.nonactivatingPanel, .titled, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        isFloatingPanel = true
        level = .floating
        titlebarAppearsTransparent = true
        isMovableByWindowBackground = true
        hidesOnDeactivate = true
        standardWindowButton(.miniaturizeButton)?.isHidden = true
        standardWindowButton(.zoomButton)?.isHidden = true

        contentViewController = NSHostingController(rootView: content())
    }

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}
```

## Pasting into the target app

Two reliable approaches:

1. **Simulated ⌘V.** Post `CGEvent` for key down and up with `.maskCommand`. Works everywhere but requires Accessibility permission.
2. **Programmatic paste via Accessibility API.** More reliable in some edge cases but also needs the same permission.

Request Accessibility permission only when the user first tries to paste — don't front-load it in onboarding.

```swift
import ApplicationServices

func requestAccessibilityIfNeeded() -> Bool {
    let options = [kAXTrustedCheckOptionPrompt.takeRetainedValue() as String: true] as CFDictionary
    return AXIsProcessTrustedWithOptions(options)
}
```

## Performance optimization patterns

### 100ms panel render

- **Pre-warm the window.** Create the `NSPanel` once at app launch, keep it around, just show/hide. Don't recreate on every open.
- **Lazy-load thumbnails.** Text previews render immediately. Image thumbnails load asynchronously and fade in.
- **Limit initial render.** First paint shows first ~30 clips. Scroll loads more via `LazyVStack`.
- **Index in advance.** FTS5 queries are fast, but pre-build the searchable text column during capture, not at query time.

### Idle CPU under 0.1%

- **Throttle the poller.** 500ms default. Only drop to 100ms if the user explicitly asks.
- **Suspend when screen locks.** Observe `NSWorkspace.screensDidSleepNotification` and stop polling.
- **No always-running Timers.** Use `Task` with `sleep` instead of `Timer` for cleaner cancellation.

### Idle memory under 80 MB

- **Don't keep clip content in memory.** Only load the clips currently visible in the panel.
- **Image clips use on-disk storage.** Load thumbnails from disk, not kept in an in-memory cache beyond LRU size.

## Menu bar and launch

### Launch at login (macOS 13+)

```swift
import ServiceManagement

func setLaunchAtLogin(_ enabled: Bool) throws {
    if enabled {
        try SMAppService.mainApp.register()
    } else {
        try SMAppService.mainApp.unregister()
    }
}

var isLaunchAtLoginEnabled: Bool {
    SMAppService.mainApp.status == .enabled
}
```

Never use the legacy `SMLoginItemSetEnabled` — it's deprecated and brittle.

### Menu bar icon

Use a template image (`NSImage.isTemplate = true`) so it adapts to menu bar appearance. SF Symbols work but a custom glyph for Trove's treasure-chest identity is better.

```swift
NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
    .button?.image = NSImage(named: "MenuBarIcon")  // template PNG or PDF
```

## Build configuration

### Two build targets

1. **Trove (direct download)** — non-sandboxed, supports shell-script filters, ships via GitHub Releases with Sparkle.
2. **Trove (Mac App Store)** — sandboxed, no shell-script filters, ships via App Store. Optional.

Use build configurations and compiler flags to conditionally compile:

```swift
#if APP_STORE_BUILD
// sandboxed paths, no shell script filters
#else
// direct download paths, shell script filters available
#endif
```

### Signing and notarization

- Developer ID Application certificate ($99/year Apple Developer Program).
- Hardened runtime enabled.
- Notarize every release via `xcrun notarytool submit`.
- Staple with `xcrun stapler staple`.

### CI

Use GitHub Actions with `macos-14` or newer runners.

```yaml
name: CI
on: [push, pull_request]
jobs:
  test:
    runs-on: macos-14
    steps:
      - uses: actions/checkout@v4
      - run: swiftlint
      - run: xcodebuild test -scheme Trove -destination 'platform=macOS'
```

For release builds, add a separate workflow that runs on git tags — builds the app, signs, notarizes, and creates a GitHub Release with the signed `.dmg`.

## Testing strategy

- **Unit tests** for: type detection, filters, sensitive-content detection, database queries.
- **Integration tests** for: capture engine end-to-end (with mock pasteboard), CloudKit sync (with mock container), snippet expansion.
- **Snapshot tests** for: panel view at various widths, dark/light mode, empty states, with different clip types.
- **UI tests** for: hotkey → panel open → search → paste flow. Smallest feasible set since UI tests are slow.

## SwiftLint config (recommended starting point)

```yaml
# .swiftlint.yml
disabled_rules:
  - trailing_whitespace
  - todo
opt_in_rules:
  - empty_count
  - sorted_first_last
  - contains_over_first_not_nil
  - first_where
  - closure_end_indentation
  - closure_spacing
line_length:
  warning: 140
  error: 200
type_body_length:
  warning: 300
file_length:
  warning: 500
excluded:
  - .build
  - Pods
```

## Useful pointers

- Apple's [Designing for macOS](https://developer.apple.com/design/human-interface-guidelines/designing-for-macos) HIG.
- GRDB [concurrency guide](https://github.com/groue/GRDB.swift/blob/master/Documentation/Concurrency.md).
- Sparkle [2.x documentation](https://sparkle-project.org/documentation/).
- `NSPasteboard` custom types registry at [nspasteboard.org](http://nspasteboard.org).
