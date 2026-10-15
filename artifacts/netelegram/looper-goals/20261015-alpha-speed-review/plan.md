# Review result and 0.1 alpha plan

## Pinned state at review

- Checkout: `/private/tmp/netelegram-cli-work`, branch `main`, origin `AffPapa/NeTelegram`; release-tooling commit `d47555d6f62a0c60227a42db099961df4c57f593`; checkpoint commit before this reconciliation was `5324b97e859c9fadc47545ed159fbf8efa21bfc7`. The app source is separately pinned at `75589091d7144e1d1ffe94b15bf38638df7d708d`; verify the new checkpoint SHA at resume.
- App source: `75589091d7144e1d1ffe94b15bf38638df7d708d`; canonical Dev.app: `/private/tmp/NeTelegram-Dev.app`, `0.0.0-dev`, arm64, macOS 14, ad-hoc only. Not a distribution artifact.
- Current Site: public v218, no app download, empty alpha/stable feeds.
- Acceptance: 56 cases: 3 passed, 46 partial, 7 not run. Synthetic 20-profile tests are not real multi-account validation. All available authorized accounts remaining active is a required product behavior at every release, not a stable-only feature.
- Current blockers: owner-operated one-account login/read/send smoke not done; latest checkpoint reports no notarization credential profile; no safe release assembler; no signed/notarized app or release assets. Developer ID identities exist, but no NeTide distribution bundle has been signed. Latest exact metadata CI evidence is run `38741886157` for `d47555d`; the release manifest contract change is pushed. It is not app-source CI and proves no native build or real archive signature.

## Why this took too long

1. The highest-value proof (one real login and a message round trip) was deferred while Core architecture, synthetic 20-profile coverage, and authentication UI polish expanded.
2. Work sometimes followed a stale app/screenshot/checkpoint identity. The app source SHA, running PID/build, repo checkpoint, Site source, saved Site version, and deployment were conflated.
3. The Site received repeated development-log releases before a binary existed; those deployments did not advance the GitHub download gate.
4. Environment failures (sandbox DNS, SwiftPM sandbox, wrong helper route, Sparkle artifact path casing) were sometimes repeated before classifying product vs harness vs environment and choosing the supported route.
5. Checkpoint summaries accumulated contradictory “latest” facts (brand, Keychain, Site, CI). The append-only evidence was good, but projections needed reconciliation before each turn.
6. Tests for synthetic profiles/close barriers increased design confidence but were repeatedly too easy to treat as progress toward real Telegram sessions, which they do not prove.

## Faster execution rules

- Begin each turn with one current checkpoint and verify checkout/HEAD/dirty state, app source SHA, app PID/BuildInfo, Site version and external release state as separate identities.
- Keep one canonical checkout and one Dev.app. Never rebuild for a Site-only failure; never launch preview builds as the app under test.
- Use one alpha acceptance path: real login → chats load → read → send → close/reopen. If owner input is pending, stop adding synthetic coverage unrelated to the reproduced blocker.
- For every defect: evidence → cause class (product/harness/setup/environment) → one narrow change → one focused check. Reuse passing checks when relevant inputs match. Diagnose after one identical failure.
- UI edits require fresh screenshot + title + BuildInfo/source SHA + PID. No screenshot-driven work from stale captures.
- Freeze UI and feature scope after alpha P0s. Telegram Desktop is a reference for interaction hierarchy, but recreate patterns in AppKit; do not copy GPL implementation/assets into this MIT codebase.
- Freeze a source SHA before release work. Separate release builder and scratch/output from destructive `Scripts/dev-app.sh`; no ad-hoc Dev.app signing as distribution proof.
- Do not update the existing Site again until verified GitHub assets are available; then update downloads/changelog/manifest together in one Site save/deploy.
- Keep a compact top-level “current truth” in checkpoint; append history in RUN-LOG. Mark stale projections superseded rather than adding another ambiguous latest field.
- Never act on a plan's pinned identity without rechecking it. Refresh `HEAD`, dirty paths, app-source SHA, running BuildInfo/PID, Site version, and public release inventory at the start; update this plan when any pointer changes.
- Existing Site v218 is not the release path. Freeze Site work until verified GitHub assets exist, then make one manifest-driven deployment.
- For the current Sparkle contract slice, focused `python3 -m unittest Tests.release.test_validate_release` passed 24/24 locally; JSON parsing, `py_compile`, and `git diff --check` passed. This is metadata-tool validation only, not CI, a cryptographic signature, a native build, or a release.

## 0.1 alpha delivery sequence

### A. Owner smoke (first gate)

Use the already-running canonical Dev.app and its existing protected API configuration. Owner enters phone/code/2FA only in the app. Verify the real account becomes the list row (no UUID profiles), chats load, read one existing chat, send one user-approved test message, close the app normally, relaunch, and confirm the authenticated identity remains. Record account count and exact app/source identity without phone number, chat content, tokens, or logs. If this fails, fix only the observed P0 and repeat just that step.

### B. Freeze the alpha scope and candidate source

Public app name: NeTide; repository codename: NeTelegram. Alpha is explicitly limited. Hide channel access until sponsored-video and sponsored-message requirements can be satisfied; do not call it Telegram-compatible or stable. Keep product/API Terms §§1.3/1.4 and §3.3 as unresolved gates. Verify the release notes and manifest state limitations plainly. One exact-SHA test workflow after any final source change; no UI redesign or broad regression rerun absent a changed surface.

### C. Build and verify a separate release candidate

Create/finish a separate release assembler using its own output and SwiftPM scratch; preserve Dev.app. Use the available Developer ID identity, Hardened Runtime and minimal entitlements, sign Sparkle nested code inside-out, verify signatures, submit with supported notarytool credentials, require Accepted, staple, then produce ZIP/DMG, SBOM, NOTICE, hashes and candidate manifest from final bytes. Run quarantine/Gatekeeper install/reopen smoke. Resolve manifest/tag semantics and whether alpha includes a signed Sparkle update archive/feed before cutting the candidate.

### D. Publish once, in dependency order

Publish immutable GitHub alpha assets against the exact source commit; download them anonymously and compare SHA-256, notarization and install receipts. Only after public-byte verification, update the existing OpenAI Site once so the single source manifest drives the download button, version, changelog, checksums and alpha feed; save/deploy one exact version and verify anonymous routes/content-types/links. Do not replace an existing version’s assets.

## Gate status / exact next action

- **Next user action:** owner completes the real one-account smoke in `/private/tmp/NeTelegram-Dev.app`: enter credentials only in the app, confirm chat list, read one chat, send one approved test message, quit/reopen and confirm the same identity returns. No credentials or message content should be sent in chat. This is the highest-value product gate; only a reproduced P0 justifies an app fix.
- **Current engineering action:** complete the release-contract bookkeeping (checkpoint metadata refresh and its validator), then proceed to the owner-operated login/read/send/reopen smoke. Do not rebuild the app because this metadata slice does not touch app source.
- **Release setup blocker:** notarization profile was absent in the latest checkpoint. After the smoke and source freeze, use the supported Apple credential setup path. Never ask for a password pasted in chat.
- **Implementation gap:** there is no safe release assembler. Implement it only after smoke exposes any source fix and the alpha source SHA is frozen.
- **Coverage may remain partial for alpha:** 20 real authorized accounts and the 1/5/10/20 resource matrix are not required to make a narrow alpha claim, but all-active runtime behavior remains mandatory in the implementation. Do not ship an alpha that only keeps one selected plus a few background accounts; report exact real-account coverage and leave 20-account certification open until it is measured.
- **Not complete:** this plan does not constitute a build, account smoke, notarization, release, Site update, or compatibility PASS.
