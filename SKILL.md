---
name: trove
description: Guidance for building Trove, a free and open-source macOS clipboard manager by Sampath. Use this skill whenever the user mentions Trove, asks for help implementing features on the clipboard manager, writes SwiftUI or AppKit code for it, drafts README/documentation/website/launch copy for the project, makes architecture decisions, or prioritizes roadmap items. Also use it for any task related to building a keyboard-first Mac utility, menu bar app, or clipboard history tool — the patterns here apply broadly. Consult this skill even for small Trove-related tasks (picking a keyboard shortcut, wording a setting label, choosing an accent color, naming a file) to keep decisions consistent across sessions.
---

# Trove

Trove is a free, open-source clipboard manager for macOS built by Sampath. Tagline: **Every copy, kept.** License: MIT (recommended). Platform: macOS 13+.

This skill encodes the project's principles, roadmap, tech choices, and patterns so every Claude session working on Trove makes consistent decisions. For the full product requirements document, read `references/feature-spec.md`. For Swift/SwiftUI implementation patterns, read `references/tech-stack.md`.

## When to consult reference files

Read `references/feature-spec.md` when:
- The user asks about a specific feature (F-01 through F-32) and needs acceptance criteria.
- You need the exact settings architecture (12 sections, S-01 through S-12).
- You're drafting the GitHub README, website copy, or launch post — the positioning table and sustainability section live there.
- The user asks about distribution, licensing, or launch checklist.

Read `references/tech-stack.md` when:
- Writing Swift, SwiftUI, or AppKit code for the app.
- Designing the data model or persistence layer.
- Making performance trade-offs (the 100ms panel render target is non-trivial).
- Setting up the project, build configuration, or CI.

## Core principles (never compromise these)

These eight principles govern every design and implementation decision. When a trade-off arises, pick the option that honors more of these.

1. **Keyboard-first.** Every action has a shortcut. The mouse is optional, never required. A feature that can't be driven from the keyboard needs a keyboard alternative before it ships.
2. **Appear instantly.** The history panel must render in under 100ms from hotkey press to first paint. This is the single most important perceived-quality metric. Slow panels break the product.
3. **Get out of the way.** No signup, no onboarding tour, no account. First-run shows one small popover ("Trove remembers what you copy. Press ⌘⇧V to find it.") and that's it.
4. **Sensible defaults.** 90% of users will never open Settings. Design for that person. Every new setting is a maintenance cost — earn each one.
5. **Privacy-first.** Local storage by default. Sync, AI, and telemetry are all opt-in. No network calls happen unless the user explicitly enables them.
6. **Native feel.** SwiftUI + AppKit bridges. SF Pro, SF Symbols, system materials, full dark mode. Never Electron. Mac users can tell.
7. **Free forever.** No paid tiers. No feature gates. No "Pro" upsell. If monetization becomes necessary, it's via optional donations or an optional paid Mac App Store listing with identical features.
8. **Open source.** Source code is public so privacy claims are auditable. Community contributions welcome.

## Identity and voice

- **Name:** Trove (from "treasure trove").
- **Pronunciation:** /trəʊv/ — rhymes with "grove."
- **Author:** Sampath.
- **Tagline (primary):** *Every copy, kept.*
- **Icon direction:** Stylized treasure-chest glyph, a geometric gem, or a simple keyhole. Works at 16px in the menu bar. Avoid literal paperclip or scissors imagery — too generic.
- **Palette:** Warm amber accent (`#D89A2A`) on neutral backgrounds. Works in light and dark mode.
- **Voice:** Quiet, confident, helpful. Not cute. Not corporate. Short sentences. Plain English. No hype words like "revolutionary" or "supercharge."

## Roadmap at a glance

| Phase | Features | Duration | Goal |
|-------|----------|----------|------|
| MVP (Phase 1) | F-01 to F-15 | 8–12 weeks | Useful on day one |
| Differentiators (Phase 2) | F-16 to F-25 | 8 weeks | Best-in-class free option |
| Advanced (Phase 3) | F-26 to F-32 | 12 weeks | Multi-device, AI-aware, community-powered |

**Phase 1 is the critical risk.** Everything depends on shipping a responsive MVP. Cut features from MVP before cutting quality or performance.

**All phases are free.** Phase 3 features (iCloud sync, iOS companion, AI) are not behind a paywall. AI is bring-your-own-key so Trove never pays for or proxies inference.

## Tech stack (defaults)

Use these unless the user explicitly asks for alternatives. They are chosen to honor the core principles.

- **UI:** SwiftUI with AppKit bridges for menu-bar, panel windows, and global-hotkey handling.
- **Persistence:** SQLite with FTS5 for full-text search. SQLCipher for encryption-at-rest (Phase 3). Prefer GRDB.swift as the SQLite wrapper — modern, actively maintained, good concurrency model.
- **Launch at login:** `SMAppService` (macOS 13+ API). Never the legacy `SMLoginItemSetEnabled`.
- **Sync:** CloudKit private database (no server infrastructure). End-to-end encrypted natively.
- **Hotkey handling:** `MASShortcut` or `HotKey` (Swift package). Implement conflict detection with the system shortcut registry.
- **Distribution:** Sparkle framework for auto-updates on direct-download build. Two builds: sandboxed (App Store, no shell-script filters) and non-sandboxed (direct download).
- **Minimum macOS:** 13 Ventura. Apple Silicon and Intel universal binary.

## Standard keyboard shortcuts (conventions to preserve)

These shortcuts are the contract with the user. Don't change them without a strong reason.

| Shortcut | Action |
|----------|--------|
| ⌘⇧V | Open history panel (global, rebindable) |
| ↵ | Paste selected clip |
| ⌘⇧↵ | Paste as plain text |
| Esc | Dismiss panel (or clear search first) |
| ↑ / ↓ | Navigate clips |
| Space | Toggle detail preview |
| → | Open detail preview |
| ← | Close detail preview |
| ⌘P | Pin / unpin selected clip |
| ⌘⌫ | Delete selected clip |
| ⌘Z | Undo delete (when panel is open) |
| ⌘1–9 | Quick-paste the first nine visible clips |
| ⌘K | Focus search field |
| ⌘, | Open settings |

## Non-negotiable performance targets

If code threatens these numbers, fix the code — don't lower the bar.

- Panel render: p95 under 100ms from hotkey `keyDown` to first paint.
- Paste: p95 under 200ms from `↵` to content appearing in target app.
- Search: under 50ms per keystroke for histories up to 10,000 clips.
- Idle memory: under 80 MB with 500 clips.
- Idle CPU: under 0.1% when panel is closed.
- Crash-free rate: above 99.5%.

## UX patterns to follow

- **Content type detection happens at capture time,** not at render time. The clip record stores its type. The UI just reads it.
- **The panel is keyboard-driven first.** Mouse works, but design for the user who has their hands on the keys.
- **Clip rows show: type icon + preview + source/time + shortcut number.** In that order, left to right. Don't redesign this — it's the scannable pattern.
- **Pinned clips sit in their own section at the top.** Then "Today," "Yesterday," older.
- **Filter chips are: All, Text, Links, Images, Code, Colors, Files.** Consistent across the app.
- **Settings save on change** — no Apply button. Mac convention.
- **Dangerous actions need a confirmation step** (clear all history, reset settings, delete a collection).
- **Errors are inline and reversible.** Toast with Undo for delete. Banner warning for actions with consequences.
- **First-run = one popover near the menu bar.** That's the entire onboarding.

## Anti-patterns (never do these)

- **Don't use Electron or any cross-platform UI framework.** Native SwiftUI only.
- **Don't add a setting for something you can detect.** If you can identify passwords from clipboard patterns, skip them automatically — don't make the user configure it.
- **Don't put anything in a modal that could be inline.** Modals break flow.
- **Don't require a restart for any setting change.** Ever.
- **Don't ship telemetry on by default.** Opt-in only, anonymous only.
- **Don't proxy user data through Trove's servers** (there are no Trove servers — CloudKit direct, chosen AI provider direct).
- **Don't add tabs inside a settings pane.** If a section has enough content for tabs, it's two sections.
- **Don't use position: fixed / modal UI during streaming renders** (not applicable to native, but keep in mind when writing web-based docs or demos).
- **Don't ship 40 theme options.** Three panel sizes (compact/comfortable/spacious) and auto/light/dark is enough.
- **Don't leak implementation terminology into user-facing copy.** "CoreData cache TTL" is not a setting. "Keep clips for" is.
- **Don't bury the kill switch.** Pause/resume must be in the menu bar icon, not three levels deep in settings.
- **Don't add a "Pro" tier.** Ever. The promise is free forever.
- **Don't add ads or track users.** Period.

## When generating code

- Prefer Swift + SwiftUI with AppKit bridges. Use `NSWindow` + `NSPanel` only when SwiftUI can't handle the window behavior natively (floating panel, non-activating hotkey window).
- Use `@Observable` (iOS 17+ / macOS 14+ macro) for view models when the minimum OS allows. Otherwise `ObservableObject`.
- Write async code with Swift structured concurrency (`async`/`await`, `Task`, `TaskGroup`). Avoid callbacks and `DispatchQueue` unless bridging an older API.
- Keep capture logic off the main thread. Use a dedicated `actor` or background `Task` for clipboard polling.
- Use `SwiftLint` with the default + a few custom rules. See `references/tech-stack.md` for the recommended config.
- Write tests. Snapshot tests for views, unit tests for clip detection and filters, integration tests for the capture engine.

## When writing user-facing copy

- Tone: quiet, confident, helpful.
- Sentence case, never Title Case.
- No emoji in the app UI. Emoji in README / website is fine but sparing.
- Error messages describe what happened and what to do next. Never blame the user.
- Button labels are verbs: "Add app," "Clear history," "Pin clip" — not "OK" or "Submit."
- Setting descriptions are one short line of plain English.

## When drafting marketing / GitHub content

- Lead with the principle that matters most to the audience: developers (open source, privacy, performance), writers (speed, templates, smart actions), designers (smart actions for colors and images).
- Show, don't tell. GIFs of the panel appearing, a color being converted, code being formatted — worth more than paragraphs of feature lists.
- The origin story is the hook: "I built Trove because Pastebot is stale and Paste is expensive. Free, native, fast. Source on GitHub."
- Positioning table lives in `references/feature-spec.md` — use it for comparison content.

## Decision log (add to this as the project evolves)

Record major decisions here so they're recoverable in future sessions.

- **2026-04-18** — Name chosen: Trove (over Magpie due to GitHub/SEO noise, over Path due to genericity).
- **2026-04-18** — License: MIT (recommended, pending user confirmation).
- **2026-04-18** — Monetization: Free forever. GitHub Sponsors + optional paid MAS listing as voluntary support.
- **2026-04-18** — AI strategy: bring-your-own-key only. Trove never proxies or charges for AI.

## If the user is starting a new session

Ask whether they want to:
1. Scaffold the project (Xcode project, package structure, dependencies).
2. Implement a specific feature (ask which F-number).
3. Write documentation (README, website copy, launch post).
4. Design a specific UI (panel, settings, onboarding).
5. Make an architecture decision (data model, sync, performance).

Then read the relevant reference file before diving in.
