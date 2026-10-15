# Review result and 0.1 alpha plan

## Pinned state at review

- **Refresh 2026-10-15 (after release-name fix):** checkout `/private/tmp/netelegram-cli-work`, branch `main`, origin `AffPapa/NeTelegram`, clean HEAD/origin `c210be2beafe5af521207a6923b6582a4060a093`. App source remains `a5ad2b4c999471155aeee7cd11df49814db84d96`; the canonical `/private/tmp/NeTelegram-Dev.app` remains accountless-smoked from that SHA, arm64/macOS 14, ad-hoc development signing only. Release packaging now consistently uses public app root `NeTide.app` while retaining the internal executable `NeTelegram`. Focused release tests passed 41/41; exact-SHA GitHub Actions run `38754232193` passed for `c210be2`. The earlier docs commit `85439c8` and this fix are pushed. Recheck before release action.
- **External state recheck:** `gh release list --repo AffPapa/NeTelegram` returned no releases. Public `/downloads/` returned HTTP 200 `text/html`; visible page text says no build/download exists and links to source. No app version or release asset is advertised. No Site deployment was attempted.
- **Release preflight recheck:** on clean published commit `5c941ea`, `Scripts/build-release-candidate.sh --preflight-only` passed repo identity/remote SHA, Developer ID identity, Xcode/Swift, pinned Sparkle signing-key match, and TDLib presence checks. It stopped only at `notarytool history`: Keychain profile `NeTide-Notarization` is not present. No candidate files were created. A fresh protected `store-credentials` prompt is waiting in session `34383` at `Developer Apple ID:`.
- Public release state: `AffPapa/NeTelegram` has source, but no app GitHub Release/assets. Existing public Site `https://netelegram.iryadom.chatgpt.site` is v218 and has no app download; alpha/stable feeds are empty. The Site source/version is not app provenance.
- Acceptance: 56 cases: 3 passed, 46 partial, 7 not run. Synthetic 20-profile tests are not real multi-account validation. All available authorized accounts remaining active is a required product behavior at every release, not a stable-only feature.
- Current gates: owner-operated real login/read/send/quit/reopen is still deferred; no distribution bundle or release candidate has been signed/notarized. A protected `xcrun notarytool store-credentials NeTide-Notarization --team-id H6VGU2M6JD` prompt is waiting in Codex terminal session `34663` for direct Apple ID and app-specific-password entry; secrets must not pass through chat or tool arguments. Developer ID identities and the project Sparkle signing key are configured, but neither alone passes notarization. Distribution channel access is disabled per the user's choice; Terms §§1.3/1.4 and §3.3 remain unresolved. Never claim compatibility/stable while those gates are open.

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

- **Next product gate:** when the user is ready (login was explicitly deferred), use only `/private/tmp/NeTelegram-Dev.app`; enter credentials there, load chats, read one chat, send one user-approved test message, normal quit/reopen, confirm the same identity. No secrets or chat content in conversation. Do not repeat the request before the user resumes it. Fix only a reproduced P0.
- **Next independent release gate:** finish the visible protected `notarytool` prompt in session `34663`; verify only the sanitized success/error status, then run the release builder's credential preflight. Do not run the candidate builder until both product smoke and notary credential preflight pass.
- **After those gates:** freeze one exact published source SHA; run focused changed-surface checks and one exact-SHA Swift CI (plus native workflow only if native bundle inputs/lifecycle changed); build a separate release candidate; Developer ID + Hardened Runtime/minimal entitlements, inside-out signing, notarization Accepted, staple, Gatekeeper/quarantine install/reopen; freeze manifest, SBOM/NOTICE, hashes and assets; create a new immutable GitHub alpha release; download and verify public bytes; update the existing Site once from that manifest and validate anonymous download routes/feed. Do not rebuild app assets for a Site failure.
- `Scripts/build-release-candidate.sh` and Sparkle key routing are implemented. The builder has not produced a candidate. Do not repeat already passing release-tool contract suites unless their inputs change.
- **Coverage may remain partial for alpha:** 20 real authorized accounts and the 1/5/10/20 resource matrix are not required to make a narrow alpha claim, but all-active runtime behavior remains mandatory in the implementation. Do not ship an alpha that only keeps one selected plus a few background accounts; report exact real-account coverage and leave 20-account certification open until it is measured.
- **Not complete:** this plan does not constitute a build, account smoke, notarization, release, Site update, or compatibility PASS.
