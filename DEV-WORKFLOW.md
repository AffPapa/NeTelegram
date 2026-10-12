# Development build and verification

Use one development bundle per checkout. `Scripts/dev-app.sh` builds the app under the repository's ignored `.build/` directory and writes a build record beside the build scratch data. The persistent development account catalogue lives under `~/Library/Application Support/NeTelegram-Dev`; it is separate from any installed Telegram client and from a release bundle. For an isolated first-run smoke, set `NETELEGRAM_SUPPORT_ROOT` to a disposable directory before `Scripts/dev-app.sh --launch`.

## Test cadence

1. Complete one related vertical slice before rebuilding.
2. Run the existing `swift test` suite once at that boundary; do not rerun it when inputs have not changed.
3. Launch the canonical development bundle only for auth, lifecycle, or visible UI changes. Record its build fingerprint and the single scenario checked.
4. Keep real-account checks separate from synthetic tests. Never seed fake Telegram identities or read installed Telegram app data.
5. Report test count and scenario coverage accurately. A passing synthetic suite does not prove real login, send, multi-account behavior, sleep/wake recovery, or a signed release.

## Current evidence

- The current source has 35 synthetic/core tests; the clean public export passed all 35 on Swift 6.4 and Xcode 27.0.
- A native no-account first-run screen showed phone entry and a QR option. No phone number or code was entered; no Telegram account was authorized.
- Developer ID signing, notarization, real-account scenarios, and twenty-runtime measurements remain unverified.
