# Development build and verification

Use one canonical development bundle across checkouts: `/private/tmp/NeTelegram-Dev.app`. Its default account catalogue is the isolated `/private/tmp/netelegram-dev-support-clean`; set `NETELEGRAM_SUPPORT_ROOT` only when a specifically named QA run needs a separate catalogue. The former `/private/tmp/netelegram-dev-support` is preserved and is not used by routine builds. `Scripts/dev-app.sh` builds intermediates under the repository's ignored `.build/` directory, writes the bundle to the canonical path, and records source and binary fingerprints. It refuses to replace a running NeTelegram process and opens the existing app instance without forcing a second process. The catalogue belongs only to this development app; it is never discovered from an installed Telegram client or shared with a release bundle.

## Test cadence

1. Finish one related vertical slice before rebuilding. Keep one checkout, one app-source SHA, and the one canonical Dev.app; do not start a parallel bundle. Complete any delegated read-only reviews before freezing the candidate; the parent owns edits, tests, pushes, builds, and publication. This prevents late findings from invalidating a just-built candidate.
2. While editing, run only the focused regression needed for fast diagnosis. After the slice is complete, push its final source SHA once and let the automatic macOS CI be the sole full-suite gate. Do not also run the full suite locally or dispatch another CI run when the exact SHA already has a successful run. Local full-suite runs are for offline work, toolchain changes, or diagnosing a hosted-only failure.
3. CI runs one bounded `swift test --no-parallel --verbose` process for the full suite. Do not add several preflight `swift test` processes before it: isolated probe passes did not prevent the full-runner timeout and repeated SwiftPM startup. For a hosted failure, inspect the exact run's job/log, classify product vs test vs runner/setup, and change the harness or source before retrying. A built binary with no `Test run started` output is runner/test-execution evidence, not a test-level failure. The SwiftPM cache key includes OS, architecture, Swift/Xcode versions, `Package.swift`, and `TDLIB.lock.json`; observed warm/cold compile times are comparisons, not guarantees.
4. Select verification by changed surface:

   | Changed surface | Required check |
   | --- | --- |
   | Swift/core tests | One focused test during iteration; one automatic exact-SHA serial macOS suite after the slice |
   | Visible AppKit/auth/lifecycle | Above, plus one run of the canonical Dev.app and one named UI scenario |
   | `Package.swift`, TDLib pin, or native build/lifecycle scripts | Automatic pinned-TDLib/Dev.app workflow; don't dispatch it again for the same SHA |
   | Checkpoint, release metadata, README, or Python release tests | JSON/checkpoint validator and Ubuntu metadata workflow only; no Swift suite or Dev.app rebuild |
   | Site source | Site build/route validation and deployment only; never rebuild the app for a Site-only failure |

5. Before manual `workflow_dispatch`, look up Actions for the exact SHA. Dispatch only if the required workflow did not start automatically and no equivalent successful run exists. Do not retry a completed success. Do not change the probe name without changing the focused test and workflow filter together.
6. Launch the canonical Dev.app only for auth, lifecycle, or visible UI changes. Verify its embedded source SHA and reuse fingerprint before opening. Do not use `swift run` to start a second app instance.
7. Keep real-account checks separate from synthetic tests. Never seed fake Telegram identities or inspect installed Telegram app data. Passing synthetic tests do not prove real login/send, 20 authorized runtimes, sleep/wake, resource limits, or distribution signing.

## Preview and real-client boundary

- `--ci-auth-layout-preview` and `--ci-chat-shell-preview` are offline visual fixtures. They skip profile restoration and connection observers; login and QR actions intentionally send no requests. Never use a preview window for owner login or account acceptance.
- Before a real login, launch the canonical bundle in normal `--launch` mode and verify the window title and process arguments contain no `--ci-*-preview` flags. A screenshot title or old process is not evidence for the current source.
- `open --args` does not change arguments on an already-running macOS app. `Scripts/dev-app.sh` now compares requested preview flags with the live process and refuses a mode mismatch; quit the current instance before switching between preview and normal client. If process arguments cannot be checked, stop rather than infer a successful switch.

## Fast feedback and release boundary

- One canonical checkout, one source SHA, and one Dev.app path are used for a milestone. Do not switch among stale bundles or rebuild the same candidate after a Site-only failure.
- Docs and static website edits use their relevant validators; metadata edits use `metadata.yml`; Swift changes use the full serial suite once. Native bundle smoke is a separate candidate gate, not another way to rerun unit tests.
- Select checks from the changed paths before editing: Swift source -> one full serial suite; AppKit visible/lifecycle change -> also one scenario in the canonical Dev.app; workflow/toolchain/pin change -> the matching hosted integration gate; state/acceptance/README-only change -> JSON/metadata validators; Site source -> Site build/route checks. Do not rerun an unchanged gate to gain confidence. After a failure, inspect its job/log and change the next action based on the observed failure stage.
- Freeze one release candidate from a clean source SHA. Build/sign/notarize that candidate once, verify its final bytes, publish those immutable bytes, and then update the Site from the verified manifest. Site fixes do not trigger app rebuilds.
- Validate a frozen release candidate with `python3 Scripts/validate_release.py candidate <manifest.json> --assets-dir <frozen-assets-dir>` before publication. After GitHub publication, download and hash-check its public assets, then write an append-only pre-Site receipt and validate it with `python3 Scripts/validate_release.py receipt <manifest.json> <assets-receipt.json> --stage assets`. This receipt covers Gatekeeper/quarantine and install/reopen evidence plus exact public bytes; it must not claim Site checks.
- Then build, save, and deploy the one Site archive containing downloads, changelog, and updater feeds. After anonymous URL/MIME/feed checks, write the final receipt referencing the exact pre-Site receipt bytes and Site deployment/version, and validate with `python3 Scripts/validate_release.py receipt <manifest.json> <delivery-receipt.json> --stage delivery --asset-receipt <assets-receipt.json>`. Never add publication time or downloaded-byte results to immutable `release.json`. CI tests these gates with synthetic fixture bytes and cannot substitute those fixtures for real-account coverage.
- Keep each milestone's evidence in `PROJECT-STATE.json`, `ACCEPTANCE.json`, and the append-only `RUN-LOG.md`; never mark a timeout, access denial, or unrun scenario as PASS.

## Current evidence

- `ACCEPTANCE.json.last_verification` is the single source for exact test count, source revision, toolchain, architecture, and hosted CI evidence. Keep revision numbers and test totals out of duplicated prose here; update the acceptance record after a verification boundary.
- The only development bundle is `/private/tmp/NeTelegram-Dev.app`. Before rebuilding it, inspect its embedded `Contents/Resources/BuildInfo.json` and confirm the process has exited. Rebuild this same path once; never launch a second development identity for routine smoke.
- The prior no-account first-run smoke reached phone entry and QR login without entering credentials. That does not prove a real Telegram login/read/send/logout flow or multi-account behavior.
- Developer ID signing, notarization, real-account scenarios, and twenty-runtime measurements remain open release gates.


## LaunchServices recovery

If `Scripts/dev-app.sh --launch` returns `kLSNoExecutableErr`, first verify BuildInfo, executable presence, source fingerprint, and strict ad-hoc signature. Do not start the executable directly or create another bundle. Bind and launch the single canonical `/private/tmp/NeTelegram-Dev.app` by exact path through CUA once, then verify its window title/AX state match the embedded source commit. Record both the LaunchServices failure and successful exact-path smoke; do not call the failure a product crash without evidence.
