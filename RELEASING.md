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

## Code-signing & notarization

The `release` job signs the app with a **Developer ID Application** certificate,
enables the hardened runtime, and notarizes + staples the DMG — but only when
the signing secrets below are present. Without them it falls back to the
existing **unsigned** build, so forks and dry-runs still work.

You need a paid Apple Developer account. Set these repository secrets
(Settings → Secrets and variables → Actions):

| Secret | What it is |
| --- | --- |
| `MACOS_CERTIFICATE` | Base64 of your exported `Developer ID Application` cert `.p12`. Presence of this secret is what flips CI into the signed path. |
| `MACOS_CERTIFICATE_PWD` | Password you set when exporting the `.p12`. |
| `KEYCHAIN_PASSWORD` | Any throwaway string; used to create the temporary CI keychain. |
| `DEVELOPMENT_TEAM` | Your 10-character Apple Team ID. |
| `NOTARY_APPLE_ID` | Apple ID email used for notarization. |
| `NOTARY_PASSWORD` | An [app-specific password](https://support.apple.com/en-us/102654) for that Apple ID. |
| `NOTARY_TEAM_ID` | Apple Team ID (same value as `DEVELOPMENT_TEAM`). |

### Exporting the certificate

1. In **Keychain Access**, find your *Developer ID Application: …* certificate,
   right-click → **Export** → save as `cert.p12` with a password.
2. Base64-encode it for the secret:
   ```bash
   base64 -i cert.p12 | pbcopy   # paste into MACOS_CERTIFICATE
   ```

### First signed release

Signing/notarization can't be dry-run here, so validate it on a real tag. After
setting the secrets, cut a release (below) and confirm the `release` job's
notarize step succeeds. Then verify the artifact:
```bash
spctl -a -t open --context context:primary-signature -vvv Trove.dmg   # should say: accepted
codesign --verify --deep --strict --verbose=2 /Applications/Trove.app
```
Once notarized + stapled, users no longer need the `xattr` quarantine
workaround — you can drop that note from the README.
