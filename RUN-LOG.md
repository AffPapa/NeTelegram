# NeTelegram run log

## 2026-10-13 — Native smoke checkpoint wording corrected

- Re-read `.github/workflows/native-app.yml` and `Scripts/window-lifecycle-smoke.sh`, then checked the exact-source workflow artifact metadata. Workflow `38407466662` for app-source `816bbb4ab2a61817cc3da0780f47219b1f8f52e9` did launch the isolated Dev.app, capture a first-run screenshot, verify last-window close and same-PID LaunchServices reopen, and issue normal Cmd+Q.
- Corrected APP04, AUTH03, and `PROJECT-STATE.json`: the smoke used temporary CI Application Support and no account; it does not prove live TDLib, real login, 20-profile operation, Keychain persistence, or visual quality of the captured screenshot. The previous “did not launch” checkpoint sentence was wrong.

## 2026-10-13 — Site v123 deployed and anonymously checked

- Existing public Site project retained: `appgprj_6acba85192e08191acdf7011928848cf`; version 123 source `bbfa7c7df93f9bf2974291109a71f11ccaad80a4`, deployment `appgdep_6ace3a2734c881918019aefea91f33ee`, saved version `appgprj_6acba85192e08191acdf7011928848cf~appgver_4a7ee91928508191b97b4eb69d1e62ad`.
- Exact saved archive SHA-256: `23f329caf27bf679b3863498fe27da8693c99bd9c35e913df45d7208a2707c5b`; Sites-reported content hash `sha256:fff05212b572d4aebe8f9f0e6f2b98780828fceeb00ced58589d49a49e9ccc1e`.
- Anonymous TLS-verified checks: `/devlog/` 200 HTML with `04279b9`; `/downloads/` 200 HTML with `NO RELEASE` and no release-download URL; stable and alpha feeds 200 `text/xml` and parse as XML.
- No app binary was built, signed, or released for this test-only milestone.

## 2026-10-13 — APP16 critical update during queue shutdown

- App Swift source is unchanged at `816bbb4ab2a61817cc3da0780f47219b1f8f52e9`; test/evidence commits `12114c5` and `04279b967c8296a8c73719ce79030286dfe4570a` are on `main`.
- Extended the shutdown regression to fill the shared capacity, block a final `updateDeleteMessages` JSON update from the same client, allow the single already-received item through shutdown, and assert FIFO with the preceding authorization update plus rejection of later input. The test comment explicitly limits this to queue preservation; it is not a real expiry/TTL test.
- Targeted local test passed 1/1. Exact-SHA macOS CI [run 38409529115](https://github.com/AffPapa/NeTelegram/actions/runs/38409529115) passed for test/evidence commit `04279b967c8296a8c73719ce79030286dfe4570a`. No app rebuild was needed because Swift app source did not change.
- APP16 stays partial: no real TDLib receive worker, 20-client saturation, real TTL expiry, or runtime overload measurement. Site v122 remains live until v123 archive-backed deployment completes.

## 2026-10-13 — Oversized TDLib updates fail closed

- App source commit: `6c6fff49d6c43746b3990de178b723d1eaf75172`.
- The C bridge measures the borrowed TDLib JSON before copying and rejects payloads above 16 MiB. The Swift queue rejects any single event larger than its configured byte capacity; the receive gateway reports the bound and prevents further sends instead of silently dropping an update.
- Local serial Swift suite: 136/136 passed. Exact-SHA [macOS CI](https://github.com/AffPapa/NeTelegram/actions/runs/38395900507) and [pinned TDLib/Dev.app workflow](https://github.com/AffPapa/NeTelegram/actions/runs/38395900428) passed.
- Public development Site v117 deployed at https://netelegram.iryadom.chatgpt.site from Site source commit `fb9b464c8ae2cbfc687e261cdf3f23237a72152e`; anonymous checks returned 200 for the updated routes and empty stable feed.
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

## 2026-10-13 — NeTelegram name, bilingual search copy, and APP04 window lifecycle

- App-source SHA: `13625c702e6dbd5d14b2f6d7d2acbf210806a8f3`. Local serial Swift suite: 136/136 passed on Xcode 27.0 / Swift 6.4.
- Exact-source macOS CI: [run 38399172699](https://github.com/AffPapa/NeTelegram/actions/runs/38399172699); pinned TDLib/Dev.app lifecycle: [run 38399172724](https://github.com/AffPapa/NeTelegram/actions/runs/38399172724). Both passed. Accountless Dev.app closed its last titled app window while the same PID remained alive, LaunchServices reopened one window in that PID, and Cmd+Q exited. This does not prove background Telegram updates; no account was logged in.
- GitHub README pages now include detailed Russian and English descriptions, the observed RU/EN query wording, a clear “no download yet” answer, and the independent/no-direct-connection notice. Search wording was taken from current result phrasing; search volume and ranking were not measured. The GitHub repository short description remains a separate metadata field.
- Search wording cross-check: English result copy uses “unofficial Telegram client for macOS” (Fenixuz: https://github.com/Novagramorg/macOS) and “alternative client for Telegram for macOS” (ForkGram: https://forkgram.en.uptodown.com/mac). Russian result sample was noisy; “альтернативный клиент Telegram для macOS” appeared in a Mac app result (https://ru.uptodown.com/mac/internet/newreleases/2). These are observed phrases only, not volume/rank evidence. Avoid “Telegram alternative” without “client” because results also mean replacement messengers.
- Removed the obsolete current-name claim from the checked-in GitHub Site snapshot while preserving the current NeTelegram name. Existing historic build labels remain only as historical facts when needed.
- Site v118 published from `6a02f20f94d1bc460cfb2f39a3350b8033d0ad44` as `appgprj_6acba85192e08191acdf7011928848cf~appgver_9c707118acac81918c9a4f27d010aec4`; deployment `appgdep_6ace28a09f9c819193ded68a92048fd4` succeeded at https://netelegram.iryadom.chatgpt.site. Anonymous checks passed for home, features, roadmap, devlog, downloads, and stable feed. Downloads still say NO RELEASE. Local archive SHA-256: `74ab3f64766d8bc28baf0496404f9c6ffa9dbab5a8ac09e84c9be9cb0a492f2c`.
- CI diagnostic lessons: an early smoke counted the status-bar service window; the final check counts visible titled app windows and waits until the main window is shown before recording launch. Do not reuse failed run IDs as evidence.
- Open: §2.3 current display-title compatibility, single-account real login (user deferred), all-20 real account coverage, Developer ID/notarization/Gatekeeper/Sparkle, channel/sponsored-media compatibility, and a downloadable release.

## 2026-10-13 — APP02 injected Keychain startup faults

- App source/test commit: `2ba4ccf0e8d899a2da7e4e42dedd30cbb5dc9b01`; two targeted local tests passed: injected Keychain error propagates without fallback, and one stalled synthetic read does not prevent the other 19 profile startup attempts from finishing at scheduler parallelism 2.
- Exact-SHA [macOS CI run 38401445104](https://github.com/AffPapa/NeTelegram/actions/runs/38401445104) succeeded, including Apple Silicon Swift tests and JSON validation.
- These are injected operation/scheduler tests. They do not exercise system Keychain behavior, app-level account failure UI, real login, or 20 authorized sessions. APP02 remains partial; no application release.
- Public development Site v119 is live at https://netelegram.iryadom.chatgpt.site. Anonymous checks returned 200 with expected MIME for all eight pages and valid stable/alpha RSS feeds; `/downloads/` truthfully reports NO RELEASE. Bilingual devlog and no-direct-connection disclosure are present; no current Neridian brand remains on public routes.
- Next implementation slice: APP03 A→B→A presentation/account snapshot isolation, with same numeric chat ID across distinct accounts, topics, and drafts. Reuse existing APP04/APP02 evidence; do not rerun unchanged checks.

## 2026-10-13 — APP03 account-local conversation snapshot

- App source commit: `9a984aeb74ff84d54c9e4c23d64db43c6434882e`. `presentRuntime` captures an account/generation-bound snapshot of selected conversation and draft; the reopen path restores snapshot text only when account, generation, and typed conversation key still match.
- One targeted local test passed: same numeric chat ID in accounts A and B retains distinct forum topics and drafts across A→B→A; a mismatched generation is rejected. This is synthetic core coverage, not a 1000-switch or real GUI test.
- Exact-SHA [macOS CI run 38402873737](https://github.com/AffPapa/NeTelegram/actions/runs/38402873737) succeeded. Pinned TDLib/[Dev.app build run 38402873559](https://github.com/AffPapa/NeTelegram/actions/runs/38402873559) assembled and verified the arm64 bundle; it did not launch the app or test an account switch.
- Public Site v120 source `b4b9de7fde9f59d1ff850c49759413afc9ed5dd4`, saved version `appgprj_6acba85192e08191acdf7011928848cf~appgver_60ae63b9fa948191b4399d20f40c1951`, deployment `appgdep_6ace2e966b4c8191ac152ca6ed24b509`. Anonymous `/devlog/` returned 200 `text/html` with the exact source SHA and CI runs. `/downloads/` remains NO RELEASE.
- APP03 remains partial: 1000 transitions, real account GUI, and real runtime generation stability were not tested. No application release.

## 2026-10-13 — NeTelegram brand/SEO sync, APP03 1000-selection check, Site v121

- Current product name is **NeTelegram** across canonical runtime identity, GitHub About, bilingual README, and Site v121. GitHub About now contains a concise RU/EN description, points to the existing public Site, and has topics `telegram-client`, `macos`, `swift`, `appkit`, `tdlib`, `open-source`. The full repository README has English and Russian descriptions, natural observed search phrases, honest development/download status, and an explicit statement that NeTelegram has no direct relationship with Telegram.
- Qualitative live SERP review found wording such as «неофициальный клиент Telegram для macOS», «клиент Telegram для Mac», «альтернативный клиент Telegram для Mac/macOS», «приложение для Telegram на Mac», “unofficial Telegram client for macOS”, “alternative Telegram client for Mac”, and “native macOS Telegram client”. Search volume and rankings were not measured. See Telegram API Terms §2.3: https://core.telegram.org/api/terms; the chosen brand remains an app-title compatibility gate for release.
- App-source commit `2285792bd360b392c79e4fe9da70dd7d70b86be7` factors draft restoration into the same account/generation/typed-conversation policy used by AppKit. One local targeted synthetic test passed 1000 alternating selections; exact-source macOS CI [38404936494](https://github.com/AffPapa/NeTelegram/actions/runs/38404936494) and pinned TDLib/Dev.app build [38404936522](https://github.com/AffPapa/NeTelegram/actions/runs/38404936522) succeeded. The bundle workflow did not launch the app; the synthetic loop is not native UI, a real account, or 20-runtime certification. APP03 remains partial.
- Existing Site `appgprj_6acba85192e08191acdf7011928848cf` advanced once from v120 to v121. Source `98208c1042c06f64cd112f8894861cf7ddf7f802`, saved version `appgprj_6acba85192e08191acdf7011928848cf~appgver_769a13e3472c8191851a46d9a8e4823e`, deployment `appgdep_6ace333a26f88191b1fe8b6a4ba9c0ee`, URL https://netelegram.iryadom.chatgpt.site. Local archive SHA-256 `2697fcc6ce3df8ce63e720e59e4f5d8c382ac3d81e76ae3fb60f4bdc2c5e8a80`; Sites content hash `sha256:d1d6a32d6453260a8c71f6404345683f7d197de355cb4a4d324478dc05aa1360`.
- Live anonymous validation returned 200 on all 8 HTML routes (`text/html`) and both alpha/stable feeds (`text/xml`). Current app SHA, title, bilingual SEO phrases, non-affiliation disclosure, and APP03 devlog are present; downloads remain NO RELEASE. Site `dist/` was synchronized into the app mono-repo's `website/dist/` mirror. The exact NeTelegram Site source helper was used; sandbox DNS denied its host once and the same helper succeeded with approved network access. No alternate Site, app version, or browser upload was created.
- Limitations: no live account/UI switch, no 20 authorized accounts, no signed/notarized application/download, no search-volume data. A stale divergent checkout still carries historical Neridian checkpoint text; preserve it, and use canonical `/private/tmp/netelegram-cli-work` for current state.


## 2026-10-13 — APP25 login-item policy and OPS02 source scan

- App-source commit `816bbb4ab2a61817cc3da0780f47219b1f8f52e9` adds a shared `LoginItemPreferencePolicy` for the four observed `SMAppService.mainApp` states and the user's requested enabled/disabled state. Registration still occurs only after explicit opt-in; disabling requests unregister; a status that does not confirm the operation is reported as unresolved.
- Targeted local command: `CLANG_MODULE_CACHE_PATH=/private/tmp/netelegram-clang-module-cache SWIFTPM_MODULECACHE_OVERRIDE=/private/tmp/netelegram-swift-module-cache swift test --no-parallel --jobs 2 --scratch-path /private/tmp/netelegram-app25-policy-check --filter loginItemPreferencePolicyOnlyRegistersAfterExplicitOptIn`; 1/1 passed on Xcode 27.0 / Swift 6.4. Exact-source [macOS CI run 38407467618](https://github.com/AffPapa/NeTelegram/actions/runs/38407467618) and [pinned TDLib/Dev.app run 38407466662](https://github.com/AffPapa/NeTelegram/actions/runs/38407466662) succeeded. The native workflow built and verified an arm64 bundle but did not launch it. Real Login Items persistence/removal remains untested; APP25 is partial.
- Gitleaks 8.30.1 scanned 241 commits (~5.15 MB), the current source tree (~218.91 MB), and saved Site v121/v122 archives (184,529 / 187,375 bytes); no known secret-pattern matches. A 99-file tracked-path inventory found no account sessions, databases, raw logs, certificates, or profile data. This is scanner and filename evidence, not a guarantee against arbitrary sensitive content. OPS02 stays partial pending a release-time asset/receipt allowlist review.
- Public Site v122 is live: source `c0d0b70c25a9f5517ec9a55a87e5f885bda34a5b`, saved version `appgprj_6acba85192e08191acdf7011928848cf~appgver_67852fdff6788191a59e7b785d19b7d8`, deployment `appgdep_6ace36ed4f988191aad661fa4bb63ff6`. Local archive SHA-256 `bab59f286f6fcfa40fcf03a91607597d290cd77773d05c9ec84bdb2283e4435e`; Sites content hash `sha256:b3f0e2f29a37f01e86d47571b48c3061d761a86630caca3270bc4436dc4fe19b`.
- Anonymous validation returned 200 for all 8 HTML pages and both valid empty XML feeds, with expected MIME. The current app-source SHA is on homepage/features/roadmap/devlog. The download route still reports no release.

## 2026-10-13 — Release preflight correction

- Evidence: read-only `security find-identity -v -p codesigning` exited 0 and reported 0 valid identities / 0 Developer ID Application identities. Public GitHub REST releases endpoint returned an empty list.
- Correction: supersedes the stale REL03 statement that four identities (including two Developer ID identities) were available. No key material or notary credentials were read.
- Result: release remains unavailable; no signed/notarized build, Gatekeeper result, or public application download is claimed.
- Also reconciled public Site state to v123; its download page still correctly says NO RELEASE.
