# NeTelegram run log

## 2026-10-13 — Oversized TDLib updates fail closed

- App source commit: `6c6fff49d6c43746b3990de178b723d1eaf75172`.
- The C bridge measures the borrowed TDLib JSON before copying and rejects payloads above 16 MiB. The Swift queue rejects any single event larger than its configured byte capacity; the receive gateway reports the bound and prevents further sends instead of silently dropping an update.
- Local serial Swift suite: 136/136 passed. Exact-SHA [macOS CI](https://github.com/AffPapa/NeTelegram/actions/runs/38395900507) and [pinned TDLib/Dev.app workflow](https://github.com/AffPapa/NeTelegram/actions/runs/38395900428) passed.
- Not verified: real-account overload behavior, Instruments/RSS measurements, and a 20-account burst. No login or account data was used.

## 2026-10-13 — Safe unfinished-login removal published to development Site

- App source: `d57d569c08ca5273435fdb2e95a51629e1527df5`; GitHub docs/checkpoint HEAD before this entry: `8c43b2616e6668498fc4b1bbc89101d0267a3e94`.
- Site source commit: `7447d22eaf613b9c008734e1e883dbc480a8a934`; saved version 115: `appgprj_6acba85192e08191acdf7011928848cf~appgver_e4f6eff6cb308191906c8b63b2d7e682`; public deployment `appgdep_6ace186c4bc08191914b2f9361e1dd4e` succeeded.
- Site archive SHA-256: `0b9ff682c62f1d59fd406ee6356cb6389d8cab7fb9827ad2d53d92105be2da77`; Sites-reported content hash `sha256:a2f4e1d693a67fc615e34681adbd7aaf45dd644e2e5369e56ccf283b6a30ed75`.
- Anonymous verification: in-app browser rendered `/devlog/` with the new d57d569 entry and `/downloads/` with `NO RELEASE` and no download button. Read-only HTTPS fetched both stable and alpha XML feeds as valid empty RSS. `get_site` confirmed active, public, latest version 115.
- Route diagnosis: default local shell could not resolve the Sites Git hostname or public Site host; official helper succeeded with approved network access. Do not change Site origin or route publication through browser uploads.
- Limits: no app binary release, no actual Telegram login/profile close, no 20-account certification, no Developer ID/notarization, and no updater release.

## 2026-10-13 — Acceptance evidence and checkpoint routing corrected

- Updated the top-level acceptance summary to current app-source `d57d569c08ca5273435fdb2e95a51629e1527df5`, 134/134 local serial tests, exact-SHA CI and accountless native smoke.
- Marked older case evidence as commit-scoped historical snapshots. This prevents older test counts or local candidates from being mistaken for proof of the current source; all real-account and twenty-account claims remain open.
- Corrected the ambiguous stale repository-head field to `repo_head_before_checkpoint`; app-source, documentation, Site-source, saved version and deployment identities remain distinct.
- No Swift source changed; no app tests or rebuild were repeated for this documentation-only correction.

## 2026-10-13 — VoiceOver authorization-step announcements

- App source commit: `4478f967654b270cd78f71a5afe69f625491d38d`.
- Change: AppKit posts short, static announcements for phone, code, 2FA, email, registration, and QR steps. Copy is selected from typed TDLib state only; it does not include entered values. Repeats are suppressed per account, runtime generation, and step.
- Local verification: `swift test` passed 130/130 on Xcode 27.0 / Swift 6.4 / macOS 27 SDK, using a temporary SwiftPM module cache.
- Exact-SHA CI: Swift tests run `38387314803` passed; pinned TDLib/Dev.app build `38387315058` passed. CI assembled and verified Dev.app but did not launch it or run VoiceOver.
- Site: public v113 at `https://netelegram.iryadom.chatgpt.site`; anonymous `/devlog/` and `/downloads/` returned 200 `text/html`. Downloads continues to show no app release.
- Limits: no native VoiceOver walkthrough, real login, QR interaction, keyboard-only journey, RTL/IME, or signed release.


## 2026-10-13 — Active notification snapshot reconciliation

- App source commit: `dd11b9f38978870bf80509c239070d2570c7d8d4`.
- Change: `updateActiveNotifications` now re-enqueues routeable active snapshot entries after state reconciliation. Reconciliation is silent and uses existing privacy and stale-route checks.
- Local verification: Swift tests passed 130/130 on Xcode 27.0 / Swift 6.4 / macOS 27 SDK.
- Exact-SHA CI: macOS run `38388246897` and pinned TDLib/Dev.app run `38388246709` succeeded.
- Correction: public Site v113 and the Site source devlog actually ended at `e89265c`; the prior checkpoint’s claim that `4478f96` was visible publicly was wrong. Site v114 is now public. Anonymous curl confirms `/devlog/` 200 with both exact commits, `/downloads/` 200 without a release, and valid empty stable/alpha XML feeds. A first verifier had a boolean-expression error; the corrected raw-response check passed.
- Limits: no real Notification Center permission/account/tap/reconcile race, native VoiceOver, or signed release. Process inspection was blocked by macOS sandbox; the old candidate is from `ff3da44`, not `dd11b9f`.


## 2026-10-13 — Site v114 verification

- Site source commit: `9f7b2256db715fd83b90f51a5cf22374ab1d26c4`; saved version `appgprj_6acba85192e08191acdf7011928848cf~appgver_8f91acef31b48191b6fdcb39ab5ad7fb`; deployment `appgdep_6ace12db0d3881918a0b08d461c495c7` succeeded.
- Archive SHA-256: `3228b204d8e769eef7ebb51baf150bd7c52d2615f43a6d8ff06f3116a71dec08`; Sites content hash `sha256:8cfcb5561d0f39237bdb5f335ba3c5a60821c861ccfd60e5764b07270a8df3f3`.
- Anonymous checks: `/devlog/` 200 HTML with `4478f96` and `dd11b9f`; `/downloads/` 200 HTML with no-release state; stable and alpha update XML each 200 and parse as valid empty feeds.
- Verification correction: the first local boolean expression constructed a string before membership testing and falsely said commit markers were absent. A corrected verifier and raw response confirmed the deployment.


## 2026-10-13 — Safe removal of an unfinished local login

- App-source commit: `d57d569c08ca5273435fdb2e95a51629e1527df5`.
- Change: the Account menu now offers removal only for a profile without a verified Telegram identity. It writes a durable pending-removal marker, prevents later identity association/restoration, asks TDLib to close, then removes the route before deleting that profile’s keys/files. Failed Keychain, file, or catalogue cleanup retains a retryable marker; confirmed accounts are rejected.
- Local verification: serial Swift suite passed 134/134 on Xcode 27.0 / Swift 6.4 / macOS 27 SDK. Failure-injection tests cover pending restore exclusion, retry after file failure, preserving files after Keychain failure, and refusing verified identities.
- Exact-SHA CI: macOS run `38390951012` and pinned TDLib/Dev.app run `38390951049` succeeded for the app-source SHA above. The native workflow built and verified the arm64 Dev.app, launched its accountless first-run screen, captured a screenshot, and quit. It did not interact with the new removal item or close a real Telegram profile.
- Checkpoint correction: this audit found a stale `workspace.app_source_commit` and a `current_head_native_smoke` record tied to an older source. Those fields are now separated/labeled historical. No old local Dev.app was relaunched.
- Site: existing public v114 remains live; one factual devlog update for this commit is in progress. Downloads remain unavailable.
- Limits: no real login, real TDLib profile close, 20-account operation, Developer ID/notarization, updater, or stable release.
