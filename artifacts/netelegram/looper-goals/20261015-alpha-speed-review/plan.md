# Review result and 0.1 alpha plan

## Pinned state at review

- Checkout: `/private/tmp/netelegram-cli-work`, branch `main`, origin `AffPapa/NeTelegram`; at the start of the follow-up HEAD was `4aa9b7feb468efb95986c2bea2cc126147a1de34`. The current alpha channel-gating slice is in the working tree; the canonical Dev.app remains pinned to app-source `75589091d7144e1d1ffe94b15bf38638df7d708d` and was not replaced because process absence could not be proven. App source remains separately pinned at `75589091d7144e1d1ffe94b15bf38638df7d708d`.
- App source: `75589091d7144e1d1ffe94b15bf38638df7d708d`; canonical Dev.app: `/private/tmp/NeTelegram-Dev.app`, `0.0.0-dev`, arm64, macOS 14, ad-hoc only. Not a distribution artifact.
- Current Site: public v218, no app download, empty alpha/stable feeds.
- Acceptance: 56 cases: 3 passed, 46 partial, 7 not run. Synthetic 20-profile tests are not real multi-account validation. All available authorized accounts remaining active is a required product behavior at every release, not a stable-only feature.
- Current blockers: owner-operated one-account login/read/send smoke not done; latest checkpoint reports no notarization credential profile; the separate release builder is implemented but unexecuted; no signed/notarized app or release assets. Developer ID identities exist, but no NeTide distribution bundle has been signed. Latest exact metadata CI evidence is run `38741886157` for `d47555d`; the release manifest contract change is pushed. It is not app-source CI and proves no native build or real archive signature.

## Why this took too long

1. The highest-value proof (one real login and a message round trip) was deferred while Core architecture, synthetic 20-profile coverage, and authentication UI polish expanded.
2. Work sometimes followed a stale app/screenshot/checkpoint identity. The app source SHA, running PID/build, repo checkpoint, Site source, saved Site version, and deployment were conflated.
3. The Site received repeated development-log releases before a binary existed; those deployments did not advance the GitHub download gate.
4. Environment and harness failures (sandbox DNS, SwiftPM sandbox, wrong helper route, Sparkle artifact path casing) were sometimes repeated before classifying product vs harness vs environment and choosing the supported route. A fresh confirmed example: metadata CI run `38743940093` failed because a stable-channel test on Ubuntu hit the macOS guard first; a local Mac test had masked the test's platform dependency. The failing assertion is now understood and the policy guard ordering is corrected locally.
5. Checkpoint summaries accumulated contradictory “latest” facts (brand, Keychain, Site, CI). The append-only evidence was good, but projections needed reconciliation before each turn.
6. Tests for synthetic profiles/close barriers increased design confidence but were repeatedly too easy to treat as progress toward real Telegram sessions, which they do not prove.

## Faster execution rules

- Begin each turn with one current checkpoint and verify checkout/HEAD/dirty state, app source SHA, app PID/BuildInfo, Site version and external release state as separate identities.
- Keep one canonical checkout and one Dev.app. Never rebuild for a Site-only failure; never launch preview builds as the app under test.
- Use one alpha acceptance path: real login → chats load → read → send → close/reopen. If owner input is pending, stop adding synthetic coverage unrelated to the reproduced blocker.
- For every defect: capture the exact failing assertion/step and log → classify (product/test contract/setup/network/permissions/environment) → make one narrow change → run one focused check. Reuse passing checks for matching inputs. After two identical failures, diagnose before another retry. Contract tests must be deterministic on the runner OS and must reach the policy being tested before host-specific guards when safe.
- UI edits require fresh screenshot + title + BuildInfo/source SHA + PID. No screenshot-driven work from stale captures.
- Freeze UI and feature scope after alpha P0s. Telegram Desktop is a reference for interaction hierarchy, but recreate patterns in AppKit; do not copy GPL implementation/assets into this MIT codebase.
- Freeze a source SHA before release work. Separate release builder and scratch/output from destructive `Scripts/dev-app.sh`; no ad-hoc Dev.app signing as distribution proof.
- Do not copy Telegram Desktop code or artwork into the MIT app: upstream is Qt/C++ and GPL-3.0 with an OpenSSL linking exception. Its useful reference is component composition and interaction hierarchy (dialog list + history, explicit selection/unread states, persistent composer); implement these ideas with native AppKit controls and retain NeTide branding.
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

## Follow-up slice: alpha channel access gate

- A release-scope audit found the candidate builder did not encode the user's decision to defer channels while sponsored video support is incomplete. The app still requested channel history after an open and could route a channel notification; the documentation said channels were blocked, but the executable did not enforce that promise.
- Added `ChannelAccessPolicy`: the `.dev` bundle keeps development access; distribution defaults closed, and this alpha builder embeds `NeTideChannelAccessEnabled=false`. Distribution chat lists/search hide channels, direct opening/history/rendering fail closed, sponsored-channel requests are suppressed, and channel notification routes/previews are removed per account/chat. All account runtimes remain connected. Unknown search/notification chat metadata is queried once and held until TDLib provides its type.
- Reconciled the Russian compatibility paragraph in `README.md`: public application name NeTide; NeTelegram is the repo codename.
- Focused macOS Swift tests: 4/4 passed (three policy cases plus chat-scoped notification cleanup); AppKit executable target build passed; `bash -n Scripts/build-release-candidate.sh` and `git diff --check` passed. The first default sandbox run failed before manifest compilation; the temporary cache route still hit the package sandbox, then the approved direct Xcode route passed. No duplicate retry was made after the second diagnosis.
- Commit `a5ad2b4c999471155aeee7cd11df49814db84d96` is pushed to `AffPapa/NeTelegram` main. Exact-source macOS CI run `38747373798` passed 218/218; pinned TDLib/isolated Dev.app workflow `38747373731` passed. No canonical Dev.app rebuild or UI smoke: `check-app-process.sh` could not prove process absence, so replacement is held. No account session or credential was read. These are source/CI artifacts, not a real account smoke or signed distribution candidate.

## Gate status / exact next action

- **Next user action:** owner completes the real one-account smoke in `/private/tmp/NeTelegram-Dev.app`: enter credentials only in the app, confirm chat list, read one chat, send one approved test message, quit/reopen and confirm the same identity returns. No credentials or message content should be sent in chat. This is the highest-value product gate; only a reproduced P0 justifies an app fix.
- **Current engineering action:** finish/review the channel fail-closed slice, then commit/push once and inspect the exact-source macOS CI and native-app workflow logs once. The canonical Dev.app process state could not be proven absent; do not replace it until the guarded path confirms it is safe. Next product gate remains the owner-operated login/read/send/reopen on the existing canonical app; do not repeat the request while the user has deferred it.
- **Release setup blocker:** notarization profile was absent in the latest checkpoint. After the smoke and source freeze, use the supported Apple credential setup path. Never ask for a password pasted in chat.
- **Release assembly:** `Scripts/build-release-candidate.sh` is implemented as a separate fail-closed path and has local contract coverage. It still needs an available notarytool Keychain profile, a configured Sparkle public key, and an accessible Sparkle private key; it has not built or signed an artifact. Run it only from a clean exact published source SHA after owner smoke/P0 freeze.
- **Coverage may remain partial for alpha:** 20 real authorized accounts and the 1/5/10/20 resource matrix are not required to make a narrow alpha claim, but all-active runtime behavior remains mandatory in the implementation. Do not ship an alpha that only keeps one selected plus a few background accounts; report exact real-account coverage and leave 20-account certification open until it is measured.
- **Not complete:** this plan does not constitute a build, account smoke, notarization, release, Site update, or compatibility PASS.
