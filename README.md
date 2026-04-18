# Trove — Every copy, kept.

Trove is a free, open-source macOS clipboard manager. It silently captures everything you copy and gives you instant access to your full history via a lightweight floating panel (⌘⇧V). Search, filter, pin, and paste — all keyboard-driven, all local.

## Download

Head to [**Releases**](../../releases/latest) and download **Trove.dmg**.

## Install

1. Open `Trove.dmg`
2. Drag **Trove.app** to your **Applications** folder
3. Launch Trove from Applications

> **Gatekeeper notice:** Because Trove is not yet notarized, macOS will block the first launch.
> Right-click **Trove.app** → **Open** → **Open** to allow it (one-time only).
>
> Or via Terminal:
> ```bash
> xattr -dr com.apple.quarantine /Applications/Trove.app
> ```

## Features

- Captures every copy automatically in the background
- Instant floating panel with ⌘⇧V (rebindable)
- Full-text search across your entire history
- Filter by type: Text, Links, Images, Code, Colors, Files
- Pin important clips, organize into Collections
- Text expansion Snippets
- Optional AI actions (bring your own OpenAI key)
- 100% local storage — no account, no cloud required

## Requirements

- macOS 13 Ventura or later
- Apple Silicon or Intel Mac

## Build from Source

```bash
# Install XcodeGen if needed
brew install xcodegen

# Generate Xcode project
xcodegen generate

# Open in Xcode and run
open Trove.xcodeproj
```

Requires Xcode 15+.

## License

MIT — see [LICENSE](LICENSE).
