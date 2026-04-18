# Trove — Feature Specification

> **Product name:** Trove
> **Tagline:** Every copy, kept.
> **Platform:** macOS 13 Ventura or later (universal binary for Apple Silicon + Intel)
> **Companion:** iOS/iPadOS 17+ (Phase 3)
> **License:** Free forever. Recommended: open source (MIT or Apache 2.0).
> **Author:** Sampath
> **Version:** 1.0 spec, drafted 2026-04-18

---

## 1. Vision

Trove is a Mac clipboard manager that disappears into the workflow. Press one hotkey and the clip you need is right there — searchable, pinned, already in the right format. Native feel, privacy-first, fast enough to be invisible, and free for everyone.

The name comes from "treasure trove" — a collection of valuable things kept together. Every copy a user makes is worth keeping, and Trove keeps it.

## 2. Target users

- **Primary:** Writers, designers, developers, and knowledge workers on macOS who copy-paste dozens of times per hour.
- **Secondary:** Customer support staff, researchers, students, and anyone who reuses text snippets, links, or media across apps.
- **Tertiary:** Privacy-conscious users who want a clipboard manager that provably stays local.

## 3. Positioning

| | Trove | Maccy | Pastebot | Paste |
|---|---|---|---|---|
| Price | Free forever | Free | $12.99 one-time | $29.99/year |
| Open source | Yes | Yes | No | No |
| iOS companion | Yes (Phase 3) | No | No | Yes |
| Smart actions | Yes | No | Limited | Some |
| AI features | Optional, BYOK | No | No | Yes |
| Modern UI | Yes | Minimal | Dated | Yes |
| Sync | iCloud (Phase 3) | No | iCloud | iCloud |

Trove's pitch: **everything Paste does, but free, open source, and respectful of your machine**.

## 4. Core principles

1. **Keyboard-first.** Every action has a shortcut. Mouse is optional.
2. **Appear instantly.** Panel renders in under 100ms.
3. **Get out of the way.** No signup. No onboarding tour. No account required.
4. **Sensible defaults.** 90% of users never touch settings.
5. **Privacy-first.** Local storage by default. Explicit opt-in for sync and AI.
6. **Native feel.** SwiftUI, SF Pro, SF Symbols, macOS materials, full dark mode.
7. **Free forever.** No paid tiers. No feature gates. No "Pro" upsell inside the app.
8. **Open source.** Source code is public so users can verify privacy claims and contribute.

## 5. Brand identity

**Name:** Trove
**Pronunciation:** /trəʊv/ — rhymes with "grove" and "drove."
**Tagline options:**
- *"Every copy, kept."* (primary — short, clear)
- *"Your clipboard, your trove."*
- *"A treasure of clips, always at hand."*

**Icon direction:** A stylized treasure-chest glyph, a geometric gem, or a simple keyhole — something that reads clearly at 16px in the menu bar. Avoid literal paperclip or scissors imagery; those are the same as every other clipboard app.

**Palette suggestion:** Warm amber accent (#D89A2A) on neutral backgrounds. Amber evokes gold/treasure without being gaudy. Works well in both light and dark mode.

**Voice and tone:** Quiet, confident, helpful. Not cute, not corporate. Speaks in short sentences. Uses plain English, no hype words like "revolutionary" or "supercharge."

---

## 6. MVP — Phase 1 (target: 8–12 weeks)

The smallest product that is useful on day one and better than the free alternatives.

### F-01 — Clipboard capture engine
**Description:** Monitor the system pasteboard and persist every copy event as a structured clip record.

**Acceptance criteria:**
- Captures text, rich text, images, files, URLs, and colors (hex/rgb strings).
- Skips clips that the source app marks as transient (`org.nspasteboard.TransientType`, `org.nspasteboard.ConcealedType`).
- Stores clips in a local SQLite + FTS5 database.
- File clips store a reference + metadata, not the file bytes.
- Captures happen in a background thread; UI is never blocked.

### F-02 — History panel
**Description:** The floating window that shows clipboard history. Summoned by global hotkey, dismissed by Escape or clicking away.

**Acceptance criteria:**
- Renders in under 100ms after hotkey press (measured from keyDown to first paint).
- Shows clips in reverse chronological order with a "Pinned" section at the top.
- Each row shows: type icon, content preview (1–2 lines), source app + relative time, quick-paste shortcut (⌘1–9 for first nine).
- Selected row is visually distinguished with a subtle accent background.
- Panel position is configurable: under cursor, center of screen, or last position.

### F-03 — Global hotkey
**Description:** System-wide keyboard shortcut to summon the panel from any app.

**Acceptance criteria:**
- Default is ⌘⇧V. Rebindable in Settings.
- Detects conflicts with system shortcuts and warns the user.
- Works in full-screen apps and Split View.
- Accessibility permission requested with clear justification text.

### F-04 — Keyboard navigation
**Description:** Full keyboard control of the panel with no mouse required.

**Acceptance criteria:**
- Arrow keys move selection; ↵ pastes selected clip; Esc dismisses panel.
- ⌘⇧↵ pastes as plain text.
- Space toggles detail preview of selected clip.
- ⌘P pins/unpins selected clip.
- ⌘⌫ deletes selected clip (with undo toast).
- ⌘1 through ⌘9 paste the first nine visible clips directly without navigation.

### F-05 — Fuzzy search
**Description:** Filter the clipboard history by typing, starting from an empty state.

**Acceptance criteria:**
- Searches across clip content and metadata (source app, type).
- Results update within 50ms of each keystroke for histories up to 10,000 clips.
- Matches highlighted inline in results.
- Supports filter chips: All, Text, Links, Images, Code, Colors, Files.
- Pressing Escape with search active clears the search; pressing Escape again dismisses the panel.

### F-06 — Content type detection
**Description:** Automatically classify each clip so the UI can treat it appropriately.

**Acceptance criteria:**
- Detects: URL, email, phone number, hex color, rgb/hsl color, JSON, code (with language guess), number, date, plain text, rich text, image, file reference.
- Detection runs during capture, not at render time.
- Type is stored with the clip and used for filter chips, icons, and type-aware actions (Phase 2).

### F-07 — Pin clips
**Description:** Mark clips as pinned so they survive history limits and sort to the top.

**Acceptance criteria:**
- Pinned clips are never auto-deleted when the history limit is reached.
- Pinned section appears above "Today" / "Yesterday" / older groups.
- Pin icon is visible on pinned rows.
- Per-pin keyboard shortcuts can be assigned (Phase 2).

### F-08 — Pause and resume
**Description:** Quickly stop capture without quitting the app.

**Acceptance criteria:**
- Accessible from menu bar icon (single right-click or option-click).
- When paused, menu bar icon shows a visual paused state.
- Auto-resumes after a configurable interval (default: until manually resumed).

### F-09 — Smart blacklist (privacy)
**Description:** Skip capture from apps known to handle sensitive data.

**Acceptance criteria:**
- Pre-populated with: 1Password, Bitwarden, Dashlane, LastPass, Keychain Access, common banking apps.
- Users can add any app via a picker in Settings.
- Respects the system transient/concealed pasteboard types automatically regardless of app.
- Detects credit card numbers, SSNs, and API-key patterns and skips them even from non-blacklisted apps.

### F-10 — Menu bar app
**Description:** Primary touchpoint for users who aren't using the hotkey.

**Acceptance criteria:**
- Menu bar icon with clear, high-contrast glyph that works in both menu bar styles.
- Left-click opens the panel anchored to the menu bar.
- Right-click shows: Pause, Settings, Clear history, Quit.
- Option-click opens the app's main window (if applicable).
- Icon can be hidden via Settings → General (but dock icon must then stay visible).

### F-11 — Launch at login
**Description:** Standard macOS auto-start behavior.

**Acceptance criteria:**
- Uses `SMAppService` (modern API, macOS 13+).
- Enabled by default on first launch, with a clear prompt the user can decline.
- Toggleable in Settings → General.

### F-12 — Native dark and light mode
**Description:** Fully respect the system appearance.

**Acceptance criteria:**
- All colors from semantic color tokens, never hardcoded.
- Follows system accent color.
- Respects Reduce Motion (disables non-essential animations).
- Respects Increase Contrast (thicker borders, stronger separators).

### F-13 — Settings window (basic)
**Description:** Minimal settings with only the sections needed for MVP.

**Acceptance criteria:**
- Modern macOS 13+ split-view layout.
- Sections: General, Clipboard, Hotkeys, Appearance, Privacy.
- Changes save immediately (no Apply button).
- Search field for finding settings by name.

### F-14 — First-run experience
**Description:** Get users to their first successful paste in under 30 seconds.

**Acceptance criteria:**
- On first launch, show a single small popover near the menu bar: "Trove remembers what you copy. Press ⌘⇧V to find it."
- Request Accessibility permission only when the user first tries to use the hotkey.
- No sign-up, no email capture, no tour.

### F-15 — Undo delete
**Description:** Protect against accidental clip deletion.

**Acceptance criteria:**
- Deleted clips show a toast with an Undo button for 5 seconds.
- ⌘Z while the panel is open also undoes the last deletion.

---

## 7. Phase 2 — Differentiators (target: 8 weeks after MVP)

Features that make Trove better than any free alternative.

### F-16 — Collections (custom pasteboards)
**Description:** Named groups of permanently stored clips, separate from the main history.

**Acceptance criteria:**
- Users can create, rename, reorder, and delete collections.
- Drag clips from history into a collection; remove from collection without deleting the clip.
- Per-collection keyboard shortcut opens the panel filtered to that collection.
- Examples to seed: "Email templates", "Code snippets", "Contact info".

### F-17 — Smart actions: URLs
**Description:** Contextual actions for URL clips.

**Acceptance criteria:**
- Open in default browser.
- Preview page title (fetched once, cached).
- Copy as Markdown link `[title](url)`.
- Generate QR code (for sharing to phone).

### F-18 — Smart actions: Colors
**Description:** Contextual actions for color clips.

**Acceptance criteria:**
- Show color swatch in the clip row.
- Convert between hex, rgb, hsl, oklch, and common code formats (SwiftUI `Color`, CSS, Tailwind class).
- Pick a similar Tailwind or Material color.

### F-19 — Smart actions: Code
**Description:** Contextual actions for code clips.

**Acceptance criteria:**
- Detect language (Swift, Python, JS/TS, HTML, CSS, SQL, JSON, shell) and syntax-highlight the preview.
- Format/prettify (via embedded Prettier or built-in formatters).
- Minify.
- Copy as code block with language fence for Markdown.

### F-20 — Smart actions: Images
**Description:** Contextual actions for image clips.

**Acceptance criteria:**
- Compress (to target size or quality level).
- Convert format (PNG, JPEG, HEIC, WebP).
- OCR to extract text (uses Vision framework, fully on-device).
- Copy as Base64 data URL.
- Save as file.

### F-21 — Smart actions: Numbers and JSON
**Description:** Contextual actions for numeric and JSON clips.

**Acceptance criteria:**
- Numbers: sum/average/max/min across multi-selected number clips.
- Numbers: unit conversion (temperature, length, weight, currency using a cached rate).
- JSON: pretty-print, minify, flatten, extract keys.
- Math expressions: evaluate and paste the result.

### F-22 — Multi-select and sequential paste
**Description:** Select multiple clips and paste them in order.

**Acceptance criteria:**
- ⌘-click or Shift-click to multi-select in the panel.
- A "Paste all" button appears when multiple clips are selected.
- Paste order matches selection order, with a configurable separator (newline, tab, comma, custom).
- Optional: "queue mode" — copy items one at a time, they join the queue, and a single hotkey pastes them in sequence at the destination.

### F-23 — Snippets with trigger expansion
**Description:** Text snippets that expand when a trigger is typed anywhere.

**Acceptance criteria:**
- User defines triggers like `;sig`, `;addr`, `;email`.
- Expansion fires on space, return, or tab (configurable).
- Supports placeholders: `{date}`, `{time}`, `{clipboard}`.
- Snippets are stored alongside clips and searchable in the main panel.
- Per-snippet enable/disable toggle.

### F-24 — Filters (text transformations)
**Description:** Named transformations applied to clips at paste time.

**Acceptance criteria:**
- Built-in filters: plain text, lowercase, UPPERCASE, Title Case, trim whitespace, strip newlines, URL-encode, URL-decode, Base64 encode/decode, JSON pretty, strip HTML tags.
- Custom filters: regex find/replace with capture groups.
- Filters can be chained.
- Each filter can have a hotkey that applies it to the current clipboard without opening the panel.
- Live preview while editing a filter.

### F-25 — Detail preview pane
**Description:** A side pane that shows full content of the selected clip.

**Acceptance criteria:**
- Opens with Space or right arrow; closes with Space or left arrow.
- Shows full content (text, rendered image, file icon + path).
- Shows metadata: size, dimensions (for images), character count (for text), source app, timestamp, type.
- Supports inline editing for text clips (press E, edit, ⌘↵ to save back to the clip).

---

## 8. Phase 3 — Advanced (target: 12 weeks after Phase 2)

All features remain free. These turn Trove into a multi-device, AI-aware clipboard platform.

### F-26 — iCloud sync
**Description:** Sync clipboard history, pinned clips, collections, snippets, and filters across the user's Macs and iOS devices.

**Acceptance criteria:**
- Uses CloudKit private database (no server infrastructure needed, no cost to maintainer).
- End-to-end encrypted via CloudKit's native encryption.
- Sync is opt-in; disabled by default.
- Granular toggles in Settings → Sync: sync clips / pinned / snippets / filters / settings independently.
- Conflicts resolved by most recent timestamp with a history pane for manual resolution.
- Configurable history-size-to-sync (e.g., sync last 500 only to save iCloud quota).

### F-27 — iOS and iPadOS companion app
**Description:** Access and paste clipboard history from iPhone and iPad. Also free.

**Acceptance criteria:**
- Shares CloudKit database with Mac app.
- Native SwiftUI app with a keyboard extension for in-app paste.
- Share sheet integration: share to the app to save as a clip.
- Shortcuts app integration: create shortcuts that use clips.
- Universal Clipboard continues to work alongside.

### F-28 — Local encryption
**Description:** Encrypt the clipboard database at rest.

**Acceptance criteria:**
- SQLite encrypted via SQLCipher.
- Encryption key stored in Keychain, tied to user account.
- Transparent to the user — no password prompt each launch.
- Optional extra layer: require Touch ID / passcode to open the app (Settings → Privacy).

### F-29 — AI actions (bring-your-own-key)
**Description:** Optional AI-powered transformations of clipboard content. User brings their own key or runs locally.

**Acceptance criteria:**
- Off by default; explicit opt-in required.
- Provider choice: Apple Intelligence (on-device, default when available), OpenAI, Anthropic, or local Ollama/LM Studio.
- BYO API key for cloud providers; key stored in Keychain, never transmitted anywhere except the chosen provider.
- Trove itself never charges or proxies for AI — users pay their chosen provider directly.
- Actions: summarize, rewrite in tone (formal/casual/concise), translate, format as table, fix grammar, extract action items, explain code.
- Clear labeling of which actions run on-device vs. cloud.
- Per-content-type action suggestions.

### F-30 — Workspaces
**Description:** Switch between isolated clipboard contexts (e.g., Work vs. Personal).

**Acceptance criteria:**
- Users define workspaces; each has its own history, collections, and snippets.
- Switch with a keyboard shortcut or menu bar picker.
- Optional: auto-switch based on active app or current Space.

### F-31 — Shell script filters
**Description:** Advanced filters written in shell for power users.

**Acceptance criteria:**
- Custom filters can be shell scripts that read stdin and write stdout.
- Sandboxed execution (no network, restricted file access).
- Clear warning when installing a shared script filter from another user.
- Only available in the direct-download build (not the sandboxed App Store build).

### F-32 — Community filter and snippet library
**Description:** A simple public library where users share filters, snippets, and collection templates.

**Acceptance criteria:**
- Hosted on GitHub as a curated community repo (`trove-community`).
- In-app browser to discover and install shared filters/snippets.
- Clear warnings about running third-party scripts.
- Users can export their own filters to contribute.

---

## 9. Settings architecture

Twelve sections, organized by frequency of use.

### S-01 General
Launch at login · Menu bar icon visibility · Dock icon visibility · Check for updates · Language.

### S-02 Clipboard
History size (100 / 500 / 2000 / unlimited) · Max clip size · What to capture (text / images / files / rich text) · Auto-delete after N days · Keep clips between launches.

### S-03 Hotkeys
Main panel · Paste last · Paste as plain text · Open settings · Per-collection shortcuts · Per-filter shortcuts · Snippet trigger prefix · Conflict detection.

### S-04 Appearance
Theme (auto / light / dark) · Panel size (compact / comfortable / spacious) · Accent color · Show source app · Show timestamps · Show preview thumbnails.

### S-05 Privacy and security
Excluded apps (with pre-populated list) · Auto-skip passwords · Clear history when Mac locks · Expire sensitive clips after N minutes · Require Touch ID to open app · Local encryption (on/off).

### S-06 Sync
Enable iCloud sync · Choose what to sync · Sync history size · Link iPhone (shows QR code or pairing screen).

### S-07 Collections
Manage collections · Reorder · Set default target collection · Auto-categorization rules.

### S-08 Filters
Built-in filters list · Create custom filter · Import/export filters · Assign hotkeys · Browse community library.

### S-09 Snippets
Trigger prefix · Expansion mode (space / return / immediate) · Manage snippets · Import from TextExpander / aText · Export as JSON · Browse community library.

### S-10 AI actions
Enable AI features · Provider (Apple Intelligence / OpenAI / Anthropic / Ollama) · API key field · Enable actions per content type · Data usage notice.

### S-11 Quick actions
Per-content-type toggles for every smart action (lets users disable ones they don't want).

### S-12 Advanced
Export settings as JSON · Import settings · Reset all settings · Clear all clips · Debug logs · Developer mode flags.

---

## 10. Non-functional requirements

### Performance
- Panel render: under 100ms (p95) from hotkey press to first paint.
- Paste action: under 200ms (p95) from Enter press to pasted content in target app.
- Search: under 50ms per keystroke for 10,000 clips.
- Idle memory: under 80 MB with 500 clips in history.
- Idle CPU: under 0.1% when panel is closed.

### Accessibility
- Full VoiceOver support with meaningful labels for every element.
- Respects Reduce Motion, Increase Contrast, and Reduce Transparency.
- Minimum text size 11px; user-configurable scale factor.
- All keyboard shortcuts documented and visible in the app.

### Privacy
- No telemetry by default. Opt-in anonymous crash reporting only.
- No network calls except: check-for-updates (optional), iCloud sync (opt-in), chosen AI provider (opt-in).
- Clear privacy policy written in plain language, accessible from Settings → About.
- All data encrypted at rest (Phase 3).
- Source code public — privacy claims are auditable.

### Platform and compatibility
- macOS 13 Ventura or later.
- Universal binary: Apple Silicon and Intel.
- iOS/iPadOS 17 or later (Phase 3 companion).
- Notarized and Developer ID signed.
- Hardened runtime enabled.
- Two builds: sandboxed (App Store) and non-sandboxed (direct download, supports shell-script filters).

### Reliability
- Crash-free rate above 99.5%.
- No data loss on unexpected quit (write-ahead logging in SQLite).
- Graceful degradation when Accessibility permission is denied (app still captures, but hotkey paste requires manual click).

---

## 11. Distribution

Trove is free. Two primary distribution channels, both at no cost to users:

### Primary — GitHub Releases + website
- Direct `.dmg` download from `trove.app` (or chosen domain).
- Source code on GitHub under MIT license.
- Sparkle framework for in-app auto-updates.
- No Apple Developer account required if users are willing to right-click-open past Gatekeeper. Recommended: $99/year Developer ID for a smoother install experience.

### Secondary — Mac App Store (optional, recommended)
- Same app, same price: free.
- Brings discoverability to non-technical users.
- Requires $99/year Apple Developer Program membership.
- Sandboxed build — shell script filters (F-31) disabled in this version.

### iOS companion (Phase 3)
- Mac App Store only (iOS has no sideloading option for most users).

## 12. Sustainability and funding

A free app still costs time and money. Options listed in order of user-friendliness:

### Recommended: optional donations
- **GitHub Sponsors** — monthly or one-time. Shows supporters on the repo.
- **Buy Me a Coffee / Ko-fi** — friendly, low-commitment way to support.
- **"Support Trove" menu item** in the app's About window that links to sponsor page. Never a popup or nag.

### Optional: paid Mac App Store listing
- Follow the Maccy model: free on GitHub, small paid listing (e.g., $4.99) on the Mac App Store for users who want the convenience of MAS and want to support the developer. Identical features in both versions.

### Avoid
- **Subscription.** Breaks the "free forever" promise.
- **Ads.** Incompatible with a trusted utility.
- **Data collection / selling.** Incompatible with the privacy-first principle.
- **Feature gates.** No "Pro" tier. Everyone gets every feature.
- **Crypto / token schemes.** No.

### Long-term sustainability
If Trove grows to need sustained maintenance beyond what one developer can donate:
- Form a small contributor team; accept community PRs.
- Apply for open-source grants (e.g., Sovereign Tech Fund, NLNet).
- Seek a single non-intrusive corporate sponsor (listed in About screen only).
- Never change the core promise — free and open.

---

## 13. Out of scope (v1)

Listed here so they don't creep into scope later without a decision.

- Windows or Linux versions.
- Browser extension.
- Team plans, user accounts, or shared workspaces beyond the community library.
- Plugin / extension marketplace.
- Clipboard history analytics.
- Cloud backup beyond iCloud.
- Markdown note-taking (Trove is a clipboard, not a notes app).
- A paid "Pro" tier of any kind.

---

## 14. Open questions

Decisions needed before or during Phase 1 development.

1. **Domain name.** Check `trove.app`, `troveapp.com`, `trove.mac`, `gettrove.com`. Pick one and lock it.
2. **License choice.** MIT (most permissive, most common) vs Apache 2.0 (explicit patent grant) vs GPL (forces downstream open-source). Recommendation: MIT.
3. **Icon design.** Treasure chest, gem, keyhole, or abstract mark? Needs to work at 16px.
4. **Logo typography.** Custom wordmark or clean use of SF Pro / Inter?
5. **Offline AI.** Bundle a small on-device model, or require users to install Ollama separately? Recommendation: Ollama link only — don't ship model weights.
6. **Developer ID.** Pay $99/year for Apple signing? Strongly recommended for install experience.
7. **Support channels.** GitHub Issues only, or add a Discord / Discussions board for a community feel?
8. **Localization at launch.** English only for v1.0. Community-contributed translations after launch.
9. **Contributor guidelines.** Need a clear CONTRIBUTING.md before accepting first PRs.

---

## Appendix A — Feature summary by phase

| Phase | Features | Duration | Goal |
|-------|----------|----------|------|
| MVP (Phase 1) | F-01 to F-15 | 8–12 weeks | Useful on day one |
| Differentiators (Phase 2) | F-16 to F-25 | 8 weeks | Best-in-class free option |
| Advanced (Phase 3) | F-26 to F-32 | 12 weeks | Multi-device, AI-aware, community-powered |

## Appendix B — Success metrics

For a free app, measure adoption and retention, not revenue.

- **Install rate:** Cumulative downloads from GitHub Releases + MAS installs. Target: 10,000 in first 6 months.
- **Activation:** % of installs that paste from the panel within 24 hours. Target: 80%.
- **Retention:** D7 and D30 active users (app launched + at least one paste). Target: D7 > 60%, D30 > 40%.
- **GitHub stars:** a proxy for developer-community interest. Target: 1,000 in year one.
- **Community contributions:** PRs merged from non-maintainers. Target: 20 in year one.
- **NPS:** In-app survey after 14 days. Target: > 50.
- **Performance:** p95 panel render time. Target: < 100ms.
- **Sponsorship:** optional — % of active users who sponsor on any tier. Target: > 0.5%.

## Appendix C — Open-source considerations

If Trove goes open source (recommended), these are the foundational files and decisions needed before the first public commit:

- **LICENSE** — MIT recommended.
- **README.md** — what Trove does, screenshots, install instructions, how to build, link to website.
- **CONTRIBUTING.md** — code of conduct, PR process, coding style, how to run tests.
- **CODE_OF_CONDUCT.md** — use Contributor Covenant 2.1 verbatim.
- **SECURITY.md** — how to report security issues privately.
- **Issue templates** — bug report, feature request, question.
- **PR template** — checklist of what a PR should contain.
- **CI** — GitHub Actions running SwiftLint + test suite on every PR.
- **CHANGELOG.md** — Keep a Changelog format, updated every release.
- **Public project board** — Phase 1 / Phase 2 / Phase 3 columns, visible on GitHub Projects.

### Governance (simple for v1)
- One maintainer (Sampath) with merge authority.
- PRs require: passing CI, one maintainer approval, CLA if desired (optional for MIT).
- All major direction changes discussed in a GitHub Discussion before implementation.

---

## Appendix D — Launch checklist

Before Trove 1.0 ships publicly:

- [ ] Final name confirmed, domain registered, trademark checked.
- [ ] Developer ID certificate obtained.
- [ ] App notarized and tested on fresh macOS install.
- [ ] Privacy policy and terms written and linked.
- [ ] Website live with screenshots, feature list, download link, FAQ.
- [ ] README polished with GIFs/screenshots.
- [ ] Twitter/X, Mastodon, and Bluesky accounts claimed.
- [ ] Show HN / Product Hunt launch post drafted.
- [ ] Reddit post drafted for r/macapps.
- [ ] A pinned GitHub issue explaining the roadmap.
- [ ] GitHub Sponsors enabled.
- [ ] CI passing, all tests green.
- [ ] One friend has used it for a week without filing a bug.
