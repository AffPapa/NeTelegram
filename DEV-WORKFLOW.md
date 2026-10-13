# Development build and verification

Use one canonical development bundle across checkouts: `/private/tmp/NeTelegram-Dev.app`. Its default account catalogue is `/private/tmp/netelegram-dev-support`; set `NETELEGRAM_SUPPORT_ROOT` only when an isolated QA run explicitly needs a separate catalogue. `Scripts/dev-app.sh` builds intermediates under the repository's ignored `.build/` directory, writes the bundle to the canonical path, and records source and binary fingerprints. It refuses to replace a running NeTelegram process and opens the existing app instance without forcing a second process. The catalogue belongs only to this development app; it is never discovered from an installed Telegram client or shared with a release bundle.

## Test cadence

1. Complete one related vertical slice before rebuilding.
2. Use the lightest check that answers the current question while editing; run the full existing serial `swift test` suite once after the slice is complete and before commit. Do not repeat it when source and harness inputs are unchanged.
3. The hosted macOS suite is the exact-source test gate. Its normal elapsed time is about 50 seconds; it stays serial because parallel execution stranded a continuation test. If a runner stalls, inspect the exact job log first. One same-SHA rerun is appropriate only after diagnosis; do not repeat runs or make product edits without failure evidence.
4. Launch the canonical development bundle only for auth, lifecycle, or visible UI changes. Record its build fingerprint and the single scenario checked. Do not use `swift run` to start a second app instance.
5. The pinned TDLib/Dev.app workflow is the expensive packaging/lifecycle gate. Push/PR changes to `Package.swift`, `TDLIB.lock.json`, `Scripts/**` native build/lifecycle inputs, and this workflow trigger it automatically. The path names are case-sensitive on GitHub. Source-only Swift changes do not rebuild pinned TDLib; `ci.yml` already runs the serial macOS suite for those changes. Use the existing `workflow_dispatch` for TDLib/runtime integration changes that need a bundled native check and for a frozen release candidate. For visible auth/lifecycle/UI edits, run the single canonical Dev.app scenario only when the changed surface needs GUI evidence. The Ubuntu metadata workflow covers machine-readable checkpoint/template changes.
6. Keep real-account checks separate from synthetic tests. Never seed fake Telegram identities or read installed Telegram app data.
7. Report test count and scenario coverage accurately. A passing synthetic suite does not prove real login, send, multi-account behavior, sleep/wake recovery, or a signed release.

## Fast feedback and release boundary

- One canonical checkout, one source SHA, and one Dev.app path are used for a milestone. Do not switch among stale bundles or rebuild the same candidate after a Site-only failure.
- Docs and static website edits use their relevant validators; metadata edits use `metadata.yml`; Swift changes use the full serial suite once. Native bundle smoke is a separate candidate gate, not another way to rerun unit tests.
- Freeze one release candidate from a clean source SHA. Build/sign/notarize that candidate once, verify its final bytes, publish those immutable bytes, and then update the Site from the verified manifest. Site fixes do not trigger app rebuilds.
- Keep each milestone's evidence in `PROJECT-STATE.json`, `ACCEPTANCE.json`, and the append-only `RUN-LOG.md`; never mark a timeout, access denial, or unrun scenario as PASS.

## Current evidence

- `ACCEPTANCE.json.last_verification` is the single source for exact test count, source revision, toolchain, architecture, and hosted CI evidence. Keep revision numbers and test totals out of duplicated prose here; update the acceptance record after a verification boundary.
- The only development bundle is `/private/tmp/NeTelegram-Dev.app`. Before rebuilding it, inspect its embedded `Contents/Resources/BuildInfo.json` and confirm the process has exited. Rebuild this same path once; never launch a second development identity for routine smoke.
- The prior no-account first-run smoke reached phone entry and QR login without entering credentials. That does not prove a real Telegram login/read/send/logout flow or multi-account behavior.
- Developer ID signing, notarization, real-account scenarios, and twenty-runtime measurements remain open release gates.
