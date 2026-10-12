# Development build and verification

Use one canonical development bundle across checkouts: `/private/tmp/NeTelegram-Dev.app`. Its default account catalogue is `/private/tmp/netelegram-dev-support`; set `NETELEGRAM_SUPPORT_ROOT` only when an isolated QA run explicitly needs a separate catalogue. `Scripts/dev-app.sh` builds intermediates under the repository's ignored `.build/` directory, writes the bundle to the canonical path, and records source and binary fingerprints. It refuses to replace a running NeTelegram process and opens the existing app instance without forcing a second process. The catalogue belongs only to this development app; it is never discovered from an installed Telegram client or shared with a release bundle.

## Test cadence

1. Complete one related vertical slice before rebuilding.
2. Run the existing `swift test` suite once at that boundary; do not rerun it when inputs have not changed.
3. Launch the canonical development bundle only for auth, lifecycle, or visible UI changes. Record its build fingerprint and the single scenario checked. Do not use `swift run` to start a second app instance.
4. Keep real-account checks separate from synthetic tests. Never seed fake Telegram identities or read installed Telegram app data.
5. Report test count and scenario coverage accurately. A passing synthetic suite does not prove real login, send, multi-account behavior, sleep/wake recovery, or a signed release.

## Current evidence

- Source `b3350623dd6498532dce219e7bb76ca35ac8696c` is the current `main` tip. The last code-changing slice, account logout/presentation cleanup at `0dcfdbef0e0a4be5e20eebf6be35c95fd6f09daa`, passed the full synthetic/core suite: 40/40 on Swift 6.4 / Xcode 27.0. The current tip also passed hosted CI run `38255270635` on Apple Silicon; that docs-only commit did not require another local test run.
- The sole canonical bundle at `/private/tmp/NeTelegram-Dev.app` still records source `5e48cece3119ce0118930b27fa94dcd39f9a928b` and ad-hoc development signing. It is currently running as PID 124. Do not kill it or replace its bundle; rebuild this same path once after it exits.
- The earlier first-run smoke showed phone entry and a QR option without entering credentials. No real Telegram account has been authorized, so real login/read/send/logout and multi-account behavior remain unverified.
- Developer ID signing, notarization, real-account scenarios, and twenty-runtime measurements remain open release gates.
