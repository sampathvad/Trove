# Releasing Trove

Trove ships auto-updates via [Sparkle](https://sparkle-project.org). Each
release is a `Trove.dmg` plus a signed `appcast.xml`, both attached to the
GitHub release. The app checks the appcast at:

```
https://github.com/sampathvad/Trove/releases/latest/download/appcast.xml
```

## One-time setup: generate the EdDSA signing key

Sparkle 2 requires every update to be signed with an EdDSA (ed25519) key. The
**public** key is embedded in the app; the **private** key stays secret and
signs each release.

1. Get Sparkle's tools (once):
   ```bash
   VERSION=2.6.4
   curl -L "https://github.com/sparkle-project/Sparkle/releases/download/$VERSION/Sparkle-$VERSION.tar.xz" | tar -xJ
   ```
2. Generate the key pair:
   ```bash
   ./bin/generate_keys
   ```
   This stores the **private** key in your login Keychain and prints the
   **public** key, e.g. `SUPublicEDKey: aBcD1234...=`.
3. Paste the public key into `Trove/Resources/Info.plist` under `SUPublicEDKey`,
   replacing the `REPLACE_WITH_SPARKLE_ED_PUBLIC_KEY` placeholder. Commit it.
4. Export the private key for CI and add it as the GitHub Actions secret
   **`SPARKLE_PRIVATE_KEY`**:
   ```bash
   ./bin/generate_keys -x sparkle_private_key.pem
   # paste the file contents into the repo secret, then delete the file
   rm sparkle_private_key.pem
   ```

> Until `SUPublicEDKey` is a real key **and** the appcast is signed with the
> matching private key, Sparkle will detect updates but refuse to install them.

## Cutting a release

1. Bump `MARKETING_VERSION` in `project.yml` (and regenerate: `xcodegen generate`).
2. Commit, tag, and push:
   ```bash
   git tag v0.1.12 && git push origin v0.1.12
   ```
3. CI (`.github/workflows/ci.yml`, `release` job) builds the unsigned DMG. If
   the `SPARKLE_PRIVATE_KEY` secret is set it also runs `generate_appcast` to
   produce and sign `appcast.xml`, then uploads both to the release. Without the
   secret the DMG still ships; only the appcast step is skipped.

## Signing & notarization (recommended follow-up)

The release build is currently **unsigned**. For a frictionless install (and so
Sparkle can validate downloads on modern macOS) the DMG should be signed with a
Developer ID certificate and notarized. That requires a paid Apple Developer
account and is tracked separately from auto-update wiring.
