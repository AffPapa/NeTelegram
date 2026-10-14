## 2026-10-14 — APP07 transient push notification and v171 devlog

- App source is exact commit `aab6a4a2df950ae61de4d69b5f67a2b251e6d8a2` on `AffPapa/NeTelegram:main`. `notificationTypeNewPushMessage` is now treated as a temporary state: live updates preserve the existing notification/route; active-snapshot reconciliation retains its prior account/chat/topic route until TDLib supplies the full `NewMessage`. No main-topic route is inferred.
- Focused local regression passed 1/1. Full serial Swift suite passed 164/164 in 0.459 s on arm64e / Xcode 27 / Swift 6.4. `Scripts/dev-app.sh` built the sole canonical `/private/tmp/NeTelegram-Dev.app` from exact source in 5.24 s; BuildInfo, source fingerprint and build record agree, executable SHA-256 is `d218bf00ca886ee9fc32b4621221d6fea963dbb0c4bd7576756565deceaf6360`, pinned TDJSON SHA-256 is `9b1ba46d15f410d687aeb355bcd6bbe4e5e172bfc55ab38abc3e68d7842efdc1`, and ad-hoc `codesign --verify --deep --strict` passed. CUA showed title `NeTelegram · dev aab6a4a` and the clean login screen; no credentials or accounts were used.
- Exact-source hosted run [38505482508](https://github.com/AffPapa/NeTelegram/actions/runs/38505482508) passed the filtered runner probe and compiled the test bundle on macOS 15 / Xcode 16.4 / Swift 6.1.2, but after `Build complete! (0.39s)` the full test process emitted no `Test run started` through 4m24. It was cancelled; no hosted full-suite PASS. The prior run 38505192226 was cancelled when the implementation was expanded to cover active-snapshot reconciliation, so its result is not acceptance evidence. Diagnose the Xcode 16.4 / Swift 6.1.2 runner startup before any unchanged retry; local Xcode 27 PASS does not substitute for hosted coverage.
- Public Site v171 retained its existing project and public URL. Site-source commit `07256341ff02f240fddf21d758a3a2d1b9250dc0`; saved version `appgprj_6acba85192e08191acdf7011928848cf~appgver_62ec1356376c8191a0bb3ffac596b98c`; deployment `appgdep_6acef6eb8bb88191b69865e8e9dc1e2b` succeeded. Archive SHA-256 `fe85119b2c702de70ee8788ace4ca662f5c43e3b5c44fa2ec6feccd61a1917d5`; Sites saved content hash `sha256:efd2f98d46090cacde5b75379765a63e0c8279c11c5bd6c9a46c8fa190e225f5` (440,320 bytes, 14 files). Anonymous in-app browser confirmed the bilingual `/devlog/` entry and `/downloads/` still has no build or download link. Both archived feeds parse as RSS; direct public XML navigation was blocked by the browser client and shell DNS lookup failed, so this turn does not claim fresh public feed MIME validation.
- Release/downloads were not changed. No actual notification center delivery, Telegram account, 20-runtime operation, Developer ID/notarization, Gatekeeper or user release was verified.
- Efficiency note: the first notification patch handled the live update but missed the snapshot path. It was detected in review, and the intermediate CI was cancelled before using it as evidence; the final source commit includes both paths. Check every producer/reconciliation path before dispatching exact-source CI.

## 2026-10-14 — AUTH05 development milestone published to Site v170

- Existing public Site `appgprj_6acba85192e08191acdf7011928848cf` advanced from v169 to v170. Site source commit `272e257fbe70e6d7de3fb19faff69f78c9cfcdca`; saved version `appgprj_6acba85192e08191acdf7011928848cf~appgver_9497e7c9a8b481918d05937c8ee77735`; public deployment `appgdep_6acee10806988191b7212e17add857a3`.
- Local archive: `/private/tmp/netelegram-site-20261014-fa80d5a.tar.gz`, SHA-256 `b72952526f130f624d4bd45504efb6545b72bbf598d22c02d3a198b3e40107c4`; Sites saved content hash `sha256:fa75c32cdb9949dc2988d74dbb9865f5f9d45a6edc8ba5e8336ff0cc8226cc58` (440320 bytes, 14 files).
- `get_site` confirmed active/public v170 and successful deployment. Anonymous cache-busted HTTPS `/devlog/?verify=fa80d5a` and the accessibility tree showed the bilingual AUTH05 entry and its exact CI/native links. The first browser reload showed cached v169; a query-string refresh resolved it. Site downloads were not altered; no app binary is advertised.
- App checkpoint before this deployment receipt: `dde726e` (app source `fa80d5a`). Site push used only the existing official Sites helper and temporary credential via hidden stdin; no credential was stored in the repository.

## 2026-10-14 — AUTH05 country search verified in the canonical Dev.app

- App source commit: `fa80d5a5f77b1fecf583754f3fe5cf69209be75b`. Search now matches localized and English names, region codes, and calling codes; the currently selected country remains visible as a separate marked option while filtering. Selecting a result retains its exact region, including for shared `+1` calling codes.
- Focused regression passed 1/1. Exact-source local serial Swift suite passed 163/163 in 0.426s on arm64e / Xcode 27.0 / Swift 6.4. Hosted macOS CI [38497467214](https://github.com/AffPapa/NeTelegram/actions/runs/38497467214) passed its runner probe, then was cancelled at the five-minute job limit during the full suite; no hosted suite result is claimed.
- Pinned TDLib arm64 Dev.app workflow [38497467210](https://github.com/AffPapa/NeTelegram/actions/runs/38497467210) passed. The sole canonical local bundle `/private/tmp/NeTelegram-Dev.app` was rebuilt from this source in 0.18s; ad-hoc code signature verification passed. CUA confirmed search `Canada` returns `🇨🇦 Канада +1` and selecting it updates the control. No phone number or code was entered.
- Site v169 remains live until one batched AUTH05 development update is deployed. No app release, real Telegram login, real-account coverage, or 20-runtime certification occurred.
- Speed guard: one source commit, one canonical bundle, focused test plus one exact-source local full suite after hosted cancellation, one native workflow; no unchanged CI retry or duplicate app launch.

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

## 2026-10-13 — APP01 restore/startup Core composition regression

- Change: added `twentyProfileRestoreStartupRegistrationSurvivesStallFailureRetryAndSelectionChanges`, combining the restore plan, two-at-a-time startup scheduler, runtime route registration, a stalled open, a rejected first request, fresh-generation retry, 20 routed update identities, and A→B→A presentation selection.
- Verification: focused local Swift test passed 1/1 on Xcode 27.0 / Swift 6.4.
- Limits: synthetic Core-only contracts; it does not invoke AppDelegate restore/startup functions, TDLib, real Telegram accounts, all-20 network sessions, or performance measurement. APP01 remains partial. Hosted validation: exact-SHA macOS CI 38412386934 passed on commit `5879143cc420cb0047606d099aa49810a609060e`.

## 2026-10-13 — NeTelegram landing redesign, public Site v126

- The official [Telegram homepage](https://telegram.org/) was used as an information-architecture reference: concise navigation, one clear first-screen message, direct platform/status paths, and short capability groupings. Text, identity, and the accessible SVG diagram are original NeTelegram work; no Telegram logo or app screenshot was reused.
- App repository commits `4d90d76` and `d63250d` update only the website assets and factual devlog. Both commits are pushed to `AffPapa/NeTelegram` `main`. The CI endpoint has no run for the documentation-only final commit; HTML parsing/internal-link checks, duplicate-ID checks, CSS brace/reduced-motion checks and `git diff --check` passed locally.
- Site v125 was deployed once for public visual review. The screenshot exposed an oversized hero heading wrapping into five lines; the layout was corrected in v126 and v125 is superseded, not edited. No app binary/version was created.
- Final Site: existing project `appgprj_6acba85192e08191acdf7011928848cf`, public version 126, Site source commit `6ce2199219b8adb692afb6b21780a42c436b0314`, app repo doc commit `d63250d8c3a4805144e0498d358d2608b0751a07`, saved version `appgprj_6acba85192e08191acdf7011928848cf~appgver_853bf475c108819182b4c3e60068279b`, deployment `appgdep_6ace41cb6cb081918195dc7caef7ee8e`; URL https://netelegram.iryadom.chatgpt.site.
- Exact archive `/private/tmp/netelegram-site-v126.tar.gz`: 280,158 local bytes; local SHA-256 `6683e8cd6f18344de07c3306b116943816a12c08ccffb15dbc0d3919cbe8dc7e`; Sites saved archive hash `sha256:0fa30ac22043981779ac8fdb34aeb4efdc8e9714a7213a807c876df0017ef276`, 471,040 bytes / 14 files.
- Public Playwright check returned 200 `text/html` for `/`, `/features/`, `/downloads/`, `/changelog/`, `/devlog/`, `/roadmap/`, `/privacy/`, `/source/`; both `/updates/stable.xml` and `/updates/alpha.xml` returned 200 `text/xml`. Final desktop (1440px) and mobile (375px) screenshots inspected: no horizontal overflow; headline height 119px / 74px; console 0 errors and warnings. No release asset exists; download status remains unavailable.
- Remaining app coverage is unchanged: no real account login, no 20 authorized runtime certification, no Developer ID identity or signed/notarized application. Next implementation work: bridge the APP01 Core composition test to the production AppDelegate restore/startup path.

## 2026-10-13 — APP01 startup-selection seam and Site v127

- App-source commit `62a75087e8c37ff07fa327613ff765f07c1d229a` adds `AccountRestorePlanner.pendingStartupProfiles` and calls it from `AppDelegate.restoreProfiles`. It preserves candidate order and excludes only account UUIDs with an existing runtime or startup task.
- Focused local Swift tests passed 2/2 on Xcode 27.0 / Swift 6.4: all 20 free candidates remain eligible; when one is running and one is starting exactly 18 remain. Exact-SHA [macOS CI run 38415556054](https://github.com/AffPapa/NeTelegram/actions/runs/38415556054) passed. This is a Core seam regression, not an AppDelegate execution harness: it does not create TDLib clients, read Keychain/storage, use real Telegram sessions, or measure 20-runtime load. APP01 remains partial.
- Updated the existing public Site project to v127: Site source `f1ffa1f9eff05c14f85bbd34b635733586f39511`; app-source commit `62a75087e8c37ff07fa327613ff765f07c1d229a`; saved version `appgprj_6acba85192e08191acdf7011928848cf~appgver_fe02914dc55081918588abbba3ce05a7`; deployment `appgdep_6ace43d1a9f8819187cf9829a862cb6f`; URL https://netelegram.iryadom.chatgpt.site.
- Exact archive `/private/tmp/netelegram-site-v127.tar.gz`: local SHA-256 `4fa34c21cd6a90bd534d01003e5b081ec206c5b161783ceee5219715ea7f281a`, 280,619 bytes. Sites saved content hash `sha256:119965791b77cc60f3c8d245e70f870b2c378314c33ba40e74fc43cbd67314ce`, 471,040 bytes / 14 files.
- Public check returned 200 `text/html` on all eight pages and 200 `text/xml` for stable/alpha updater feeds. Current APP01 entry appears on homepage/devlog; downloads still say NO RELEASE. Mobile 375px has no overflow, console has 0 errors/warnings. Final landing screenshot/desktop visual QA is recorded at v126; v127 changes only milestone copy and labels.

## 2026-10-13 — Site v128 stale asset cleanup

- The Telegram-inspired landing design was already complete; no second redesign was started. The official site's concise hero, direct app routes and benefit grid are structural references only. NeTelegram already has a short RU-first hero, scoped feature cards, explicit download status, product pages and an independence note.
- Removed two unreferenced old `Neridian Dev` PNG captures from the Site static assets. Static-source scan found no `Neridian` branding in served HTML/CSS/XML; the packaged archive excluded both assets (44 archive members checked).
- Existing public Site https://netelegram.iryadom.chatgpt.site was saved as v128 from `bcf5b46502c04681d20ef20eb3193d4384a7cec3` and deployment `appgdep_6ace458edd8081919c27948f7f12730b` returned `succeeded`. App source remained `62a75087e8c37ff07fa327613ff765f07c1d229a`. Archive `/private/tmp/netelegram-site-v128.tar.gz`: SHA-256 `759cfd6a80e0f96013e661f73439eed56dd5442eac69e38bdf8479f37cbdcf37`, 51,649 local bytes; Sites content hash `sha256:d02292ba21045dcd3b4fa03a301ec782cf9a7766d3747bafa4d682109fce7ae7`, 12 files / 215,040 bytes.
- Direct public HTTP fetch was unavailable because this environment could not resolve the Site hostname; the successful Sites deployment response and archive checks are recorded, but they do not constitute a route-level HTTP check for v128.

## 2026-10-13 — APP01 production enqueue dispatch and Site v129

- App-source commit `6434b101b8bd7124321858e79beb8535536b1aca` adds synchronous `AccountRestorePlanner.enqueueStartupProfiles`, now used directly by AppDelegate. The callback hands each eligible profile to the bounded scheduler without awaiting an earlier auth/network flow.
- Three focused local tests passed 3/3. Full exact-SHA [macOS CI 38417637060](https://github.com/AffPapa/NeTelegram/actions/runs/38417637060) and [pinned TDLib/Dev.app workflow 38417637092](https://github.com/AffPapa/NeTelegram/actions/runs/38417637092) passed for `6434b101b8bd7124321858e79beb8535536b1aca`. The native workflow built pinned TDLib and ran an isolated Dev.app window-lifecycle smoke: launch; close last window with same PID alive; reopen via LaunchServices in same PID; Cmd+Q. Screenshot captured but not visually reviewed; no account was entered.
- Public Site v129 uses source `3d8768a41c35c2a58155af796fdce93e1742ff59`, deployment `appgdep_6ace47b7829481919509682da8984d45`, version `appgprj_6acba85192e08191acdf7011928848cf~appgver_06de39ff88d481919aa752aa7254b159` at https://netelegram.iryadom.chatgpt.site. Devlog now has RU/EN exact-SHA evidence. Archive SHA-256 `4a67fa0b8983f984b12aa6452d25ca8a93f7e94894bb9ed51d79c46b0df60acf`, local 52,273 bytes; Sites content hash `sha256:1405033d04e1eb84b9ad7f93fb398b02b777c5176b642c6b4becdd45c91c717a`, 12 files / 225,280 bytes.
- No real Telegram account, twenty real runtimes, performance, Developer ID signature, notarization, Gatekeeper or app download was certified. Direct Site HTTP fetch remains blocked by DNS from this environment; Sites deployment succeeded but this is not a route-level verification.


## 2026-10-13 — NeTelegram Site v130 landing clarity pass

- Reference research: official telegram.org uses language/platform navigation, a concise product hero, benefit blocks and grouped informational links. Adapted only its information hierarchy; kept NeTelegram’s original editorial visual system and did not reuse Telegram marks, copy, or assets.
- Site source commit: `eb33a39823a068d5405b2d1792508dcb41254467`; public Site v130 saved as `appgprj_6acba85192e08191acdf7011928848cf~appgver_fbc448b84be881918f54b53ea22254bd`; deployment `appgdep_6ace4a5da9648191ba9e6ada4a9cf801` succeeded.
- Changes: replaced the multiple-profile/“20” hero drawing with an original abstract single-window illustration; made the conceptual/non-screenshot status explicit; simplified internal jargon; added a header EN link to the existing English overview; refreshed homepage and features evidence to app-source `6434b10` and exact CI/native run links. No download CTA or release claim added.
- Local checks: HTMLParser/anchor checks passed for homepage and features; `git diff --check` passed; stale old commit/run strings absent from the two edited pages. Public browser tab was refreshed and its accessibility tree confirmed the new content and version. Sites reported successful public deployment. Direct web-fetch tool could not access the hostname; no raw HTTP status claim.
- Archive: local SHA-256 `b3e2115a0d32da9cdf66015ca9ea66848f5161c20ab50a88a01e07157630054c`, 52,152 bytes; Sites reports content hash `sha256:2bccaef60fb35a85cff28b9ee35d8693eca15e6e430569de09bde439e30a7760`, 12 files / 225,280 bytes.
- Next: planned SecretsStore backend injection; no Telegram session entered and no 20 authorized runtimes measured.


## 2026-10-13 — SecretsStore Keychain backend injection and Site v132

- App-source commit: `3934bd21bc563fc8a0cc9b901a3650dd1b3cbd15`. `SecretsStore` now delegates typed read/add/update/delete operations to an immutable per-instance `KeychainItemBackend`; production default stays on Security.framework.
- Local verification: five focused tests passed on Xcode 27.0 / Swift 6.4 using an in-memory backend. They exercise real `SecretsStore` CRUD/policy methods for fail-closed read errors, explicit not-found creation, read-only no-create, API-hash update error without add fallback, and account-scoped deletion. No real Keychain was touched; system Keychain ACL and lock/unlock remain unverified.
- Exact-SHA macOS CI `38420552764` succeeded. Pinned TDLib/Dev.app run `38420551856` succeeded: dependency build and isolated arm64 app assembly/verification passed. It did not perform window interaction or account login.
- Site entries v131/v132: v131 published the new Keychain milestone. A cross-page verification caught `/features/` still referring to the older `6434b10`; corrected to current `3934bd2` in v132. This correction is recorded so resume checks the whole active route set once before finalizing, and does not treat history entries as current status.
- Site v132 source: `6302d3a84904c013ee38039bcdd332fe1987a824`; saved version `appgprj_6acba85192e08191acdf7011928848cf~appgver_288dc25fd4f4819185a89c65ddf837e3`; deployment `appgdep_6ace4cdaba7881919bc3cc02e5216327` succeeded. Local archive SHA-256 `757d336e4f5f69d5e82534bafa3e00cf743abf605e7277cd630c561a9314e1ed` (52,645 bytes); Sites hash `sha256:90846368dd019fc5a7969551ae1a0aa34b67cb9ee9daba59b240e998e2901a37` (12 files / 225,280 bytes). Refreshed browser accessibility trees verified new homepage, `/features/` and links. Direct web fetch remains unavailable.
- Release/account limits remain: no real Telegram login, no 20 authorized-runtime certification, Developer ID/notarized app and public downloads not available.

## 2026-10-13 — APP02 per-profile storage preparation and NeTelegram Site v137

- App source `26abae365b4eec54882ae69cc1274e20ddabb276` adds production-used per-profile storage preparation before TDLib runtime creation. Two focused tests passed; exact-SHA CI run [38425731506](https://github.com/AffPapa/NeTelegram/actions/runs/38425731506) and pinned TDLib/Dev.app build run [38425731851](https://github.com/AffPapa/NeTelegram/actions/runs/38425731851) passed. The latter assembled an arm64 Dev.app but did not launch the GUI or log in. APP02 remains partial; real Keychain, Telegram login, and 20 authorized sessions are not verified.
- Landing review against [telegram.org](https://telegram.org) found the existing NeTelegram hierarchy already communicates the product clearly: concise introduction, explicit no-download state, evidence-labelled features, direct navigation, and an original concept SVG. No additional illustration or broad redesign was justified. Branding and disclaimer remain independent and factual.
- Published Site v137 from source `775fee7bc71391ba90a5976492542128e1b16044`; saved version `appgprj_6acba85192e08191acdf7011928848cf~appgver_04790af39c4c8191af0e2d10eeff20be`; deployment `appgdep_6ace570e7e6481918128a73c93c1e559` succeeded at https://netelegram.iryadom.chatgpt.site. Public `/devlog/?v=137` and both restored screenshot assets opened; browser identified each PNG as 1024×768. The asset audit caught two historical image references missing from v136; both were restored before v137.
- Site archive: `sha256:e33b7240ce7799f65b72be5e163345865cf11b609322444c2779ae06a98ff767` (15 files / 491,520 Sites-reported bytes); local saved archive `/private/tmp/netelegram-site-v137-restored-images.tar`, SHA-256 `6671753a0140be6bafe2d30da674e5ff05d9e771f193103f71b351c66ea671f7`, 285,875 bytes. App repo `website/dist/` was synchronized to the v137 Site output.
- Next: continue from a distinct acceptance gap; do not repeat APP02/Site v137 checks without changed input. User deferred real login. No signed app release or twenty-account certification.


## 2026-10-13 — Shared NeTelegram site template and Site v141

- Rebuilt the existing public Site using `website/build_site.py`, one shared shell, route metadata in `website/content/*.json`, and independent HTML content fragments. Generated output remains static HTML/CSS with no client-side framework or JavaScript dependency. Added a native `<details>` mobile navigation, active route state, canonical and Open Graph metadata, shared footer, and a route validator.
- The v138 first pass exposed a dark status pill and the v140 devlog screenshot showed horizontal overflow. Both were corrected in the Site source; the final public rendering is Site v141. The public Site remains the same project and hostname.
- Focused validation passed: all eight routes have one H1, three consistent nav regions, active state, canonical metadata, existing local links and required assets; `git diff --check` passed. Public browser screenshots visually checked home, downloads and the dense devlog. The download page continues to state NO RELEASE and contains no fake download action.
- Site source: `4f99890bb6e01872e0e13dc02f975981c103abd7`; saved version `appgprj_6acba85192e08191acdf7011928848cf~appgver_89adc85509388191a024b0ec32faf360`; deployment `appgdep_6ace5c143c2c819182fe7243ce9a7c42` succeeded at https://netelegram.iryadom.chatgpt.site. Archive SHA-256 `390ea6353ec63a6c6bc319adb943282d5e77aec22d8c0faa49d0cca8d802b16d`; Sites content hash `sha256:157432c3b19cf4bfabfe1f85a0c3aa951d09305779300996f8b99885674c82bb` (15 files / 522,240 Sites-reported bytes).
- The mirror, generator, content source and validator are synchronized under the app repository's `website/`; app-source code and identity were not changed. Next: commit and push the docs/mirror checkpoint, then return to a distinct app acceptance gap. User login remains deferred; real-account/20-runtime proof and signed release remain open.


## 2026-10-13 — APP14 identity gate, Site v144, and checkpoint sync

- App source `14565217d47645248390853f1d7a7e495c3270dd` implements identity-bound local profile state: verified Telegram user ID gates private-state hydration, `getMe` is correlated by `@extra`, and mismatched identity closes that runtime. Two focused local tests passed. Exact-source [macOS CI 38431733861](https://github.com/AffPapa/NeTelegram/actions/runs/38431733861) and [pinned TDLib/Dev.app workflow 38431733910](https://github.com/AffPapa/NeTelegram/actions/runs/38431733910) passed. Real account revocation/reauth and 20 authorized runtimes remain untested; APP14 remains partial.
- Public Site v144 is live at https://netelegram.iryadom.chatgpt.site from source `dc015ddca81330db297f13d4289cf1c40a43faca`; deployment `appgdep_6ace60f0033081918e279cc45c848e65`, saved version `appgprj_6acba85192e08191baff6d10d81d5e71`. Sites archive hash `sha256:98081fb347d51b72a87a4ac3804c31e9d090195265f46772901d0042c584c422`, reported 522,240 bytes. Public devlog links the exact passing workflows. Local validator passes all eight routes. Public widths: 390px viewport → 375px document; 1440px viewport → 1425px document. No app download or release is available.
- Synchronized the v144 static site source and generated output into `website/`; updated APP14/site evidence and checkpoint pointers. Checkpoint commit `378cf388b59c1aba25b1a17f43dbd4f38aa1feb6` was pushed to `origin/main` after the sandbox DNS restriction was cleared for the authorized Git operation. No credentials, keys, or account data were recorded.

## 2026-10-14 — Shared Site design v145 and APP15 shutdown barrier

- Reworked the Site's visual system once for all eight static routes. `website/site.css` is now the editable design source; `build_site.py` copies it to generated `dist/site.css` alongside the shared HTML shell. `website/README.md` records the single-file restyle workflow. Existing route content remains separate; the home illustration and truthful no-download state are preserved. Static generation and `validate_site.py` passed. Local browser checks covered all eight routes at 390px (document width 375px, one H1 each); desktop home/devlog remained within 1425px at a 1440px viewport. Screenshot capture timed out in Playwright while waiting for fonts, so no screenshot visual PASS is claimed.
- Public Site v145: source `6fa7d210cad42c6407c46c5b422f22572cb201eb`, deployment `appgdep_6ace66bb8fb88191a1ee9f1dc6ac04ac`, version ID `appgprj_6acba85192e08191baff6d10d81d5e71~appgver_452c78e881208191bfdcf82e4edcfb20`. Source archive byte SHA-256 `4bd0febc96a2e971b10902349f139bcbb3bd474a547045fa47f97870a620078e` (286,415 bytes); Sites stored content hash `sha256:ee6e0d34cdfdc0aed9c9293900e23ba5111ca9036227dbc63e0ae32b7765b471`. Deployment returned succeeded at https://netelegram.iryadom.chatgpt.site.
- APP15 adds `RuntimeShutdownCoordinator` to track the expected client IDs separately from ordinary logout closes. Receiver/reducer drain is gated until each expected client reports `authorizationStateClosed`; unknown/duplicate acknowledgements cannot satisfy the barrier. A rejected close cancels quit and existing lifecycle bookkeeping waits for already-accepted closes.
- The first targeted Swift run correctly exposed compile errors because Swift Testing `#expect` cannot wrap mutating calls. Assertions were changed to evaluate into local variables. The rerun passed both focused tests. Exact-SHA macOS CI [38437898571](https://github.com/AffPapa/NeTelegram/actions/runs/38437898571) passed 150/150 tests on `256caf4faea294cddf4dd4e168cc2b64bd18a3d8`. Pinned TDLib/arm64 Dev.app workflow [38437335165](https://github.com/AffPapa/NeTelegram/actions/runs/38437335165) passed for product-code commit `15cb93b63c1654f256403b793ff05995a4907a09` (the later `256caf4` change only fixes test assertions); its accountless GUI smoke verified last-window close, LaunchServices reopen in the same PID, one-window state and normal quit. APP15 and APP04 remain partial for real authorized-account behavior.
- Updated the Site devlog with the exact test/workflow scope and deployed public Site v146: source `240412d258b98c19e3de876d60bf996eb352bbde`, deployment `appgdep_6ace695c756881918f8d2efde416ab90`, version ID `appgprj_6acba85192e08191acdf7011928848cf~appgver_d6ca329e03a481918117d1b7745327d4`. Source archive byte SHA-256 `4496f8195bdcc32e502725d83b75c5b820bb608cdf8f581b2bfbc94ffd0bc113` (286,941 bytes); Sites stored content hash `sha256:d53b0004b0e3002ba3a99cdc4de6cf034fcfe8ae9dfe5d096ece5f1f89fba702`. Public v146 `/devlog/` and `/downloads/` returned HTTP 200; both fit 390px (375px document width), one H1. The stylesheet returned `text/css`, 23,814 bytes, SHA-256 `a1154df7cc9c9a71b3a4892046de059655767eb4fb6d204ee7d71c3eb81115b1`. Downloads show no ZIP/DMG/release links.
- Fresh local signing-identity count: 0 valid code-signing identities, 0 Developer ID Application identities. Notary profile was not inspected. Real Telegram login remains user-deferred; no authorized 20-account quit, stable app, signing, notarization, or unresolved Telegram compatibility gate is claimed closed.

## 2026-10-13 — APP16 pipeline evidence and Site v147 checkpoint

- App-source `0fc9e8604a851ce8ab2968f5b2623a1417a7e350` adds integrated synthetic coverage for the common TDLib receive pipeline: 20 routes, one held callback while 19 lanes progress, bounded receive backpressure, and ordered accepted-event drain during shutdown. Two focused tests and the full local Swift suite passed (151/151, Xcode 27.0 / Swift 6.4). Independent read-only review confirmed the explicit callback-entered/drain-requested handshake is deterministic.
- Fresh GitHub API access failed during this checkpoint. Exact-SHA macOS CI run `38440068849` therefore has no established current terminal result; do not report PASS, failure, or pending. Exact-SHA pinned TDLib/Dev.app run `38440068795` was cancelled before any steps and provides no native-build evidence. Earlier accountless lifecycle smoke remains tied to product-code commit `15cb93b63c1654f256403b793ff05995a4907a09`.
- Existing shared responsive site design remains a single stylesheet and shared shell across all eight routes; no page-by-page redesign or app binary was added in v147. Public Site v147 uses source `a445eedc691d66943746781ad13384dd89304050`, saved version `appgprj_6acba85192e08191acdf7011928848cf~appgver_cbd5c1d62f088191bb98de8b500ac9d7`, deployment `appgdep_6ace70fe25388191816150f1949f6d64`, at https://netelegram.iryadom.chatgpt.site. Archive SHA-256 `19729a5a2921eff625b05e87c03b9a7c50752a9655d63973beb09eafb5ba6186` (286,675 bytes); Sites content hash `sha256:4c9685a0fab6ac72c5fccfae8683683edc693465af704ef18c15f67982861ffd`.
- Anonymous browser rendered the homepage, `/devlog/`, and `/downloads/` at 390px; checked pages had 375px document width. Devlog shows APP16 and local 151/151 while distinguishing unverified hosted CI and canceled native workflow. Downloads have no ZIP/DMG or GitHub-release link and state no application release. Existing all-eight-route validator/design evidence from v145 remains applicable because shared shell/CSS did not change.
- No real Telegram login, authorized 20-runtime operation, performance certification, Developer ID/notarization, or compatibility gate is claimed complete. User deferred login. Do not repeat APP16/site checks without changed inputs.

## 2026-10-13 — APP26 claim aligned to dispatch evidence

- A read-only review at repository checkpoint `ad1a81787a8cf9948eb7d6eaed00873370c37540` confirmed `LocalAccountRuntime.send` and `.close` share `RuntimeCommandGate`, with no direct gateway-send bypass. The gate guarantees synchronous call/dispatch ordering and reopens after an immediate close enqueue rejection.
- Corrected APP26 acceptance wording: it does not wait for a remote TDLib/Telegram response to each command before requesting close. This keeps the claim aligned with what source and deterministic tests prove. APP26 remains partial because exact-HEAD native lifecycle and real multi-account quit are not verified.
- No code changed and no tests were rerun; the existing deterministic gate tests are the evidence for this documentation correction. The exact-HEAD native workflow was canceled before steps; the previously passed accountless GUI smoke belongs to an older app-source commit.

## 2026-10-13 — Sign-in affiliation text corrected

- App-source commit `86855e4599ae4dc9d00274c07331617ddc5b3684` removes contradictory sign-in wording that called NeTelegram part of the Telegram ecosystem while also denying affiliation. The auth subtitle now says it is an independent unofficial client using Telegram API/TDLib with no direct relationship to Telegram Messenger LLP, and that other clients' sessions are not imported.
- Exact-HEAD AppKit `swift build` passed on Xcode 27.0 / Swift 6.4 in 4.69 seconds. The 151/151 local Swift suite is from unchanged Core code at parent app-source `0fc9e86`; it was not rerun for this copy-only UI change. Exact-SHA [macOS CI 38444116182](https://github.com/AffPapa/NeTelegram/actions/runs/38444116182) and [pinned TDLib/Dev.app workflow 38444116358](https://github.com/AffPapa/NeTelegram/actions/runs/38444116358) were running when this checkpoint was recorded.
- No Dev.app was launched and no local profile or Telegram client data was accessed. Native visual layout/contrast, login, and 20 authorized runtimes remain unverified. Public Site v147 was unchanged.

### 2026-10-14 — sign-in disclosure and Site v148 checkpoint

- App source commit: `86855e4599ae4dc9d00274c07331617ddc5b3684`. Exact-HEAD AppKit compile passed locally on Xcode 27.0 / Swift 6.4; the full 151-test suite is from base `0fc9e86` and was not repeated for the copy-only change.
- Exact-source GitHub macOS CI run [38444116182](https://github.com/AffPapa/NeTelegram/actions/runs/38444116182) concluded **cancelled** during “Build app and run core tests”; no CI test PASS. Exact-source pinned TDLib/arm64 Dev.app workflow [38444116358](https://github.com/AffPapa/NeTelegram/actions/runs/38444116358) succeeded for pinned dependency build/verification, isolated Dev.app assembly/verification, and artifact upload. This is accountless packaging evidence only.
- Public Site v148: source `48c314b77fa06f635399089aad316c5993c36cff`, saved version `appgprj_6acba85192e08191acdf7011928848cf~appgver_c23cd449d07c819196f72e9cf7d9befd`, deployment `appgdep_6ace755eb3e4819185693db0ce1866a3`. Source archive SHA-256 `79afff4bc7bc4695923f700b195ea8f6043f74e027503714339d460d8194f58e` (287,196 bytes); Sites content hash `sha256:3e9ca1b8ede1d70c40d350341b264549b3f8be61096de299917289af757e2f83`. Anonymous public `/devlog/` check at 390px showed 375px document width and confirmed commit, non-affiliation wording and no-login statement. Downloads remain unavailable.
- Synced the v148 devlog source and generated route into the app repository. Real login, 20 authorized runtimes, Developer ID/notarization, and compatibility gates remain open.

### 2026-10-14 — align hosted CI toolchain

- GitHub macOS CI run `38444116182` used Swift 6.1.2 / Xcode 16.4 on `macos-15`. Its 10-minute job timeout canceled `swift test` while `cancelledQueuedStartupDoesNotRunAfterItsPermitBecomesAvailable` was the only started test without a completion line. No concurrent workflow run existed to explain the cancellation.
- The exact test passed alone locally, and the full 151-test suite passed locally on Swift 6.4 / Xcode 27. CI now selects the `xcode-27` runner to match the tested toolchain generation; app deployment target remains macOS 14. Hosted verification for the workflow change is pending.
- Evidence is diagnostic, not a claim that the prior hosted suite passed. No account data or credentials were accessed.
- **Diagnosis correction:** the same 10-minute cancellation reproduced on the `xcode-27` runner with Swift 6.4, so the compiler-version mismatch was not the cause. Logs show Swift Testing starting the cancellation-sensitive test concurrently with the other tests. `swift test --no-parallel` completed locally with all 151 tests passing in 1.27 seconds. CI now returns to `macos-15` and invokes that explicit serial mode; hosted confirmation is pending.

### 2026-10-14 — hosted CI serialized and Site v149 published

- App repository/workflow commit `7eb1d292adc0d0f59d362c9eb925193d25128df6` changes CI to run Swift Testing explicitly with `--no-parallel` on `macos-15`. Exact run [38447978740](https://github.com/AffPapa/NeTelegram/actions/runs/38447978740) passed all 151 tests and checked-in JSON validation on macOS 15 / Xcode 16.4 / Swift 6.1.2. Local `swift test --no-parallel` passed 151/151 in 1.27 seconds on Xcode 27 / Swift 6.4. This resolves the prior 10-minute cancellations; the failed hypothesis that Xcode generation was the cause is superseded. Product source remains `86855e4599ae4dc9d00274c07331617ddc5b3684`.
- Public Site v149 source `c7c551dc5ddbd021cec894539e281c7d27cc3aae`, version ID `appgprj_6acba85192e08191acdf7011928848cf~appgver_fe401e8fbf848191ac535d721b3f7629`, deployment `appgdep_6ace7b3e44148191b1b9848cca2fd031` at https://netelegram.iryadom.chatgpt.site. Local archive SHA-256 `c9dc05bad1f314f5bc8b950b9139f616deeb799aa90a89db4e06f2e507d456ee` (287,610 bytes); Sites content hash `sha256:820c84b847c8b67a8ae9074bc13f761c9d6e69e0cd736b7fce3d1d2c3cfdbaf3`. Anonymous `/devlog/?v=149` showed the passing run/commit at 390px viewport (375px document width); `/downloads/?v=149` stated no verified release and linked zero ZIP/DMG assets.
- No app binary was released. Real account login, 20-runtime measurement, signing/notarization and Telegram compatibility gates remain open.

### 2026-10-14 — Shared Site design v150 and exact-state publication

- One shared CSS/design system and the existing HTML shell now serve all eight Site routes. The home keeps its original, clearly labelled concept illustration; content pages share consistent type, cards, status styles, navigation, footer, mobile layout, and reduced-motion behavior. The structure adapts Telegram.org's concise hero/value sections/footer without copying its assets or unsupported claims.
- App repository Site source commit `33147b0fff262db4825c5aa11b0782015d7485f1` was pushed to `AffPapa/NeTelegram`. The official Sites source helper committed/pushed exact Site source `92fdb0289165157b5f9ee8939dc96767c2915490`; archive `/private/tmp/netelegram-site-v150.tar` is 288,025 bytes, SHA-256 `5a732c4596fde83acba720ee464b8bc51ef3d12f01e2d9278ac1a688f2dc64d8`.
- Saved Site version `appgprj_6acba85192e08191acdf7011928848cf~appgver_50db2aac69548191bedc2057d6d3fcb5` and deployed successfully as `appgdep_6ace7e38f5d881918fa29d7fa0ebbd18` at https://netelegram.iryadom.chatgpt.site. Sites archive content hash `sha256:de3218cd58bdfef61848d4b7f6840aeb88c780b37761298374ee457eafa4c0c0` (15 files / 512,000 reported bytes).
- `python3 build_site.py` and `python3 validate_site.py` passed; both zero-item stable/alpha RSS files parse. Live public browser checked all eight routes at 375px: one H1, correct canonical, no horizontal overflow. Home was visually checked at 1440px and 375px. Downloads has zero ZIP/DMG/release links; both appcasts return HTTP 200 and `text/xml` with valid XML.
- Checkpoint was reconciled: previous nested Site v147 record now agrees with live v150, and latest repository HEAD is distinguished from unchanged product-code SHA `86855e4`. No native app code/build/release changed in this milestone.

### 2026-10-14 — clarify local profile slots in the sidebar

- App-source commit `4e96a1556e6cd5f74d0cabeb651e21fa64793b51` adds visible Russian copy below the account picker: these are local NeTelegram profiles on this Mac, and sessions from other apps are not imported. The sidebar search/chat list moved down to preserve spacing; picker identity/status behavior was not changed.
- Exact-source `swift build` passed on local Xcode 27 / Swift 6.4. SwiftPM's scratch and module caches were redirected to `/private/tmp` because the default user cache was inaccessible in the sandbox. The 151 Core tests were not rerun because this change only edits AppKit labels and frames. No Dev.app was launched and no Telegram profile/session data was accessed.
- Public Site remains v150; no download or release state changed. Native visual review, real login, 20 authorized runtime coverage, Developer ID/notarization and Telegram compatibility gates remain open.

### 2026-10-14 — shorten validation loop and reconcile current checkpoint

- Exact repository commit `40ca82e5065456b1ab98f675963682bf846da9a4` passed serial macOS Swift CI run [38452464811](https://github.com/AffPapa/NeTelegram/actions/runs/38452464811): 151/151 tests, 47-second job. Dedicated metadata validation run [38452464851](https://github.com/AffPapa/NeTelegram/actions/runs/38452464851) passed. The pinned TDLib/arm64 Dev.app workflow [38451242039](https://github.com/AffPapa/NeTelegram/actions/runs/38451242039) passed accountless close/reopen/quit smoke for app source `4e96a1556e6cd5f74d0cabeb651e21fa64793b51`.
- CI now runs Swift tests only when application, tests, package, dependency pin, or CI workflow inputs change. JSON checkpoint edits use a separate lightweight validator. The 47-second hosted suite and prior 1.27-second local suite do not justify adding SwiftPM cache complexity; the existing TDLib dependency cache remains for native app assembly. Tests stay serial because prior parallel execution stranded a cancellation-sensitive test.
- Reconciled `PROJECT-STATE.json` and `ACCEPTANCE.json` to Site v150, app source `4e96a155`, repository evidence baseline `40ca82e`, and the current passing workflows. This is documentation/checkpoint work; no Site publish or app release was appropriate. Real account, 20-runtime, signing/notarization, and Telegram compatibility evidence remains open.

### 2026-10-14 — narrow AUTH03 to evidence still missing

- Static review of app source `4e96a1556e6cd5f74d0cabeb651e21fa64793b51` confirms a 900×700 minimum window, a 568 px maximum auth card and 360 px inputs. The constraints fit at the declared minimum width; this does not establish visual quality or height behavior.
- Exact-source pinned Dev.app run `38451242039` published a review artifact containing the native first-run image. The image has not yet been visually inspected. Code/2FA/QR/registration screen layouts and accessibility remain unverified; AUTH03 stays partial. Next action is to inspect the artifact and make only screenshot-backed layout changes.

### 2026-10-14 — make Telegram ecosystem disclosure explicit in sign-in

- Rechecked current primary Telegram API Terms and pinned TDLib 1.8.68 schema. Terms §2.2 calls for prominent notice that the client uses Telegram API and is part of the Telegram ecosystem. The sign-in intro now says both explicitly while preserving NeTelegram's independent/no-affiliation disclosure.
- The exact pinned TDLib schema contains sponsored channel messages with `messageVideo` plus timed video-message advertisement APIs. User previously declined a video player; channel access/stable release therefore remains deferred. Terms §§1.3/1.4 do not enumerate a minimum feature checklist in the primary page, so this compatibility review remains open.
- Exact-source local AppKit/Core build passed on Xcode 27 / Swift 6.4 in 5.69 seconds. No account or keychain data was accessed. CI and pinned Dev.app smoke are pending for the changed source.

### 2026-10-14 — verify ecosystem disclosure change on exact source

- App source `78d96212b45df18f5a5aea206a467ff397d273b4` makes the sign-in intro explicitly say the client uses Telegram API/TDLib and belongs to the Telegram ecosystem, while retaining the independent/no-affiliation statement. Local Xcode 27 / Swift 6.4 AppKit/Core build passed in 5.69 seconds.
- Exact-source hosted serial CI [38453959840](https://github.com/AffPapa/NeTelegram/actions/runs/38453959840) passed all 151 tests in 53 seconds on macOS 15 / Xcode 16.4 / Swift 6.1.2. Metadata validation [38453959743](https://github.com/AffPapa/NeTelegram/actions/runs/38453959743) passed. Pinned TDLib/arm64 Dev.app workflow [38453959931](https://github.com/AffPapa/NeTelegram/actions/runs/38453959931) passed bundle verification, accountless first-run capture, last-window close, LaunchServices reopen/same PID and normal quit.
- Current official Terms and pinned TDLib v1.8.68 schema were reviewed. The sign-in disclosure now covers API use and ecosystem membership. Terms §2.3 title conflict, sponsored-video requirement for channels, and basic-functionality review remain open; no compatibility or stable-release pass is claimed. No real accounts, Site, or release assets changed.

### 2026-10-14 — report explicit photo opens to TDLib

- The exact pinned TDLib 1.8.68 schema says `openMessageContent` informs TDLib when a user opens photo/video/document/location content and may generate `updateMessageContentOpened` (pinned schema, lines 11812–11816; https://raw.githubusercontent.com/tdlib/td/c15d3f5a5de6e3ba5839822c451152e5e18bb700/td/generate/scheme/td_api.tl). The NeTelegram photo viewer previously displayed an opened full-size image without sending that request.
- The viewer now sends the request after ImageIO decoding succeeds and the viewer is shown, through `PrivacyDispatchBarrier` bound to account, server identity, runtime generation and privacy epoch. This does not mark inline thumbnails as opened and does not claim real-account behavior.
- Final local serial `swift test --no-parallel` passed 151/151 on Xcode 27 / Swift 6.4 (build 5.33 seconds, tests 0.207 seconds). Hosted CI and pinned Dev.app checks are pending for the changed source. APP20 remains partial until native/account-backed photo flows and memory pressure are verified.


### 2026-10-14 — shorten and instrument the Swift CI feedback loop

- Exact app source `55dd12b5bbcfab871df3473dba0d9e5a03b51814` is pushed to `AffPapa/NeTelegram`. Local serial Swift suite passed 151/151 (build 5.33 seconds; test execution 0.207 seconds). Exact-source pinned TDLib/arm64 Dev.app workflow [38454870134](https://github.com/AffPapa/NeTelegram/actions/runs/38454870134) and metadata workflow [38454869806](https://github.com/AffPapa/NeTelegram/actions/runs/38454869806) passed.
- Exact-source macOS CI [38454870102](https://github.com/AffPapa/NeTelegram/actions/runs/38454870102) compiled and linked the test bundle in 40.26 seconds, then emitted no test-start output for about 9m23s and was cancelled at the 10-minute limit. This establishes a runner stall after build/link and before visible test output; it does not identify a failing test or prove a product defect. A prior 151/151 hosted pass was for SHA `78d9621`, not this source SHA.
- GitHub's connected Actions integration returned 403 for a same-job rerun, so no retry or new credential was attempted. CI now keeps the serial suite, enables verbose driver output to expose the test-runner handoff, and caps silent stalls at five minutes. `DEV-WORKFLOW.md` records one-checkout/one-candidate cadence and which workflow applies to source, metadata, native bundle, and release changes. Hosted confirmation for this workflow adjustment remains pending. Local rerun of the new `--verbose` command could not proceed: SwiftPM manifest compilation hit the managed `sandbox-exec: sandbox_apply: Operation not permitted` restriction even with its scratch/module caches under `/private/tmp`; this is an environment block, not a Swift test result.
- No app release or Site deployment occurred. Account-backed login, all-20 runtime certification, Developer ID/notarization, and Telegram compatibility gates remain open.


### 2026-10-14 — confirm fast CI diagnostics on the exact candidate

- Workflow/checkpoint commit `fa021866d59db2f797fea5c49eab7f4798c95f2c` passed macOS CI [38456932580](https://github.com/AffPapa/NeTelegram/actions/runs/38456932580) for app-source `55dd12b5bbcfab871df3473dba0d9e5a03b51814`. `swift test --no-parallel --verbose` reported all 151 tests passed in 0.486 seconds after build; the complete hosted job took about 59 seconds.
- This confirms the verbose command and serial suite. It does not retroactively turn prior cancelled run 38454870102 into a pass; that run stalled before visible test output. The new log boundary makes future runner-startup stalls diagnosable, and the five-minute limit bounds that wait.
- Exact app-source local suite remains 151/151 (5.33-second build, 0.207-second test execution); exact-source native TDLib/Dev.app smoke 38454870134 and metadata validation 38454869806 passed. No Site, app release, or Telegram account state changed.


### 2026-10-14 — validate the updated project checkpoint

- Metadata-only validation [38457141078](https://github.com/AffPapa/NeTelegram/actions/runs/38457141078) passed for checkpoint commit `cd1fbe457ad8c14884bd781b84ef2ac007b88909`. It does not rerun the Swift suite; exact-source Swift PASS remains run 38456932580.


### 2026-10-14 — verify sign-in disclosure on one exact candidate

- Canonical checkout `/private/tmp/netelegram-cli-work`, `main`, source `6145b0156068f784e1eea3bf70df77a8b834bf83`, clean and equal to `origin/main`. Local AppKit/Core build passed in 5.27 seconds; serial suite passed 151/151 (0.202 seconds) on Xcode 27 / Swift 6.4.
- Pinned TDLib/arm64 Dev.app run [38457814416](https://github.com/AffPapa/NeTelegram/actions/runs/38457814416) passed exact-source bundle verification, first-run capture, window close/reopen in the same PID, and normal quit. Screenshot review confirms the phone-entry card and API/TDLib + non-affiliation disclosure; the line is small/low-contrast. CI has no API hash configured, so no login was attempted.
- Hosted macOS CI [38457814445](https://github.com/AffPapa/NeTelegram/actions/runs/38457814445) passed 151/151 in 0.468 seconds after a 36.31-second build (about 52 seconds total) on macOS 15 / Xcode 16.4 / Swift 6.1.2. The first attempt completed build but the Swift Testing runner stayed silent and hit its five-minute timeout; one same-SHA rerun passed. No code change or duplicate native build was used to resolve it.
- No real account, private account data, Site deployment, or app release was accessed or published. Site remains v150; real login/all-20-runtime coverage and signed distribution remain open.


### 2026-10-14 — publish the exact candidate evidence to Site v151

- Updated the existing public Site using its official source helper. Source commit `08b31c8ca6a5a0c1957fa268abeba9b1c2366a24` and saved version 151 were deployed as `appgdep_6ace8ec76e4081918ae04844ab188b40` at https://netelegram.iryadom.chatgpt.site; no new Site was created.
- The devlog links app source `6145b0156068f784e1eea3bf70df77a8b834bf83`, hosted CI [38457814445](https://github.com/AffPapa/NeTelegram/actions/runs/38457814445), and pinned TDLib/Dev.app smoke [38457814416](https://github.com/AffPapa/NeTelegram/actions/runs/38457814416); it states the 151-test pass, the same-SHA runner timeout/rerun, the accountless scope and the low-contrast disclosure observation. It does not claim a live login or release.
- Anonymous HTTPS checks returned HTTP/2 200 and `text/html` for `/devlog/` and `/downloads/`. Live content matches the source. Downloads says no verified macOS build exists and contains zero ZIP/DMG/release URLs.
- Local archive `/private/tmp/netelegram-site-v151.tar.gz`: SHA-256 `644bfe466d0557f269c645f36a0744f74bbc3f1eabb75d30775dbf999cc7d21b`, 288543 bytes. Sites saved archive receipt: `sha256:4a651fc1aa376c021101ee64ccc46ab7976fe5cd4ba20d8157d468c757dbc001`, 512000 bytes, 15 files. Checkpoint commit `3664214a842913ed03c5413a18beb39b95cc817e` passed metadata validation run 38459557354; this Site receipt is recorded in the subsequent checkpoint edit.


### 2026-10-14 — avoid rebuilding pinned TDLib for source-only edits

- Removed `Sources/**` and the workflow-file self-trigger from automatic push/PR paths for `native-app.yml`. Swift source and tests remain covered by the macOS serial CI; pinned TDLib/Dev.app still runs automatically for SwiftPM, TDLib lock and native build/lifecycle script changes, and remains available through `workflow_dispatch` for runtime integration or a frozen release candidate.
- Updated `DEV-WORKFLOW.md` to match. Ruby YAML parse and `git diff --check` passed. No app code changed; no application build or test suite was repeated for this trigger/documentation-only change. The prior exact-source native run 38457814416 remains valid for app source 6145b015.

### 2026-10-14 — improve sign-in disclosure readability

- Source commit `2cd13c2bd97431ab4e6f7f0b03fa9a6e5f2cfbb` changes only the sign-in disclosure from 11 pt tertiary-label gray to 12 pt secondary-label gray. Copy, auth behavior, profile catalogue and account state are unchanged.
- Exact source-tree fingerprint `3038c01c875af925bdf39eb7134cdd3f861bd14597d53c1138a7ecfdf0f51e1c`; canonical arm64 Dev.app executable SHA-256 `2ba1f7c3adc0d9214b3fa62051959e38f84849058a4c173ed2c00676ead52259`; pinned TDLib JSON SHA-256 `9b1ba46d15f410d687aeb355bcd6bbe4e5e172bfc55ab38abc3e68d7842efdc1`. The app was built with ad-hoc development signing only.
- Local `swift test --no-parallel` passed 151/151 on Xcode 27.0 / Swift 6.4 (5.30 s build, 0.203 s test execution). Managed sandbox rejected SwiftPM module-cache sandbox setup even with caches under `/private/tmp`; one reviewed escalation allowed the exact test command to run. This was an environment permission boundary, not a product test failure.
- One canonical Dev.app ran with isolated empty support root `/private/tmp/netelegram-auth-ui-support`. Accessibility inspection confirmed the normal phone-entry form and no profile picker. Screenshot `/private/tmp/netelegram-auth-ui.png`, SHA-256 `f3a8b27087f3b559168352debee1e97a4a122d03d1be1cb635d3f38def84c36c`, visually reviewed with no clipping and clearer disclosure. No login credentials or account data were used. Lifecycle close/reopen was not repeated for this UI-only edit.
- Exact-source hosted CI, metadata validation and public Site devlog sync are pending. No app release or download link exists. Real login, all-20 certification, Developer ID/notarization and Telegram compatibility gates remain open.

### 2026-10-14 — publish current sign-in verification and Site v152

- App source `2cd13c2bd97431ab4e6f7f0b03fa9a6e5f2cfbb` and checkpoint commit `0c8ee8358e8fe7d5e79204336ccc0c6a9e387f7a` were pushed to `AffPapa/NeTelegram` through Git. Exact-source macOS CI [38461168203](https://github.com/AffPapa/NeTelegram/actions/runs/38461168203) passed; the run log reports all 151 tests passed in 0.620 s. Metadata validation [38461168216](https://github.com/AffPapa/NeTelegram/actions/runs/38461168216) passed for checkpoint `0c8ee83`. Neither run was manually duplicated.
- Existing public OpenAI Site project `appgprj_6acba85192e08191acdf7011928848cf` was updated through its official source helper. Site source `e671ff012964561583051b18772ddbae0d34f409` was saved as version 152 and deployed as `appgdep_6ace91b5ca288191bd66fe1f88c5f08b` at https://netelegram.iryadom.chatgpt.site. The audience remains public.
- Site archive `/private/tmp/netelegram-site-v152.tar.gz`: SHA-256 `90a5e6a35fdf21a4e180fc046504464108d3a8268715954f8596fd148be693ae`, 288544 bytes. Sites receipt: `sha256:2758ac725793abf912182785aa5cd48110e70432c6c819f4b600114d396d0786`, 512000 bytes, 15 files.
- Anonymous system `curl` verified `/devlog/` and `/downloads/` as HTTP/2 200, `text/html`. Devlog contains app source `2cd13c2`, CI run `38461168203`, metadata run `38461168216`, and the accountless test scope. Downloads still have zero ZIP/DMG links and state that no verified app build is available.
- A Python HTTPS probe failed TLS certificate validation because its local CA bundle could not build a trust chain; standard system `curl` verified the same public routes with normal certificate validation. No TLS bypass was used.
- No app release, release asset or user account changed. Real login/all-20 coverage, Developer ID/notarization, updater, and Telegram API compatibility remain open.

### 2026-10-14 — remove stale evidence pointers from the checkpoint

- Consolidated evidence labels after review: pinned native workflow `38457814416` is now explicitly a historical baseline for app source `6145b015`, while the current source `2cd13c2` has separate accountless local Dev.app UI evidence. No Swift tests or TDLib build were repeated.
- Current Site acceptance evidence now points to public v152/source `e671ff0` and deployment `appgdep_6ace91b5…`. Anonymous live checks cover only `/devlog/` and `/downloads/`; local static validation covers all eight routes. Other public routes/feeds were not claimed as live-checked. SITE03/04/05 remain partial because downloads, accessibility/browser coverage and signed-byte/updater coherence are incomplete.
- Removed duplicate Site archive size/hash aliases and renamed the stale top-level devlog pointer to `latest_site_source_commit`. Acceptance workflow evidence is now structured by current app-source CI, checkpoint metadata, and historical native baseline.
- This is checkpoint hygiene only. The already-passed app CI `38461168203` remains valid for unchanged app source `2cd13c2`; one metadata validation will run for this consolidated JSON, with no source or package rebuild.

### 2026-10-14 — reconcile the current checkpoint and stop stale-version loops

- Resume audit found `PROJECT-STATE.json` still pointed its repo HEAD and native candidate to mixed historical labels, while the latest metadata run for `f99ce19` had already completed. Reconciled app-source SHA (`2cd13c2`), repository checkpoint HEAD (`f99ce19`), Site-source/version/deployment, metadata receipt, and historical local Dev.app evidence as distinct identities.
- Marked the captured local bundle historical because its process state was not re-queried; it is no longer described as the current running app. Corrected the prior Site receipt's `app_repository_commit` to the app source SHA mirrored by the Site.
- Updated the single next action: investigate pre-account country selection without creating an account/runtime just to fetch a list; retain explicit international-number input as the existing fallback. No product code, app build, Swift tests, Site deploy, account data, or release assets changed.
- Local metadata-equivalent JSON validation and `git diff --check` passed. GitHub API was unreachable on this resume, so metadata run `38462120071` is carried forward from the immediately preceding workflow receipt; this checkpoint-only change will receive the normal metadata workflow after push. No app test or native workflow is needed.

- Push of checkpoint `2e27871ce636639873de1c9769b26c2a7ce1229a` to `origin/main` succeeded. The expected metadata-only workflow [38462809234](https://github.com/AffPapa/NeTelegram/actions/runs/38462809234) completed successfully for that exact commit. No app-source workflow, Swift suite, TDLib build, Site deployment, or release was triggered. This is the current metadata receipt and supersedes the previous pending note.

### 2026-10-14 — first-run country selection slice

- Added a pre-account country selector backed by 245 region/calling-code pairs derived from Google libphonenumber v9.0.41 at pinned commit `b68df884d42d5e9860fc1956a99ce6afae361100`. Source XML and license SHA-256 values match `COUNTRY-DATA.lock.json`; the generator reproduced the checked-in Swift catalog byte-for-byte. Apache-2.0 attribution/license are retained.
- The macOS locale only suggests a region when that region exists in the catalog. No implicit `+1` is selected. International numbers with `+` are accepted without selecting a country; national-format numbers require an explicit calling code. Country data is bundled, so first-run UI does not create a TDLib runtime/profile just to fetch the list. Existing TDLib country data can replace the local list after a profile runtime exists.
- Local serial `swift test --no-parallel` passed 152/152 on Xcode 27.0 / Swift 6.4 (4.88-second build; 0.200-second test execution). JSON parsing, lock hash checks, deterministic generator comparison, and `git diff --check` passed.
- Native UI smoke of this candidate was not run. The old canonical Dev.app stayed open after a graceful Cmd+Q attempt and the launcher refused replacement; no forced process termination or second app bundle was used. Hosted exact-source and metadata CI are pending the candidate push. Site remains public v152 and still describes the previous milestone; no app release/downloads were added.
- No real login, account/profile data, installed Telegram data, signing identity, or release credentials were accessed. Real login, server-list reconciliation, all-20-runtime coverage, signed/notarized release, updater, and API compatibility gates remain open.

### 2026-10-14 — publish country-selection milestone and record hosted CI timeout

- Source commit `be58d831aaa1d53c3d47e1313758feb7f9e32384` and checkpoint commit `1ff4cf578e634623bbcdd5d876041f100f9290f0` were pushed to `AffPapa/NeTelegram`. The pre-push fetch confirmed origin/main was the prior ancestor, so this was a fast-forward with no remote changes overwritten.
- Exact checkpoint metadata validation [38464148278](https://github.com/AffPapa/NeTelegram/actions/runs/38464148278) passed. Hosted macOS CI [38464148650](https://github.com/AffPapa/NeTelegram/actions/runs/38464148650) completed its build step but the test step was cancelled at the five-minute workflow timeout. Local serial suite passed 152/152. The GitHub connector denied a same-run retry with HTTP 403 `Resource not accessible by integration`; job logs were unavailable through the connector. Hosted PASS is not claimed.
- Existing public Site v153 was deployed from source `7790a235a570dd9923c58be9b714af91585732ab` as deployment `appgdep_6ace9871f63c819180a67d58b1591c98`. It adds bilingual factual notes about the first-run country picker and the hosted timeout. Anonymous checks found `/devlog/` and `/downloads/` at HTTP/2 200 `text/html`; the downloads page still has no app binary links.
- Site archive `/private/tmp/netelegram-site-v153.tar`: local SHA-256 `a882fb669d8b8dae055018589dd826753a11c0141a51c8235ba298391bdcb064`, 289466 bytes. Sites stored receipt `sha256:32919270e3e8acd907b89f912b17492587827f4f85e9dff0bc500dcebf469c08`, 522240 bytes, 15 files.
- No current-candidate Dev.app GUI smoke, real Telegram login, account data, app release, or downloads. Existing old bundle was not force-terminated or replaced. Next: diagnose the hosted runner timeout and use only an authorized Actions retry route; then perform one canonical accountless UI smoke after safely quitting the old bundle.

### 2026-10-14 — show first-run phone UI before API hash lookup

- A native Dev.app smoke after the country-catalog milestone exposed a startup ordering issue: on an empty profile catalogue, `restoreProfiles()` attempted Keychain API-hash lookup before it called `showPhoneEntry()`. The form could remain at “Подключаю экран входа…” while that asynchronous lookup ran or failed. The code now shows the bundled country selector and phone form as soon as the empty catalogue is confirmed; only explicit Continue/QR proceeds to `addAccountProfile()`, which still requires the API hash before creating a profile.
- App source commits `74265a3525d0ba4351c89e57ea63dafbc0802804` and `94740d38bfa845919ac2863ad0e78d1a7d494a04` are on `main`; the latter only changes the first-run status copy to remain neutral until the credential check happens.
- Exact-source canonical Dev.app for 94740d3 built in 9.12 seconds on arm64 / Swift 6.4; ad-hoc nested codesign verification passed. Fresh AX and screenshot inspection show Thailand +66 as a locale suggestion, phone field, Continue and QR. Status is “Выберите страну и введите номер телефона.” No phone, OTP, account, profile or session was entered or created. Bundle fingerprint `e79a341bdfc0c7cd1c7da64c68b0a42112af892000c42c01bac16fed836d32b6`; executable SHA-256 `af309b5551f57682e86d8a521da99ae97f04606fbfc17d4df5d10cd101fc2a31`; bundle `/private/tmp/NeTelegram-Dev.app`; isolated support root `/private/tmp/netelegram-first-run-smoke-94740d3`.
- The serial core suite passed 152/152 for preceding source be58d83, before this AppKit-only startup-order change. A current-source `swift test` run compiled the app in 5.14s but emitted no test result for over a minute; it was interrupted, so it is not a PASS. Automatic exact-source macOS CI run [38466197778](https://github.com/AffPapa/NeTelegram/actions/runs/38466197778) is pending. Earlier run [38464148650](https://github.com/AffPapa/NeTelegram/actions/runs/38464148650) on be58d83 was cancelled at its five-minute workflow timeout; the GitHub connector denied retry with 403.
- Public Site v153 still refers to be58d83 and says the updated UI was not visually checked. Update the existing public Site once after CI status resolves; no app release/downloads are available.

### 2026-10-14 — publish current first-run UI smoke as Site v154

- Existing public Site project `appgprj_6acba85192e08191acdf7011928848cf` remains public at https://netelegram.iryadom.chatgpt.site. Site v154 source `6242beb8ecd26008e235b46b7f922c37010b14b2` deployed as `appgdep_6ace9add32348191ad8bf25dc41140bf`; saved version ID `appgprj_6acba85192e08191acdf7011928848cf~appgver_0e843b0b1ca08191a89301eb4a734108`.
- The bilingual devlog reports exact app source 94740d3, the first-run country UI visible in a current-source Dev.app, prior-source 152/152 suite coverage, current test-runner interruption and current hosted CI still in progress. It makes no current-source test PASS claim. Downloads remains without app URLs.
- Anonymous HTTPS checks: `/devlog/` and `/downloads/` both returned HTTP/2 200 and `text/html`; live content assertions passed. Site archive `/private/tmp/netelegram-site-v154.tar`: local SHA-256 `a9f68baeb47fbb9d59f9e06d86917d1a2084919329fc2e7da5c28c8b61c77836`, 290346 bytes; Sites archive receipt `sha256:4c62478ca725e7d990ef4829ba912136ca34990d0c4236197532f900434390e2`, 522240 bytes, 15 files.
- Current exact-source macOS CI run [38466197778](https://github.com/AffPapa/NeTelegram/actions/runs/38466197778) was in progress at publication time. Metadata run [38466400353](https://github.com/AffPapa/NeTelegram/actions/runs/38466400353) is queued for checkpoint d2df61b. No app release/downloads, real login, or account data.


### 2026-10-14 — reconcile test status and remove stale-version loops

- Rechecked GitHub run 38466197778 against exact app-source SHA 94740d38bfa845919ac2863ad0e78d1a7d494a04: macOS CI ended `cancelled` at the five-minute timeout during `swift test --no-parallel --verbose`. No failed assertion surfaced and no test result was produced; current-source suite is not PASS. Metadata validation 38466847617 passed for checkpoint 4d9989c.
- Reconciled the top-level acceptance summary to app source 94740d3, prior-source-only 152/152 coverage (be58d83), Site v154 and the terminal CI result. The existing `last_verification` and PROJECT-STATE already had the correct current source, but ACCEPTANCE top-level still said 2cd13c2, 151/151 and Site v152.
- Read-only Site QA found stale homepage/features cards still linking run 38447978740 and claiming 151 tests. One corrective Site publication is being prepared; no app rebuild or test rerun is needed for these metadata/content changes.
- Fast path from here: diagnose why the serial test runner stalls before retrying once; choose the next independent production-wiring slice after that. Real login remains user-deferred. No account/session data or credentials accessed.


- Publication update: checkpoint reconciliation commit `6ee3a837aba4e737d84443b5a3dc61ca9bef6c69` is local and unpushed. `git push origin main` failed before transport because DNS could not resolve `github.com`; no retry was made. Existing Sites source checkout `/private/tmp/netelegram-site-source` has a prepared homepage/features/devlog correction (all eight static routes validate); the official helper failed before commit/push because DNS could not resolve `git.chatgpt-team.site`. No Site version was saved or deployed. Both DNS checks failed at `curl` resolution; no fallback endpoint/token route was attempted. Resume by checking DNS once, then push the exact checkpoint and use the official Site helper once.


### 2026-10-14 — isolate the silent CI runner with two focused tests

- Downloaded job logs for exact-source macOS run 38466197778. Xcode 16.4 / Swift 6.1.2 compiled and linked the test bundle in 47.20s; the job log then shows no test completion output before `The operation was canceled` at 20:58:21Z. GitHub cleanup terminated orphan `swiftpm-testing`. The job's configured timeout is five minutes; the log does not identify the cancellation initiator, so cause is recorded as unknown rather than asserted.
- Built current source 94740d3 locally with Xcode 27 / Swift 6.4 in 5.38s and ran only two filtered tests: `cancelledQueuedStartupDoesNotRunAfterItsPermitBecomesAvailable` passed in 0.002s; `twentyProfileRestoreStartupRegistrationSurvivesStallFailureRetryAndSelectionChanges` passed in 0.001s. These are synthetic Core tests; they do not invoke AppDelegate restoration or real TDLib accounts. No full suite PASS is claimed.
- Initial targeted launch under the default sandbox failed before the test runner because `sandbox-exec` was denied; the authorized host execution completed the two focused commands. No app source changed and no full-suite retry was made.
- DNS still fails for `github.com` and `git.chatgpt-team.site`. The app checkpoint is local/ahead and the Site homepage/features/devlog edits remain uncommitted locally; no external source push, Site version save, or deployment occurred.


### 2026-10-14 — make account startup queue failures visible

- `AccountRestorePlanner.enqueueStartupProfiles` now returns queued and rejected account UUIDs. `AppDelegate` records rejected starts as per-profile failures and keeps the other eligible profiles running; status text reports partial queue rejection instead of implying all were restored.
- Added a 20-candidate regression test: 17 accepted, one explicitly rejected, one already-running and one already-starting are accounted for, and the last candidate remains queued.
- Exact app-source commit: `4d6820da73f2790c73a35177b8f9c1d1ecf8685c`. Focused serial `swift test` on Xcode 27 / Swift 6.4 built in 18.37s; both `restoreEnqueueReportsOneRejectedProfileWithoutDroppingOtherEligibleProfiles` and `startupDispatchQueuesAllFreeProfilesWhileFirstStartupIsStalled` passed (0.001s each). These synthetic Core checks do not prove real TDLib accounts or 20-account lifecycle. The full suite was not run.
- `git diff --check` and JSON parsing passed for the reconciled checkpoint. Fresh DNS checks still fail for `github.com`, `netelegram.iryadom.chatgpt.site`, and the Sites helper host. `gh auth status` reports its stored tokens invalid; no new credential was created. App source and checkpoint remain local; public Site v154 remains unchanged.
- Efficient next sequence: one DNS recheck; once available, push source + checkpoint once and wait for exact-source CI once; then publish the already-prepared Site correction once through the official helper. Do not repeat these focused tests unchanged or build an app bundle for Site-only copy.


### 2026-10-14 — full serial suite confirms startup rejection slice

- Current app-source commit `4d6820da73f2790c73a35177b8f9c1d1ecf8685c` passed the complete serial Swift suite: 153/153 on Xcode 27.0 / Swift 6.4 / arm64 / macOS 27 SDK. With the test bundle warm, build took 0.23s and test execution took 0.200s. The run includes both startup queue tests; no real Telegram account or TDLib session was used.
- Exact command: `CLANG_MODULE_CACHE_PATH=/private/tmp/netelegram-clang-module-cache SWIFTPM_MODULECACHE_OVERRIDE=/private/tmp/netelegram-swift-module-cache swift test --no-parallel --jobs 2 --scratch-path /private/tmp/netelegram-fast-validation --verbose`. The sandbox denied SwiftPM manifest setup; the same selected host execution then completed successfully.
- This establishes a local full-suite PASS for this source, not a hosted CI PASS. Exact-source CI has not run because the source is still unpushed. Parent-source CI 38466197778 (94740d3) remains cancelled in runner phase with initiator unknown.
- Site homepage/features/devlog were updated locally to source 4d6820d and exact coverage; static validation passes all 8 routes. Sites confirms the existing public deployment remains v154. No app binaries or downloads.
- External checks still show DNS failure for github.com; do one DNS/remote check on resume, then push source + checkpoint once, let CI/metadata run together, and publish the prepared Site once after the hosted result. Do not repeat 153/153 unchanged.


### 2026-10-14 — exact app CI and public Site v156 reconciled

- Verified canonical app repo `/private/tmp/netelegram-cli-work`, branch `main`, clean before publication; live `origin/main` was `4d9989c04f07875dbed7218c77c33b60a1f5e1c6`. Existing Git transport pushed the three reviewed commits fast-forward to checkpoint `c9dd915e5e79dd9027db568c68c8a2e3283950e5`; no token creation or auth login.
- GitHub macOS CI `38469520583` and metadata validation `38469520931` both completed successfully on the checkpoint; product app-source remains `4d6820da73f2790c73a35177b8f9c1d1ecf8685c`. Local full serial suite remains 153/153 on Xcode 27 / Swift 6.4; tests were not repeated unchanged.
- Official Sites helper initially failed inside sandbox on DNS for `git.chatgpt-team.site`; same helper succeeded through approved host network using credential only over hidden stdin. No Site origin was replaced and no token was printed. Site source `7590ad7` saved/deployed as v155, then anonymous QA found that the intended new devlog marker had not landed. Corrected the source and published v156 from `5e9651446a4bfbae4bd3bc0f086c9d481f9560d5` (deployment `appgdep_6acea15c55f881918a6f848cac79f7a6`).
- Public v156 checks: `/`, `/features/`, `/devlog/`, `/downloads/` each returned HTTP 200 `text/html`; current CI/source markers pass, and downloads contains no installer links. Local v156 archive SHA-256 `0c473115004e34a4119b8d9eae36a295e08c571a78ae0465131f0d095e3e1fab`; Sites archive receipt `sha256:f96442371e6bf138335de9f090bcec6cdf07b4e6a225ebfdb7f000cd13de79ac`.
- No app bundle was rebuilt or launched. No real Telegram account was entered. All-20 runtime, current-source native GUI smoke, Developer ID/notarization, updater and compatibility gates remain open; no binary release/download is claimed.


### 2026-10-14 — current-source accountless Dev.app smoke

- Canonical `Scripts/dev-app.sh --launch` passed its process guard and built `org.affpapa.netelegram.dev` from clean HEAD `c028bd3859d76b6abf31634a4bb62f071d5e9f57` in 9.05s; nested ad-hoc codesign verification passed. arm64, minimum macOS 14.0; isolated support root `/private/tmp/netelegram-c028-dev-support`.
- Bundle source fingerprint `d4a02f5339d4d87b9f79ab6d4df9f9ca56639e6f09366e3520e1afc66c9586d8`; executable SHA-256 `e9a30f6e2413e2b2cbc163ce3f5ce82462c431a546e258e7b513a9843bf2fa35`; TDJSON SHA-256 `9b1ba46d15f410d687aeb355bcd6bbe4e5e172bfc55ab38abc3e68d7842efdc1`.
- Accessibility smoke: country/phone form, locale-suggested Thailand +66, neutral status, Continue and QR visible. No phone, OTP, profile or Telegram session entered. Native Dev.app remains open. This is not a release signature/notarization check.
- Metadata validation `38470536609` passed for c028bd3. No app-source changes since 4d6820d; 153/153 local suite and macOS CI `38469520583` remain the current app-source test evidence.


### 2026-10-14 — current-source smoke published to Site v157

- Site homepage/features/devlog now report canonical Dev.app smoke from clean app checkpoint `c028bd3`, not only historical parent `94740d3`. The status remains accountless, ad-hoc development signed, and not a release.
- Official Sites helper source commit `3c14efda4c204c0bb3ca57a95aca0b2b8f27b751`; saved version 157 `appgprj_6acba85192e08191acdf7011928848cf~appgver_68bbface67388191aa283ec451dcb128`; deployment `appgdep_6acea2b8963481919ba43b8a1b5c0dfa6` succeeded on the existing public Site `https://netelegram.iryadom.chatgpt.site`. No Site project/origin changes.
- Archive SHA-256 local `458456229885704413ba63fbe22b7f6baaa9415fe184a00f66875af8f8274cb5`; Sites archive receipt `sha256:f4237d5da1dc9a5dc55be20b61c0ca8acb672bf9c1fe42c8620f9aff52c55eef`, 532480 bytes/15 files.
- Anonymous public checks after v157: `/`, `/features/`, `/devlog/`, `/downloads/` each HTTP 200 `text/html`; current-source/CI markers passed; downloads has no installer links.
- App source unchanged. Local suite 153/153 and hosted macOS CI 38469520583 remain valid; current-source Dev.app c028bd3 AX smoke passed with no phone/code/profile/session. No real login or 20-runtime certification.


### 2026-10-14 — native workflow trigger accuracy and faster verification policy

- Review found the native workflow filters used lowercase `scripts/...`, while the tracked native inputs are under case-sensitive `Scripts/...`. Corrected both push and pull-request filters, and added the workflow file itself so future trigger edits receive the native bundle check.
- Kept source-only Swift edits off the expensive pinned-TDLib workflow: `ci.yml` already runs the serial macOS tests for `Sources/**` and `Tests/**`; dispatch the native workflow only for TDLib/runtime integration, native packaging inputs, or a frozen candidate. This preserves fast iteration without dropping source test coverage.
- Local validation passed: Ruby YAML parse; case-sensitive existence and inclusion of each native script in both filters; `git diff --check`. No Swift code changed, so the 153/153 suite was not repeated.
- Current Dev.app lifecycle script was not claimed as a pass: the shell process/LaunchServices route could not control the already-running app (`pgrep` reports sysmond unavailable; `open -n` returns `kLSNoExecutableErr`). CUA independently confirms the existing canonical c028bd3 window is running on the accountless phone form. No replacement instance, profile, or login data was created.

## 2026-10-14 — Privacy Lock notification-cache redaction

- App-source commit `be4707d2876c183fa5760f7264ee0fd51c740461` redacts plaintext previews already held in the app's notification route cache on lock, clears the pending locked-notification handoff, and avoids copying preview text from notifications arriving while locked. Exact account/chat/topic/message routing is preserved.
- Focused local privacy tests passed 2/2. Exact-SHA [GitHub macOS CI run 38473154528](https://github.com/AffPapa/NeTelegram/actions/runs/38473154528) passed the complete Apple Silicon serial suite, 155/155 (41 seconds).
- A local full-suite attempt stalled in the existing blocked-receive drain test; it was interrupted and is not counted as a local PASS. The exact-source hosted full suite passed. No duplicate run was launched.
- Synthetic route/cache evidence only. Native Notification Center behavior, secure RAM erasure, late image/picker callbacks and real-account send races remain unverified. No Dev.app build, login, release asset, or Site update was made.

## 2026-10-14 — Public devlog v158 synced to privacy-cache milestone

- Existing public Site/project retained: `appgprj_6acba85192e08191acdf7011928848cf`; source commit `02a5dbdde3d877e3791397b392c183453b03fa50`; saved version 158 `appgprj_6acba85192e08191acdf7011928848cf~appgver_042a2e3e757881919cdfd4e1ba0d6c2b`; deployment `appgdep_6acea846c16c8191b1db071a9eb334c0` succeeded at https://netelegram.iryadom.chatgpt.site.
- Site archive SHA-256 `320c16dc1960daacfb27f16c9488c236e59d33db99c527e658fbdc09a95929fc`; Sites-reported archive hash `sha256:7ee8dcf223331b8ae32405033935c0b72509235434276cf13699b98ef6eda36b`.
- Static build and focused validation passed for all eight routes. Anonymous HTTPS checks returned 200 `text/html` for `/`, `/features/`, `/devlog/`, and `/downloads/`; the devlog contains app-source `be4707d` and CI `38473154528`. Downloads still has no installer links.
- Site source uses its own Sites checkout/remote; the NeTelegram app origin was not changed. No app binary was built or published.

## 2026-10-14 — One canonical current-source Dev.app build and login smoke

- Gracefully quit the one old accountless `org.affpapa.netelegram.dev` process (source c028bd3), confirmed its PID exited, and rebuilt the same canonical `/private/tmp/NeTelegram-Dev.app` once from clean checkpoint `e7ee13a87275140615da8328244964b1b5faad48`. Build completed in 9.20s on arm64 / Swift 6.4; nested ad-hoc `codesign --verify --deep --strict` passed. Source fingerprint `0d26a0d079dc72136b29f31f72079329c73238c488c315fae493434e0bdabca0`; executable SHA-256 `580aa2cec16857a043381660bd331424129f8b9cb880b476cf55ad36ffb613a5`; TDJSON SHA-256 `9b1ba46d15f410d687aeb355bcd6bbe4e5e172bfc55ab38abc3e68d7842efdc1`.
- AX confirms the single running window is titled `NeTelegram · dev e7ee13a8`, with welcome text, phone field, Continue, and QR; no UUID profile is visible. No phone, OTP or account data was entered.
- Smoke is partial: after at least five seconds the status remains `Подключаю экран входа…`. A one-second process sample observed `restoreProfiles` awaiting Security `SecItemCopyMatching` on a utility task while AppKit's main thread was idle. The cause of the Keychain wait is not yet diagnosed. This is not an auth PASS and no API hash was reused.

### 2026-10-14 — isolate Security calls from Swift executor and diagnose test stall

- On the canonical repo `AffPapa/NeTelegram`, source commit `1de572048aec9ecb6fa04f2f7c6ed786473888df` changes Security reads to use a dedicated serial DispatchQueue and adds `LAContext.interactionNotAllowed = true`; AppKit reports the Keychain restore state and fail-closed errors without resetting catalogue/key data. The same change replaces detached Security work in logout cleanup.
- A first focused local test invocation built but hung. Diagnosis found a test-only deadlock: the test awaited the Keychain operation before its `defer` could signal the semaphore releasing that operation. The signal is now sent before awaiting completion. Focused tests `secretsStoreReadQueryDisallowsImplicitKeychainAuthenticationUI`, `keychainReadsRunOutsideTheMainThread`, and `blockedKeychainOperationDoesNotBlockSwiftCooperativeTasks` passed 3/3 locally; `git diff --check` passed.
- Exact-source GitHub macOS CI [38475546446](https://github.com/AffPapa/NeTelegram/actions/runs/38475546446) passed 157/157 on macos-15 arm64 / Xcode 16.4 / Swift 6.1.2. The commit was pushed using the existing Git credential helper; no new credential or login was used. Default sandbox DNS failed once; the same `git push origin main` succeeded on the approved host-network retry.
- After confirming the old accountless process had exited, rebuilt and launched exactly one canonical `/private/tmp/NeTelegram-Dev.app` from the clean commit in 9.26s. Build fingerprint `be0f24718ae00fd4bc95d5a08a0c845dfc60d5b39cc1a210514f79ff911e23e3`; executable SHA-256 `0bdc4bbf9effd0ddb374fbc9f6b9ddc3628333e0e4ecc4fb2f9845ea8eb7b40a`; pinned TDJSON SHA-256 `9b1ba46d15f410d687aeb355bcd6bbe4e5e172bfc55ab38abc3e68d7842efdc1`; ad-hoc nested code verification passed. Accessibility shows the phone form/Continue/QR and the new explicit status “Проверяю доступ к Связке ключей macOS для восстановления сохранённых профилей…”. It remains there after >20 seconds; this is partial, not startup PASS. No phone/code entered. The app support root was preserved and not inspected or reset.
- Remaining focused action: diagnose why the local Security call still waits and obtain either a phone-ready state or a clear Keychain failure. Never import/inspect installed Telegram sessions. Real login and twenty authorized runtimes remain untested; no Developer ID/notarization, updater, app release, or download links.

### 2026-10-14 — clean first-run smoke without touching prior app data

- Checkpoint `43980cf0f654d7d0d38c71b5ec73154871c26400` records the source/CI/Dev.app evidence and was pushed to `origin/main` by Git. Public app source remains `1de572048aec9ecb6fa04f2f7c6ed786473888df`; exact CI run 38475546446 passed 157/157.
- The earlier running Dev.app used the default `/private/tmp/netelegram-dev-support` and reached a saved-profile Keychain restore that stayed pending for >20 seconds. I did not inspect or delete that catalogue, its keys, or its files.
- After confirming that one app process exited, the same `/private/tmp/NeTelegram-Dev.app` path was rebuilt from cached clean source with fresh QA support root `/private/tmp/netelegram-first-run-1de5720-support`; build took 0.20s. This is the single currently running Dev.app, not a second app identity/version. AX verifies country selector Thailand +66, phone field, Continue, QR, neutral first-run prompt, and no UUID profile. No phone or code was entered. This proves only clean first-run presentation; account login is still deferred.
- Existing default-root Keychain restore remains unresolved. Fresh isolated first run avoids that path until explicit login, but does not diagnose or repair the prior local saved-profile state. Metadata JSON and `git diff --check` were validated locally; the metadata workflow status for checkpoint `43980cf` has not yet been confirmed through GitHub because unauthenticated Actions API rate limit is exhausted until reset.

### 2026-10-14 — publish factual clean-login milestone to the public Site

- Site project `appgprj_6acba85192e08191acdf7011928848cf`, public audience preserved. Official Sites source helper opened the existing checkout and returned source `02a5dbdde3d877e3791397b392c183453b03fa50`; only `content/devlog.html` and its generated `dist/devlog/index.html` changed.
- Site devlog records the clean isolated phone-entry smoke from app checkpoint `43980cf`, app-source `1de5720`, exact CI run `38475546446` (157/157), no real phone/code entry, and the still-unresolved Keychain restore from the old support root. It clearly states the ad-hoc Dev.app is not a user download and that there is no released binary.
- Source helper committed and pushed exact Site source `a37d2b74b9deda24ed0ee47c5459c94f871b4684`; saved public Site version 159 as `appgprj_6acba85192e08191acdf7011928848cf~appgver_601f305ae44881918025fe7bc1c16337`; production deployment `appgdep_6aceadfed7b48191bb0a6b4852fbbba3` succeeded at https://netelegram.iryadom.chatgpt.site. Local archive SHA-256 `6f357ac798e3ac65a0ea2581fe32a9b07d3a81537393c3e89f4c22de9e1f0ac4` (294,495 bytes); saved archive content hash `sha256:d9e794f34c4e272b3e14bdad76ce273abedfc7af90c74dd45edc47b65f6b8f88`.
- Anonymous HTTPS validation: all eight public routes returned HTTP 200 `text/html`; `/devlog/` contains exact source/CI/limitation markers and `/downloads/` has no installer link. The first Python TLS probe failed because the local Python cert store lacked an issuer; no TLS bypass was used. The same routes then passed through system `curl` with normal TLS verification.

### 2026-10-14 — make clean support the routine Dev.app default

- Exact app-repository checkpoint `3cba4c58555bce73802f9ff70f073fe9e5856101` changes `Scripts/dev-app.sh` and `DEV-WORKFLOW.md`: routine Dev.app builds now use `/private/tmp/netelegram-dev-support-clean`. The former `/private/tmp/netelegram-dev-support` remains preserved and is no longer selected by default. Shell syntax and whitespace checks passed.
- Exact pinned TDLib/Dev.app workflow [38477106487](https://github.com/AffPapa/NeTelegram/actions/runs/38477106487) succeeded for checkpoint `3cba4c5`: pinned arm64 app build, nested bundle validation, and last-window close / LaunchServices reopen in same PID / one-window / quit smoke passed. Hosted GUI uses its own isolated runner support path; it does not access user data.
- On the local Mac, after confirming the sole prior process exited and the new root did not exist, the same `/private/tmp/NeTelegram-Dev.app` bundle was built once with the unmodified default. Incremental build 0.22s; AX shows country +66, phone, Continue, QR, neutral status and no UUID profiles. App fingerprint `be0f24718ae00fd4bc95d5a08a0c845dfc60d5b39cc1a210514f79ff911e23e3`; executable SHA-256 `dd65910e1b02dc0ac659d2746fd2edb2239444fcd8bad35e8a7403bfd5ed680b`; TDJSON SHA-256 `9b1ba46d15f410d687aeb355bcd6bbe4e5e172bfc55ab38abc3e68d7842efdc1`. No phone or code entered; the old support folder was not inspected or changed.
- Public Site v160 deployed from Site source `cc15fded6d6a54aba81b033df930c1a405bbf6ed` as deployment `appgdep_6aceaf8916848191bdc8bc64d3243a49`; anonymous validation passed for all eight public routes and confirmed no installer link. Local archive SHA-256 `d9759d68c397adf63b7aeadb51537d2487ad0500191ecb237c015679598d2436` (295,113 bytes); saved content hash `sha256:fce37102474e27300a03b8e341a2179840dfd6d2b68786b0efbdd41274e352e7`.
- Real authentication remains deferred. The prior support-root Keychain wait and migration/recovery are unresolved; no profile keys/data were inspected or reset. All-20 real runtime coverage, Developer ID/notarization, updater and user downloads remain open.

### 2026-10-14 — checkpoint reconciliation and fast-path validation

- Reconciled the state/acceptance checkpoint to the already verified Dev.app workflow 38477106487 and public Site v160. The documentation-only checkpoint commit `07586a90cacccfd2b4ff28788691542c8f1a059d` was pushed to `AffPapa/NeTelegram` `main`; exact metadata validation run [38477842919](https://github.com/AffPapa/NeTelegram/actions/runs/38477842919) completed successfully for that SHA.
- No Swift suite, TDLib build, Dev.app rebuild, or Site deployment was repeated: no corresponding inputs changed. Local JSON parsing and `git diff --check` passed before push.
- Efficiency note: Git transport succeeded while the local `gh run list` API lookup could not resolve `api.github.com`; the connected GitHub API reader returned the exact run result. Treat Git transport and GitHub API as separate routes, switch once to an available read path, and do not repeat a failed route without a changed network condition.
- Keep one source checkout, canonical `/private/tmp/NeTelegram-Dev.app`, and isolated default support root. The next product slice should be chosen from acceptance gaps; current auth is deferred, no real Telegram accounts are in test coverage, and release prerequisites remain open.

### 2026-10-14 — clarify login disclosure and verify one source-matched UI slice

- Source change `209be94fde904d0b666ab5c28f588d78610b05bf` replaces the ambiguous “Telegram ecosystem” phrase with a factual independent-client statement naming Telegram API/TDLib, no direct relationship with Telegram Messenger LLP, and no import of sessions from other apps. Disclosure text uses 13 pt medium instead of 12 pt regular.
- Full local serial Swift suite passed 157/157 (Xcode 27.0 / Swift 6.4 / arm64e; 17.89s build, 0.212s test execution). The sandbox denied the first manifest setup before tests; the same command passed on host execution. Exact-source hosted CI is pending; earlier CI for 1de5720 does not cover this change.
- Reused the one canonical `/private/tmp/NeTelegram-Dev.app` and clean default support root. Build completed in 8.57s; ad-hoc nested code signature verified. Build source fingerprint `b954e21469bfc42bf0c98e05867f2b107857255d84b9daecda010033e35b97bc`, executable SHA-256 `f31409c71cb07c6b8568adbfbe4a444cc149475b3c6ca4918465ae2a9cb9d844`, TDJSON SHA-256 `9b1ba46d15f410d687aeb355bcd6bbe4e5e172bfc55ab38abc3e68d7842efdc1`. Screenshot/AX confirm revised copy, +66, phone, Continue, QR, neutral status and no profile or credentials. Bundle was built before source commit and therefore still displays parent `87c9257+dirty`; source fingerprint identifies the tested source bytes.
- Normal Quit was selected once from the app menu. The process remained live and the UI unchanged for more than two seconds. The cause is unknown; no force kill or bundle replacement was attempted. Treat local graceful-quit behavior as unresolved; investigate before the next canonical rebuild.
- Fast-path lesson: test the completed source slice once; use the canonical UI smoke only because AppKit text changed; defer Sites publication until exact-source CI, then update the existing Site once. Do not use a parent-SHA CI result as a pass for this source.

### 2026-10-14 — Site v161 records exact hosted-CI cancellation

- App source `209be94fde904d0b666ab5c28f588d78610b05bf`: local serial suite passed 157/157 and one accountless canonical Dev.app smoke showed the phone/QR entry screen. No phone or code was entered.
- Exact-source GitHub Actions run [38478591456](https://github.com/AffPapa/NeTelegram/actions/runs/38478591456) built its test package but was cancelled after five minutes during test execution. No hosted test result exists. The connected GitHub rerun operation returned 403 `Resource not accessible by integration`; no alternate credential or route was created.
- Existing public Site v161 source `69f99f815da78275650cae1324545f2e70392883`, saved version `appgprj_6acba85192e08191acdf7011928848cf~appgver_356c9c33a0cc8191a6fe2b322a7e83b8`, deployment `appgdep_6aceb40c64cc81918919940bc8772ca4` succeeded at https://netelegram.iryadom.chatgpt.site. Public audience and existing project retained.
- Archive SHA-256 `8472f0346a9617ea90d47731d5647fcbe6431608574676607cf5c7b3ad2a7024` (295,698 bytes); Sites archive content hash `sha256:844ed8b274bb0b37b5d74d7ee5e6c565b6a451a6399266c7a9f8052ac74e3164` (542,720 bytes, 15 files). Anonymous HTTPS validation returned 200 `text/html` for all eight routes. Devlog displays the exact cancelled CI state; downloads contains no binary link.
- Speed rule reinforced: do not rerun a full suite with unchanged source/harness after a terminal cancellation that cannot be retried through the authorized connector. Preserve the local PASS and classify hosted status separately. Next source change should run one full local suite and produce one exact-source hosted run.
- Graceful Quit remains unresolved: normal app-menu Quit left canonical Dev.app running; no force-kill or replacement. Real login remains deferred; 20-runtime, signing/notary, updater and release gates remain open.

### 2026-10-14 — clean Dev.app rebuilt and menu Quit verified; Site v162 corrected log

- Correction to the prior entry: the earlier observation that the process was still alive after menu Quit was made too soon and was not terminal evidence. On the new canonical build, selecting the NeTelegram app-menu Quit item ended the process; subsequent CUA inventory showed the app not running. No force kill. A `super+q` UI automation attempt did not close the app, so Cmd+Q remains unverified; this is not treated as a confirmed product defect.
- Canonical `/private/tmp/NeTelegram-Dev.app` was rebuilt once from clean checkpoint `7f95e03c12457d522f2e7e50b3baa497db6e731d`; app source remains `209be94fde904d0b666ab5c28f588d78610b05bf`. Build took 0.23s, `working_tree_dirty=false`; fingerprint `b954e21469bfc42bf0c98e05867f2b107857255d84b9daecda010033e35b97bc`; executable SHA-256 `5ab67ec7a147680421930e57112573438c4edb8f3164b1fdfed689a369a8d8d0`; TDJSON SHA-256 `9b1ba46d15f410d687aeb355bcd6bbe4e5e172bfc55ab38abc3e68d7842efdc1`; ad-hoc codesign verification passed.
- AX confirms +66, phone, Continue, QR and non-affiliation/session-import disclosure. No phone/code or account profile was entered. This is accountless development evidence only.
- Corrected public Site v162 source `6e1d7be28feb32c651f60e352971a3f8d493a1ad`, version `appgprj_6acba85192e08191acdf7011928848cf~appgver_9487e710ff248191b1f497281a7797ff`, deployment `appgdep_6aceb5a92a448191a0f3cf120850b40c` succeeded at https://netelegram.iryadom.chatgpt.site. Archive SHA-256 `4d01f8f646db834a84ddc6160deea4fc9e91facb78d30223f342207a77293b80` (295,795 bytes); saved content hash `sha256:d02427da812a53a2d2eceb6f3d70960311edcf2617a808b7e59225e35234acc2` (542,720 bytes/15 files). All eight public routes returned 200 `text/html`; Downloads has no binary URL.
- Local 157/157 result still covers unchanged app source `209be94`; it was not repeated for this docs/site-only checkpoint. Exact hosted run 38478591456 remains cancelled/no result. Real auth, 20-runtime coverage, Developer ID/notarization, updater and user release remain open.

### 2026-10-14 — diagnose hosted test cancellation from exact job logs

- Retrieved jobs and decoded logs for exact-source Actions run [38478591456](https://github.com/AffPapa/NeTelegram/actions/runs/38478591456), job `115575330981`, using the connected GitHub read API. macOS 15.7.9 arm64 / Xcode 16.4 built the test binary successfully in 31.65s. The workflow then produced no test output for 272s before cancellation; cleanup terminated `swiftpm-testing`.
- This rules out a compile failure but does not identify a hanging test or prove the runner itself is at fault. Keep hosted status cancelled/no PASS. Same-SHA rerun remains unavailable (connector returned 403); do not retry unchanged inputs. At the next planned Swift source change, add a filtered deterministic runner probe before the one full serial suite and use that exact run to localize the stall.
- Efficiency decision: use one checkout and one app candidate; no rebuild or full local suite was repeated because this turn changed only workflow/evidence documentation. The canonical Dev.app was exited normally after the accountless login UI check; no phone/code was entered.


### 2026-10-14 — reduce CI rebuild time and localize silent test stalls

- Updated `.github/workflows/ci.yml` with a SwiftPM `.build` cache keyed by macOS, architecture, Swift/Xcode versions, `Package.swift`, and `TDLIB.lock.json`. Added a known-fast filtered runner probe before the existing serial full suite. This keeps the concurrency-sensitive test suite serial while distinguishing runner startup from a later suite stall.
- Local validation passed: Ruby YAML parse, both checkpoint JSON parses, and `git diff --check`. No Swift source changed, so no Swift tests, app rebuild, or Site deployment were run.
- The optimization is not proven faster yet. First hosted run must report cache status, probe output, full-suite result and elapsed time. Baseline run 38478591456 compiled in 31.65s, then emitted no test output for 272s before cancellation; hosted PASS remains absent.


### 2026-10-14 — bound the hosted runner probe

- The filtered probe passed locally: `publicDisplayNameMatchesRepositoryName` passed 1/1 (9.10s build, 0.001s test execution) on local Xcode 27.0 / Swift 6.4 / arm64e. The first pushed workflow run 38481765351 restored the cache step successfully but was still executing the probe after more than one minute; its cache hit/miss detail and active logs were not yet available.
- Added `timeout-minutes: 2` to the isolated probe so a hosted runner startup stall cannot consume the full five-minute job budget. At the moment of observation the first run was still shown as in progress; its decoded logs later confirmed it completed successfully before the follow-up workflow commit. This limit is diagnostic; the full serial suite remains required after a passing probe.

### 2026-10-14 — cached probe and exact-source suite passed

- GitHub Actions run [38481987804](https://github.com/AffPapa/NeTelegram/actions/runs/38481987804) passed on checkpoint `d8055a1967e029b27e2db427939d5220f48dc0d8`, with unchanged app source `209be94fde904d0b666ab5c28f588d78610b05bf`. The 51 MB SwiftPM cache restored from the preceding checkpoint, then was saved under the new checkpoint key.
- The deterministic runner probe passed 1/1 in 0.001s. The existing serial suite passed 157/157 in 0.504s. The filtered invocation compiled in 17.50s; the prior uncached baseline compiled in 31.65s. The hosted job completed in 42s, versus the prior run cancelled after five minutes with no test result. This confirms a faster compile and a current hosted PASS; it does not explain why the uncached parent run stalled.
- Decoded logs for the preceding cold-cache run [38481765351](https://github.com/AffPapa/NeTelegram/actions/runs/38481765351) show it also passed the probe 1/1 and full suite 157/157; first compile took 48.43s, then the 51 MB cache was saved. The following warm run compiled in 17.50s, about 64% less compile time for these two comparable checkpoint runs. The first run was not cancelled.
- Metadata validation [38481987832](https://github.com/AffPapa/NeTelegram/actions/runs/38481987832) also passed. No AppKit source changed, no Dev.app rebuild or Site deployment was needed. Real login, twenty authorized runtimes, Developer ID/notarization and public app assets remain unverified.

### 2026-10-14 — Site v163 records measured CI improvement

- Updated only the existing public Site devlog through its official source helper. Exact Site source commit `73bdefad3368d9ed6d65d0e15745303e138db127` mirrors to the app repository's `website/` directory. No Site `origin` was changed and no new project was created.
- Saved version 163 as `appgprj_6acba85192e08191acdf7011928848cf~appgver_763225b471fc8191a19b41d759f602f1`; deployment `appgdep_6acebad482b88191b71d3ba495b4ba9b` succeeded at https://netelegram.iryadom.chatgpt.site with the audience still public. Archive SHA-256 `183568ef690995b5e3047a9da2b26314b4fb9e3566f39bd5a5693378d2b0b2e0` (296,477 bytes); Sites stored hash `sha256:97d555f676cc5e463e93f66bc6791ab719d3176fde98486d2d80659accc60f02` (552,960 bytes, 15 files).
- Static build/validation passed for eight routes. Archive inspection confirmed release feed files and assets, exact run/source markers, and no download URL. Anonymous HTTPS `/devlog/` returned 200 `text/html`. No app binary was built or published; real login, 20-runtime certification, Developer ID/notarization and updater remain open.

## 2026-10-14 — Verification cadence aligned with measured CI cache

- Corrected `DEV-WORKFLOW.md`: exact cold/warm cache runs 38481765351 and 38481987804 both passed the probe and 157/157 suite; compile step measured 48.43s then 17.50s with a restored 51 MB cache. The result is explicitly not a guarantee of later cache hits.
- Added a changed-path-to-check mapping so unchanged gates are reused and failures are investigated at the failing stage before retry. Documentation-only change; no Swift build, app launch, or Site deployment was needed.
- Checks: `git diff --check`; `PROJECT-STATE.json` and `ACCEPTANCE.json` parsed successfully. CI trigger review confirms this file change does not run the Swift suite.

## 2026-10-14 — Removed misattributed historical Site screenshot

- Public devlog previously embedded an authentic but obsolete screenshot whose binary title showed a former working name; its alt text incorrectly called it the current NeTelegram UI. Removed the image and its packaged asset, retaining a brief bilingual explanation in the historical entry. No app source or app bundle changed.
- Sites version 164 source `458e535ef2a81ff1a8ffe35a0428711d2a469d37` was saved and deployed to the existing public project `appgprj_6acba85192e08191acdf7011928848cf` as deployment `appgdep_6acebc95df188191a0a76fe5b408adbc`. Anonymous `/devlog/` returned 200 `text/html`; live content includes the correction and excludes the obsolete image path/name. Archive SHA-256 `604bcd6645f27b49b27e894db078968a486e45c3f2f938f6854769d7fb4dca88`, 185332 bytes; Sites saved archive hash `sha256:3959c3f17d243017cfe88cd6d82afced055bd4f44686343ed4686b40f2ed30df`, 419840 bytes.
- Mirrored the two changed devlog files and removed asset into the NeTelegram app repository. This is Site content/checkpoint work only; no Swift build/test or Dev.app rebuild was run.

### 2026-10-14 — Fail-closed release candidate validation

- Added `Scripts/validate_release.py` with candidate and post-publication receipt modes. Candidate checks bind immutable manifest metadata to frozen local artifact bytes, require real account evidence, require a 1/5/10/20 same-host measurement matrix and closed Telegram compatibility gates for stable, and validate signing/notarization/Gatekeeper and Sparkle metadata. Receipt checks bind the exact manifest hash to public byte downloads and required install/Site/feed checks.
- Added 11 targeted unit tests and wired them into the fast Ubuntu metadata workflow. Updated the manifest template with safe local asset paths and explicit empty coverage/open compatibility gates; documented the two commands in `DEV-WORKFLOW.md`.
- Local verification: targeted Python suite 11/11; JSON parse; Python byte-compile; `git diff --check`. This does not prove release readiness or app behavior. No Swift source changed, so no Swift suite or Dev.app rebuild; no login, signing, notarization, publication, or Site deployment.
- Reconciled checkpoint to public Site v164 deployment `appgdep_6acebc95df188191a0a76fe5b408adbc`; Site v164 remains development-only with no download asset.

### 2026-10-14 — Scope macOS CI to Swift test sources

- Changed both push and pull-request path filters from all of `Tests/**` to `Tests/NeTelegramCoreTests/**`, matching the SwiftPM test target. Python release-validator tests under `Tests/release/**` stay in the fast Ubuntu metadata workflow.
- Hosted run [38484677460](https://github.com/AffPapa/NeTelegram/actions/runs/38484677460) passed for exact workflow checkpoint `4ee0a210d36a9ca2b9c2bf0cc783b167f239d16e`; the probe and full serial Swift suite passed. This single run was triggered by editing `ci.yml`.
- Expected benefit: later metadata-only Python test changes no longer run the unrelated Swift suite.

## 2026-10-14 — Per-account network update recovery

- App-source commit `ec2d91b96dfed996d32d825bd03c1aabc3596c1a` now records failed TDLib network-type setters per account, keeps only the latest desired type, surfaces pending state for the selected account, and clears it only after setter success. A failure does not make the profile appear offline or start an unbounded retry loop.
- Local serial Swift suite passed 158/158. Exact-source GitHub Actions run [38485519098](https://github.com/AffPapa/NeTelegram/actions/runs/38485519098) passed 158/158 on macOS 15 arm64 / Xcode 16.4 / Swift 6.1.2. Synthetic tests include 20-runtime fanout and one-account failure/recovery; no physical sleep/wake, real account, or server-side delivery test was performed. No new local Dev.app was launched or rebuilt during this step.
- Existing public Site `appgprj_6acba85192e08191acdf7011928848cf`, version 165, deployed as `appgdep_6acec1e799448191924afe11a2e1014b` from Site source `a445ea6dcd555c8b812941ae048182c5d4340234`. Anonymous `/devlog/` and `/downloads/` returned HTTP 200 `text/html`; the live devlog contains the exact commit/run and limitations, while downloads still correctly reports no release and has no installer URL. Site archive SHA-256: `c30c31060910e23290e6250ca4b7e9ce49686c3a5bbd73c690d031056323447d` (186103 bytes).
- Site helper initially failed because sandbox DNS could not resolve `git.chatgpt-team.site`; the same official helper and source succeeded with approved network access. No alternate Site, repo, credential route, app build, or release was created.
- Next: run one exact-source Dev.app smoke only after the existing instance is closed; real login remains deferred. All-20 hardware certification, signing/notarization, Telegram compatibility gates, and app downloads remain open.

## 2026-10-14 — Canonical Dev.app aligned with current source

- CUA confirmed the sole running NeTelegram Dev.app was stale (`7f95e03c`). The accountless window was exited; the same `/private/tmp/NeTelegram-Dev.app` path was rebuilt and opened once from clean repository checkpoint `e1fa50933066273344e6544eb3fcf0a368d66ac5` (app source `ec2d91b96dfed996d32d825bd03c1aabc3596c1a`).
- Incremental native build completed in 9.33 s with Xcode 27 / Swift 6.4 / arm64 and pinned TDLib `c15d3f5a5de6e3ba5839822c451152e5e18bb700`. Bundle ID `org.affpapa.netelegram.dev`; source fingerprint `b237c73467dc5a9b1576182e679d67f0da51fd3f2323c9c2c2d0c2030f2457db`; nested code and bundle signature verification passed (ad-hoc development only). The visible title now matches `e1fa5093` and UI shows the accountless phone/QR entry and disclosure. No phone, OTP, account, profile, or old Telegram session was used.
- First build attempt was stopped by inaccessible default Swift module cache; retry with caches redirected to `/private/tmp` passed. Process inspection through shell is blocked in this sandbox, so the stale app was closed and absence of a running app confirmed through CUA before rebuilding; a one-call `NETELEGRAM_PGREP_BIN=/usr/bin/false` override was used only after that UI confirmation.
- This is a native accountless startup smoke only. It does not prove login, read/send, 20-account lifecycle, sleep/wake or release readiness. The canonical Dev.app is now left running at the current checkpoint; do not launch another copy.

## 2026-10-14 — Bind native app smoke to Swift source commits

- Updated `.github/workflows/native-app.yml` so push and pull-request changes under `Sources/**` run the pinned-TDLib Apple Silicon Dev.app build and lifecycle smoke, alongside the serial Swift unit suite. This closes the prior gap where source CI could pass while no native bundle was built for that source SHA.
- Updated checkpoint operating rules: metadata-only changes remain on the fast metadata workflow; source commits use both exact-SHA CI runs and one canonical Dev.app. No extra bundle was launched and app source did not change.
- Local validation: Ruby YAML parsing for both macOS workflows, JSON parsing for both checkpoint files, and `git diff --check` passed. Exact checkpoint metadata run [38486733576](https://github.com/AffPapa/NeTelegram/actions/runs/38486733576) passed. The workflow-only commit also triggered the pinned-TDLib arm64 Dev.app lifecycle smoke [38486733631](https://github.com/AffPapa/NeTelegram/actions/runs/38486733631), which passed. Swift app source/tests did not change, so no separate Swift unit suite was needed; the existing local Dev.app was not relaunched.

## 2026-10-14 — Bound Keychain work so one stalled account cannot hold the rest

- Replaced the single serial Keychain executor with an `OperationQueue` capped at two blocking operations. This keeps synchronous Security calls off the main/cooperative executors and allows one other account's key work to proceed if a call stalls, without spawning work for all 20 accounts at once.
- Replaced the misleading startup test (which only proved unrelated scheduler tasks could run without accessing the blocked Keychain queue) with a direct executor regression: operation 1 stalls, operation 2 enters, operation 3 remains queued until a slot frees, then proceeds.
- Focused local validation passed 1/1 under Xcode 27 / Swift 6.4; compile completed in 16.76 seconds and test in 0.111 seconds. This does not establish physical Keychain behavior. Exact-source macOS Swift run [38487262779](https://github.com/AffPapa/NeTelegram/actions/runs/38487262779), pinned-TDLib Dev.app/lifecycle run [38487262804](https://github.com/AffPapa/NeTelegram/actions/runs/38487262804), and metadata run [38487262753](https://github.com/AffPapa/NeTelegram/actions/runs/38487262753) all passed. No account credentials or Keychain contents were read.

## 2026-10-14 — Published bounded-Keychain milestone to the existing Site

- Existing public Site `appgprj_6acba85192e08191acdf7011928848cf` was opened through the official source helper at prior Site source `a445ea6`. Added a bilingual factual devlog entry linked to app-source `4f7cb6f`, local focused test scope, exact macOS/native/metadata CI runs, and the limits of synthetic stall coverage. No stable changelog entry or download was fabricated.
- Source helper pushed and packaged exact Site source `350f12d472bc5cd925cb540d0e95214221f5f44e`. Local archive `/private/tmp/netelegram-site-keychain-4f7cb6f.tar.gz`: SHA-256 `3d64c522f05cb54afbb6e035d5644eca07fecadb10df32be7eada8a2c3642a83`, 186849 bytes, 50 tar entries. Local build and 8-route structural/link validation passed before packaging.
- Existing public Site version 166 saved as `appgprj_6acba85192e08191acdf7011928848cf~appgver_b95c27859c148191a6e6fc47997ce6b2`, saved archive hash `sha256:fbc7000935902e4c98c94789f239422f0152f5cbff039b0c124a48e51e8443b1`, then deployed as `appgdep_6acec7108bc48191b1670b457ca8ea24`.
- Anonymous TLS-verified `/devlog/` and `/downloads/` returned HTTP/2 200 `text/html`; devlog markers for source and all three exact CI runs were present. Downloads continues to state no release and offers no download button. Public audience and existing hostname were preserved.

## 2026-10-14 — Reuse the verified Dev.app and pin its identity to app source

- `Scripts/dev-app.sh` now derives the displayed/build identity from the latest commit touching `Package.swift`, `Sources/**`, or `TDLIB.lock.json`, so docs/checkpoint commits do not make unchanged app code appear to be a new build. The dirty marker tracks those same app inputs.
- Before rebuilding, the script checks the canonical GitHub origin and local checkout, then validates the existing app-source commit, source fingerprint, Swift version, pinned TDLib ref, support root, executable and TDLib hashes, Info.plist identity, and ad-hoc code signature. An exact match is reused; `--launch` only opens that verified bundle. Any mismatch retains the existing process guard and normal rebuild path.
- Native CI now compares the bundle identity against the app-source commit, not the docs/workflow commit. Checkout fetches full history so a script/docs-only trigger can still identify the exact last source commit. This avoids false version changes while retaining exact source traceability.
- Targeted local checks passed: `bash -n Scripts/dev-app.sh`, native workflow YAML parse, `python3 -m json.tool PROJECT-STATE.json`, `git diff --check`, and release metadata tests 11/11. Running `bash Scripts/dev-app.sh` against the already-open canonical app returned “Reusing verified canonical bundle” for source `4f7cb6f` in under one second; no build, bundle replacement, or relaunch occurred. CI validation for the changed script/workflow is pending publication.
- Canonical app remains `/private/tmp/NeTelegram-Dev.app`, source `4f7cb6f`, arm64, macOS 14 baseline, ad-hoc development signature. This does not test login, real accounts, 20-runtime behavior, Developer ID or notarization. Site v166 is unchanged because this was build-pipeline work, not a user-visible product milestone.

## 2026-10-14 — Exact-source validation for the Dev.app reuse guard

- The first native workflow attempt, [38488971908](https://github.com/AffPapa/NeTelegram/actions/runs/38488971908), correctly stopped before bundle assembly: GitHub Actions supplies `https://github.com/AffPapa/NeTelegram` without `.git`, while the local remote includes it. Accepted both forms without weakening the repository owner/name check.
- Follow-up commit `2fd84223a420a3aa7ac602085a34c0a3fc39bf3e` passed pinned TDLib, Dev.app bundle verification and lifecycle smoke in [38489107253](https://github.com/AffPapa/NeTelegram/actions/runs/38489107253). Metadata validation for the implementation/checkpoint commit passed in [38488971873](https://github.com/AffPapa/NeTelegram/actions/runs/38488971873).
- Local no-op validation continues to reuse the one canonical `4f7cb6f` Dev.app without replacing it. Current checkout is clean at tooling commit `2fd8422`; app-source SHA remains `4f7cb6f` until Swift changes.

## 2026-10-14 — Reflect privacy-lock state in the menu-bar status

- `Sources/NeTelegramApp/main.swift` now changes the menu-bar status to `Заблокировано · синхронизация продолжается` while privacy-locked and disables the already-satisfied `Заблокировать` command. Both lock and successful unlock refresh the menu immediately; background runtimes remain untouched.
- Local `swift build` passed for the changed source under Xcode 27 / Swift 6.4 in 8.92 s. The default sandbox attempt was rejected before compilation by macOS `sandbox_apply`; the same bounded build passed on the host. No unrelated or full local test suite was repeated; exact-source serial Swift and native Dev.app workflows will validate after push.
- The currently open canonical Dev.app remains the old, accountless source `4f7cb6f`; it has not been replaced. Rebuild/AX verification occurs once only after exact hosted checks.

## 2026-10-14 — Убрал дублирование полного Swift suite и выровнял checkpoint

- `DEV-WORKFLOW.md` теперь задаёт один полный serial Swift suite на exact-source hosted CI. Локально запускается только целевой тест для быстрой диагностики; второй полный suite нужен лишь при hosted-only сбое, смене toolchain или offline работе. Так один и тот же неизменившийся набор больше не гоняется подряд локально и удалённо.
- Checkpoint синхронизирован с app source `752f6842855373061f3a5e8cafb2b164838cf417`, Swift CI run `38489454775`, pinned-TDLib/native run `38489454777`, metadata run `38489454774` и публичным Site v167. CI запуски прошли; число Swift tests для этого run в checkpoint не указано и здесь не выдумывается.
- `Scripts/dev-app.sh` проверил clean app source, toolchain, pinned TDLib, support root, executable/TDJSON hashes, plist и подпись и повторно использовал `/private/tmp/NeTelegram-Dev.app` менее чем за секунду; сборки и второго запуска не было. CUA подтвердил AX-заголовок `NeTelegram · dev 752f6842` и пустой экран телефона/QR. Авторизация и смена lock/unlock в этом проходе не проверялись.
- Публичный in-app browser отобразил `/devlog/` с текущим SHA и ссылками CI. Site остаётся development-страницей; `/downloads/` не содержит фиктивной ссылки на бинарник.
- Точечная проверка checkpoint: `python3 -m json.tool` для обоих JSON, `python3 -m unittest discover -s Tests/release -t . -p 'test_*.py' -v` (11/11) и `git diff --check` прошли. Swift suite не повторялся, app source не менялся.
- Остаются открытыми: отложенный пользователем реальный login, 20 реальных авторизованных runtime, Developer ID/notarization, стабильная совместимость с требованиями Telegram и публичный бинарный релиз. Следующий цикл начинается с этого checkpoint, не с пересборки или повторного деплоя сайта.

## 2026-10-14 — Обновлён release preflight Developer ID и notarization

- Свежий `security find-identity -v -p codesigning` read-only inventory дважды возвратил четыре валидные identity: Apple Development, Apple Distribution и две Developer ID Application identity для Team ID `H6VGU2M6JD`. Один соседний вызов вернул ноль; повторные enumeration дали четыре, поэтому нестабильное чтение отмечено явно. Отпечатки и private keys не выводились.
- Read-only Keychain metadata query к штатной notarytool службе `com.apple.gke.notary.tool` вернул `errSecItemNotFound`; содержимое credential не запрашивалось. Проверка имён environment variables не обнаружила `APPLE_`, `ASC_` или `NOTARY_` credential names. Notarization profile пока не подтверждён.
- Это снимает только прежнее утверждение «Developer ID identity отсутствует». Никакой app signing, upload в Apple, notarization, release, аккаунтный тест или новый Site deploy не выполнялся. Stable release по-прежнему закрыт реальным login/20-account и Telegram compatibility gates.


## 2026-10-14 — Bound profile restore waiting on the shared API hash

- Source commit: `80b69f338e9df01955ffacb8925f4c56800e576c` (parent `d9e1fda7a203002d283ccd6eac314eaf07b304c3`). Added a single-flight `TelegramAPIHashReadiness` shared by saved-profile restore, profile retry, and new-account creation. A wait ends with a clear 10-second status; the blocking Security operation remains bounded in the existing Keychain queue and is not duplicated by a retry. A late successful value is reused and invalidated after the user replaces the app API hash. Timeout leaves profile failure state and account storage untouched.
- Focused local SwiftPM test `apiHashReadTimeoutRetriesJoinOneLookupAndCacheItsLateResult` passed 1/1; app and test targets compiled; `git diff --check` passed. No full suite was repeated locally. The running canonical Dev.app remains source `752f684`; no bundle replacement, login, or credential use occurred.
- Git push was attempted twice and failed before authentication with `Could not resolve host: github.com`. Connected GitHub API read verified `main` remains at the expected parent `d9e1fda`; no hosted CI or Site publication exists for `80b69f3`. Keep this exact commit and push it when DNS is available, then inspect its exact-source Swift, pinned-TDLib Dev.app, and metadata workflows. Physical Keychain stall/recovery remains unverified.


## 2026-10-14 — Offline exact-source serial validation

- With GitHub DNS still unavailable, ran the project’s exact serial offline command on app-source commit `80b69f338e9df01955ffacb8925f4c56800e576c`: `swift test --package-path . --scratch-path .build/canonical-dev-build/swift --no-parallel --verbose`. Result: **159/159 passed** in one suite; Swift compiled `NeTelegramApp` and `NeTelegramCoreTests` under arm64 / Xcode 27 / Swift 6.4. The focused timeout/single-flight regression passed 1/1, and release metadata validation passed 11/11. JSON parsing and `git diff --check` passed.
- This proves synthetic logic and compilation for the local source only. It is not hosted CI, a packaged Dev.app smoke, a physical Keychain stall/recovery, real account login, or 20-account certification. The open canonical Dev.app stays at source `752f684`; no second bundle was created.
- The GitHub API read still reports `main` at `d9e1fda`; Git transport cannot resolve `github.com`. The exact two local commits remain queued for one push when DNS is available. Site remains public development version 167, unchanged.


## 2026-10-14 — Discard stale API hash after in-flight replacement

- Final source commit `5e47c4eec6bf57d03e76b92dcb449b5eaf7c0f56` folds the bounded API-hash wait and its replacement-race fix into one source revision. Replacing the app hash invalidates existing waiters; the non-cancellable old SecItem read may finish, but its value is discarded. New waiters queue one fresh lookup after it finishes. No old hash can be cached or passed to a profile startup after invalidation.
- Both focused regressions passed 2/2, including replacement during a blocked lookup. Full serial Swift suite passed **160/160** under arm64 / Xcode 27 / Swift 6.4; release metadata suite passed 11/11; JSON and diff checks passed. No real Keychain daemon was blocked and no account credentials were used.
- Candidate is local only. GitHub API last confirmed `main` at `d9e1fda`; Git transport still failed to resolve `github.com`, so no hosted CI, native bundle workflow, Dev.app replacement, or Site publication has occurred. Current canonical Dev.app stays at source `752f684`.

## 2026-10-14 — Gate API-hash reads during Keychain replacement

- Consolidated source commit `2d8a4e5964211c9fbd40136f5470da7d47266937` starts the readiness replacement barrier before the Keychain write and releases it after either success or failure. A profile restore arriving during the write waits; it cannot read/cache the old hash during that write. Local history was consolidated against `origin/main` so one source candidate replaces the abandoned unpublished intermediate commits.
- Focused `replacingAPIHashDiscardsOldInFlightLookupBeforeStartingProfiles` passed 1/1. The exact consolidated source passed serial SwiftPM suite 160/160 under arm64 / Xcode 27 / Swift 6.4. `git diff --check` and checkpoint JSON parsing passed.
- No app bundle was rebuilt or launched, no Telegram credentials were read, and no Dev.app was replaced. This is synthetic readiness coverage, not physical Keychain daemon recovery or a real Telegram login.
- Source is local only and one commit ahead of `origin/main` at `d9e1fda`. Next: commit this checkpoint, make one push attempt, then inspect exact-SHA CI/native workflows. Reuse the existing Dev.app only after its exact-source native workflow passes.


## 2026-10-14 — Published API-hash readiness development milestone

- App source `2d8a4e5964211c9fbd40136f5470da7d47266937` and checkpoint/source-aggregate `7d63518026eb17266cfb816d4af22189be859374` are pushed to `AffPapa/NeTelegram`. Exact run results: [macOS CI 38492400249](https://github.com/AffPapa/NeTelegram/actions/runs/38492400249), [pinned TDLib/Dev.app 38492400259](https://github.com/AffPapa/NeTelegram/actions/runs/38492400259), [metadata 38492400278](https://github.com/AffPapa/NeTelegram/actions/runs/38492400278) all succeeded. Local serial tests passed 160/160; focused replacement race passed 1/1.
- Canonical `/private/tmp/NeTelegram-Dev.app` was rebuilt once after the prior empty welcome instance quit. BuildInfo records app SHA 2d8a4e5, arm64, macOS 14 baseline and pinned TDLib; ad-hoc `codesign --verify --deep --strict` passed. CUA confirmed title `NeTelegram · dev 2d8a4e59`, accountless phone/QR welcome and non-affiliation note. No credentials entered.
- Existing public Site `appgprj_6acba85192e08191acdf7011928848cf` advanced to version 168 from Site source `8a90bfa27cb219f4c86838b2f027f4d6533f72f6`, deployed as `appgdep_6aced33c6180819180ed76df0094ad26`. Saved archive hash `sha256:d7af3b2d8b75b2c1c140fe747d098f02d6bacec10ec81a4754ba5043f27e8a1e`; local tar SHA-256 `fcbde11c88acc4645df7d2448a58ad815e97d7ad34d37d33aa1df92af50502e2`. Anonymous CUA verified `/devlog/` with the new 2d8a4e5 entry and exact workflow links; `/downloads/` shows NO RELEASE, no empty binary button, and a GitHub source link. Downloads correctly have no app binary.
- The app repository website mirror and checkpoints were updated locally; `website/validate_site.py` passes 8 static routes. Next: commit/push this docs-only mirror, verify metadata validation for the new checkpoint and anonymously check the public Site routes. No real auth, 20-account, Developer ID, notarization or release test was performed.


## 2026-10-14 — Связал тест all-active fan-out с production helper

- Усилен APP01: `twentyProfileRestoreStartupRegistrationSurvivesStallFailureRetryAndSelectionChanges` теперь вызывает тот же `AccountRestorePlanner.enqueueStartupProfiles`, который вызывает `AppDelegate.restoreProfiles()`. Проверяется синхронная постановка всех 20 профилей до bounded startup scheduler, один зависший open, отказ первого TDLib-запроса одного профиля, retry с новой generation, регистрация route до первого запроса и изоляция маршрутов при переключении A/B.
- Целевой локальный тест прошёл 1/1 на arm64 / Xcode 27 / Swift 6.4. Первичная sandbox-команда остановилась до компиляции из-за запрета системного Clang cache; тот же тест прошёл на host runner за 8.81 s сборки и 0.001 s исполнения. `git diff --check` и exact-source CI ещё ожидают фиксации/публикации кандидата.
- Только тесты и checkpoint изменились; Swift application source, TDLib pin, текущий bundle и UI не менялись. Канонический Dev.app остаётся на `2d8a4e5`, без rebuild/relaunch. APP01 остаётся partial: это production-helper synthetic integration, не 20 авторизованных Telegram-сессий.


## 2026-10-14 — APP01 fan-out test passes exact-source hosted CI

- Test/checkpoint commit `bb9b38f8abee386b83b9f7949b22b6cfcc985744` is pushed to `AffPapa/NeTelegram`. The exact-source macOS CI [38493619014](https://github.com/AffPapa/NeTelegram/actions/runs/38493619014) passed the filtered runner probe and serial suite **160/160**. Metadata validation [38493619106](https://github.com/AffPapa/NeTelegram/actions/runs/38493619106) passed. No native-app workflow was triggered because only Tests/checkpoint paths changed.
- The focused local APP01 test passed 1/1. It now calls the same synchronous `AccountRestorePlanner.enqueueStartupProfiles` helper used in production `restoreProfiles()` and verifies 20 queued startup tasks with bounded concurrency, one stalled opening, one first-request failure/retry with new generation, route registration, and account-selection isolation.
- Scope remains synthetic. It does not execute all of `AppDelegate.restoreProfiles`, TDLib with real sessions, or certify 20 real accounts. App source remains `2d8a4e5`; the single canonical Dev.app was not rebuilt. Public Site remains v168 because this was test-coverage work only.


## 2026-10-14 — Revalidate photo send after asynchronous staging

- Source commit `5b40336754462cc767727a1bde9c553e2513d13e` adds a live-target guard after ImageIO finishes staging a photo. Immediately before manifest registration, production checks that the exact captured account/runtime is still registered and ready, Telegram identity and generation still match, privacy lock/epoch is unchanged, chat permission still allows the captured sender and typed topic, and Stars remain zero. If state changed, the staged file is removed and the caption stays in its draft.
- Focused local regression `photoSendRevalidatesLiveTargetAfterAsyncStaging` passed 1/1. After the exact-source hosted runner stalled before its first test event, the one permitted diagnostic full local serial suite passed 161/161 under arm64 / Xcode 27 / Swift 6.4.
- Exact-source macOS CI [38494308524](https://github.com/AffPapa/NeTelegram/actions/runs/38494308524) was cancelled at its 5-minute limit. The filtered probe passed and test bundle compiled, but logs contain no `Test run started`; runner cleanup terminated `swiftpm-testing`. GitHub connector retry returned 403 (`Resource not accessible by integration`), so no hosted suite PASS is claimed. The separate pinned TDLib/arm64 Dev.app build [38494308687](https://github.com/AffPapa/NeTelegram/actions/runs/38494308687) passed exact-source assembly.
- No app login, canonical local Dev.app rebuild, Site update, or release asset change occurred. Real picker/TDLib send remains unverified. APP17 remains partial. Next inspect APP16's unrouteable-update failure handling; do not repeat an unchanged hosted CI attempt.

## 2026-10-14 — Exact-source routing guard verified; stale failure status superseded

- App source `a45536262185b13e2bb47703449f6d4c69a7bb3d` contains APP16 fail-closed routing: an unknown TDLib client route terminates the shared receiver after draining already accepted events. Focused route test passed 1/1. The commit also includes the APP17 photo dispatch guard; its focused test passed 1/1 on the parent source.
- Exact-source macOS CI [38495482988](https://github.com/AffPapa/NeTelegram/actions/runs/38495482988) passed **162/162** tests on macOS 15 / Xcode 16.4 / Swift 6.1.2 arm64. Pinned TDLib arm64 Dev.app assembly [38495482965](https://github.com/AffPapa/NeTelegram/actions/runs/38495482965) passed. It did not launch the app or test a real account.
- The older 5b40336 test-runner cancellation is superseded by this exact-source CI result. Do not retry it or rebuild a455362. Real login, picker/send against Telegram, 20-account certification, Developer ID notarization and Telegram compatibility gates remain open.
- Site remains public v168. The official Sites helper was opened in a fresh empty workspace; its exact remote lookup failed because DNS cannot resolve `git.chatgpt-team.site`. The initial non-empty workspace invocation also failed during reserved checkout setup. No Site source push, save, or deployment occurred; do not repeat until that DNS route changes.

## 2026-10-14 — Published APP16/APP17 development log

- Public Site `appgprj_6acba85192e08191acdf7011928848cf` advanced to v169 while preserving its public audience. New bilingual entries report the exact app source `a45536262185b13e2bb47703449f6d4c69a7bb3d`, macOS CI `38495482988` (162/162), and pinned-TDLib Dev.app assembly `38495482965`. The entries explicitly say real accounts and native photo picker/send were not tested.
- Site source commit: `348ae0873fa32549b38d8134bce3b48ca7a58f4b`. Deployment: `appgdep_6acedbaf4dd4819197f0e5816d5b03db`. Saved archive content hash: `sha256:8f269a1cb3049efb4e4d111db0c309587f89123f16ef860e1cfc078da51b870b`; local ZIP-tar bytes SHA-256: `d4eb83c574fa30165e68a33018cc0799b91a47b3e1851639d6d3c22073ca89ac` (189019 bytes).
- Anonymous in-app browser loaded `/devlog/` and exposed both entries with exact CI/native links. `/downloads/` still has no app binary or download action. No app build or release occurred.
- Site helper needed host-network execution because the sandbox could not resolve either exact Git hostname; host DNS resolved both. No new credentials were created; the existing short-lived Site credential was passed only by hidden stdin and will expire.

## 2026-10-14 — Checkpoint consistency guard and faster resume path

- Reconciled the authoritative resume snapshot to app source `fa80d5a5f77b1fecf583754f3fe5cf69209be75b`, the one canonical `/private/tmp/NeTelegram-Dev.app` (BuildInfo/CUA title and fingerprint match), and public Site v170 / deployment `appgdep_6acee10806988191b7212e17add857a3`. Corrected stale pointers that still said Site v169, Dev.app source `2d8a4e5`, Site source `8a90bfa`, and older release-identity inventory. Historical per-case evidence remains unchanged.
- Added `Scripts/validate_checkpoint.py` to make metadata CI fail fast when app source, Dev.app fingerprints, or Site version/project/deployment/source pointers disagree. Wired it into the existing metadata workflow; checkpoint-only changes still do not run Swift or rebuild/relaunch Dev.app.
- Local checkpoint validator passed; release metadata tests passed 11/11; JSON parse and `git diff --check` passed. Commit `1341f4f30053454525864fa8f65c48949c9addd3` is pushed to `AffPapa/NeTelegram`; exact metadata workflow [38499013967](https://github.com/AffPapa/NeTelegram/actions/runs/38499013967) passed. Post-push local `main` and `origin/main` matched, and the validator passed again.
- No Swift app source, binary, Dev.app process, Site deployment, release asset, or user account changed. Next resume at the current acceptance gaps from this checkpoint; do not rerun AUTH05 or rebuild the unchanged app.

## 2026-10-14 — Native keyboard path and current Telegram API gates

- On the exact open canonical `/private/tmp/NeTelegram-Dev.app` at app source `fa80d5a`, CUA accessibility state confirmed Tab focus order: country search → country picker → phone number → Continue → QR. No button was activated; no phone number, code, profile, or Telegram account was created. This narrows APP22 evidence only; VoiceOver, IME, RTL, and authenticated conversation keyboard use remain unverified.
- Local metadata tests passed 11/11 and `Scripts/validate_checkpoint.py` passed. Checkpoint commit `083e9db8a300466f1a0024ca8998e20e368d03b4` is pushed. Exact checkpoint metadata run [38499490904](https://github.com/AffPapa/NeTelegram/actions/runs/38499490904) passed. No Swift source changed; no app rebuild/relaunch or Site deployment was needed.
- Re-read current primary [Telegram API Terms](https://core.telegram.org/api/terms) and [sponsored-message rules](https://core.telegram.org/api/sponsored-messages). Terms §§1.3–1.4 require basic functions and correct Telegram semantics; §2.1 requires this app's own api_id; §2.2 requires prominent API/ecosystem disclosure; §2.3 conflicts with public title `NeTelegram`; §3.3 requires sponsored channel messages. The sponsored video path has required playback, timing, and click behavior. The user declined a video player, so channel access/stable release remains deferred; no title or feature scope was silently changed.
- Current app search uses TDLib `searchChats` (offline search over known chats), `searchMessages` (all non-secret chats), and local NeTelegram profile-name matching. It does not invoke MTProto `contacts.search`; the separate sponsored-peer path documented for that global contact-search flow is therefore not implied by the current UI. No broader public-user search claim is made.

## 2026-10-14 — Stop redundant pinned-TDLib builds on ordinary Swift edits

- Narrowed `.github/workflows/native-app.yml`: ordinary `Sources/**` edits and edits to the workflow itself no longer trigger a pinned-TDLib/Dev.app rebuild. `Package.swift`, `TDLIB.lock.json`, and native build/lifecycle scripts still trigger it automatically. The existing `workflow_dispatch` remains the explicit bundled app/lifecycle gate for integration and visible UI changes.
- Added `Tests/release/test_native_workflow_scope.py` so the trigger split and manual dispatch cannot silently regress. Updated `DEV-WORKFLOW.md` to match the route.
- Validation: Ruby YAML parser passed; trigger-scope tests passed 2/2; complete release metadata Python suite passed 13/13; `git diff --check` passed. No Swift source, app binary, canonical Dev.app, account data, release asset, or Site changed. Hosted metadata CI is expected after push; native app packaging is intentionally not part of this workflow-only change.
- This removes a duplicate heavy job from ordinary Swift changes: cached serial macOS CI remains automatic for Swift source; native packaging is now run only when its integration evidence is needed.
- Publication verification: commit `b5184c252ed8bd9a4e1e67ff744543a40dd0901d` is `origin/main`; GitHub metadata validation [38499847748](https://github.com/AffPapa/NeTelegram/actions/runs/38499847748) passed. No native bundle workflow ran.

## 2026-10-14 — AUTH05 disclosure polish and one-bundle verification

- Source commit `e43bcd0d5e7304f6731e589ce88bf5438493f520` shortens the login disclosure and reduces its visual weight. It still states that NeTelegram is an independent Telegram API/TDLib client and is not affiliated with Telegram Messenger LLP; it also says sessions are not imported.
- Exact-source macOS CI [38500525870](https://github.com/AffPapa/NeTelegram/actions/runs/38500525870) succeeded. The returned job evidence did not include a test count, so none is claimed. The optimized workflow did not run the separate pinned-TDLib native bundle job for this ordinary Swift UI edit.
- Reused the one canonical `/private/tmp/NeTelegram-Dev.app`; embedded BuildInfo identifies source `e43bcd0`, fingerprint `f020523821ea483e933cc7bf5712e4df3d06ab62b284bb1e816046fc39ad6229`, arm64, macOS 14 baseline, pinned TDLib `c15d3f5a5de6e3ba5839822c451152e5e18bb700`, ad-hoc development signature. Its executable SHA-256 is `ed17b1e108223fd97e921cf2691abdee6c4ab927539326471b28a7bdfdb4c461`.
- CUA confirms the app title/source and accessible accountless login controls. No phone, code, Telegram account or session was used. This is a presentation check, not real-auth or accessibility certification. Public Site remains v170 and has no app download.
- Checkpoint update only; no app rebuild, full local suite, Site deployment, or release asset change. Next: use the exact current-source partial acceptance list to select one bounded implementation slice; keep the real-account step deferred until the user logs in.

## 2026-10-14 — Auth disclosure contrast correction; native replacement guarded

- Source commit `0a7cbe627d253c5cb9751573b014145ee9f630d3` changes only the disclosure color from tertiary to secondary label contrast. Exact-source macOS CI [38501111688](https://github.com/AffPapa/NeTelegram/actions/runs/38501111688) passed; no test count is claimed from the available output.
- Native visual verification is pending. CUA Cmd+Q and menu Quit did not terminate the old accountless app at `e43bcd0`; `Scripts/dev-app.sh` refused replacement. Sandbox `pgrep` cannot access macOS process state (`sysmond service not found`); the guarded unsandboxed invocation confirmed the app is still running. No second bundle or forced kill was used.
- Added a checkpoint rule/test so a stale running bundle can be recorded only when the pending candidate names the exact new source, old bundle source, blocked state, and reason. This prevents a false claim that an old UI is the current binary while still allowing an honest resumable checkpoint.
- Next: diagnose/complete the normal quit barrier, then rebuild only the canonical Dev.app from `0a7cbe6` and inspect the contrast once. Real account entry remains deferred.
- Checkpoint validator regression and metadata suite passed locally **14/14**; `Scripts/validate_checkpoint.py`, both JSON parses, and `git diff --check` passed. Checkpoint metadata CI [38501377674](https://github.com/AffPapa/NeTelegram/actions/runs/38501377674) passed for exact commit `5aaadc7bb4dbb1635fe8574ef7e00e5f4790b6d5`.

## 2026-10-14 — Verified current auth disclosure contrast in the canonical app

- The normal quit barrier completed after the previous turn's UI action; fresh CUA inventory confirmed NeTelegram Dev was no longer running. No process was force-killed and no second app bundle was created.
- Rebuilt `/private/tmp/NeTelegram-Dev.app` once from exact source `0a7cbe627d253c5cb9751573b014145ee9f630d3`; Swift build completed in 5.24s with pinned TDLib `c15d3f5a5de6e3ba5839822c451152e5e18bb700`. BuildInfo fingerprint is `f80ce59a1b8fa6497e1abaa2441dc3c1d10b491e5929606e6290162672a3639b`; executable SHA-256 is `f5b47d8ab41381bbe045ac0d3c7696a4ac78d7284bb5a7ec83b2d94523220b4d`; `codesign --verify --deep --strict` passed. Ad-hoc dev signing only.
- CUA title and screenshot confirm `NeTelegram · dev 0a7cbe62`. The non-affiliation notice is now readable in secondary contrast without dominating the login form. No phone, code, account, or Telegram session was entered. This is a visual smoke, not real-auth or accessibility certification.
- Exact-source macOS CI [38501111688](https://github.com/AffPapa/NeTelegram/actions/runs/38501111688) and prior checkpoint metadata CI [38501473452](https://github.com/AffPapa/NeTelegram/actions/runs/38501473452) passed. No app release or Site deployment occurred; Site remains public v170 without a download.

### 2026-10-14 — remove duplicated resume-action drift and record auth review

- Exact source `0a7cbe627d253c5cb9751573b014145ee9f630d3`: the one canonical `/private/tmp/NeTelegram-Dev.app` was reviewed in light appearance after restoring its centered default window. CUA screenshot and accessibility tree showed the complete accountless phone/QR form and disclosure. Minimum size, dark appearance, accessibility contrast, and subsequent auth states remain unverified; AUTH03 stays partial.
- The two resume checkpoints had different `next_action` text. `Scripts/validate_checkpoint.py` now rejects that drift, with a regression in `Tests/release/test_validate_checkpoint.py`; both files now name the same next slice: APP02 production restore orchestration under an injected stalled Keychain preparation.
- Scope is metadata/checkpoint only: no Swift source, app bundle, TDLib or Site changed. Verify with the release metadata tests and checkpoint validator; do not rerun the Swift suite or rebuild Dev.app.

### 2026-10-14 — keep 19 profile preparations moving past one stalled Keychain operation

- Added `oneStalledProfileKeychainPreparationDoesNotBlockTheOtherNineteen` in `Tests/NeTelegramCoreTests/RuntimeCoordinatorTests.swift`. It runs 20 local account namespaces through the production `RuntimeStartupScheduler`, `SecretsStore.performKeychainOperation`, and `ProfileStoragePreparer` path; one Keychain operation is held while the other 19 finish, then released and drained.
- Focused test passed 1/1 on arm64 / Xcode 27.0 / Swift 6.4 (compile 17.99 seconds; test 0.018 seconds). The first unredirected run failed before manifest compilation because the managed sandbox denied the default Clang module cache; the documented `/private/tmp` cache route still hit SwiftPM sandbox setup denial. The identical focused test then passed in an explicitly authorized host execution. This is harness setup, not a product test failure.
- Synthetic-only evidence: no real OS SecItem stall, AppDelegate lifecycle, Telegram login, authorized accounts, or 20-runtime resource measurement. The existing canonical Dev.app at app source `0a7cbe6` was not rebuilt; this test-only change triggers one hosted exact-source Swift suite, not the pinned TDLib bundle workflow.

### 2026-10-14 — make shutdown drain awaitable and the photo-cache regression deterministic

- Source commit `67341bab5399fcf3323f0a9fd5b486b0dd8bf6d1` changes `TDLibUpdatePipeline.finishInputAndDrain()` to async and moves its blocking DispatchGroup wait off Swift cooperative executor threads; AppDelegate now awaits the barrier directly. The focused 20-client accepted-update drain regression passed 1/1.
- Repeated full-suite evidence isolated one prior false failure to the test's assumption that system `NSCache` must retain an unrelated preview under memory pressure. Added an internal cache seam and a deterministic test cache; the production implementation still uses bounded `NSCache`. Scoped invalidation checks now target the exact cache entries. The photo regression passed 1/1, then the serial suite passed 164/164 locally in 0.455s.
- Exact-source GitHub macOS CI [38504170791](https://github.com/AffPapa/NeTelegram/actions/runs/38504170791) passed the runner probe and all 164 tests in 65 seconds.
- Rebuilt the one canonical arm64 `/private/tmp/NeTelegram-Dev.app` once from `67341ba` in 5.22s with pinned TDLib `c15d3f5a5de6e3ba5839822c451152e5e18bb700`. Ad-hoc `codesign --verify --deep --strict` passed; executable SHA-256 `ad0acae841e326944953a49cebd7ba5629ad068f00d7b5887946042a5594a694`; TDLib SHA-256 `9b1ba46d15f410d687aeb355bcd6bbe4e5e172bfc55ab38abc3e68d7842efdc1`. CUA showed `NeTelegram · dev 67341bab` and the accountless welcome screen. Normal menu Quit exited the process. No credentials were entered.
- This is synthetic/accountless lifecycle evidence. Real Telegram login, 20 authorized runtime behavior, Developer ID/notarization, Gatekeeper and stable distribution remain unverified. No Site or app release was changed.
- After recording the normal quit, reopened the same fingerprint-verified canonical bundle through `Scripts/dev-app.sh --launch`; it reported `Reusing verified canonical bundle` and CUA again confirmed title `NeTelegram · dev 67341bab`. No second bundle or rebuild was created.
- Checkpoint validation after source commit `6b9fc7b716de62044bcb6b56e088d885dbe7a37c`: metadata workflow [38504598500](https://github.com/AffPapa/NeTelegram/actions/runs/38504598500) completed successfully. It checked JSON, checkpoint consistency, and all 15 release metadata tests. This run was for the exact checkpoint commit; this RUN-LOG-only receipt does not change app source or trigger another metadata suite.
- Final checkpoint commit `51c5fc1ae13d41715153e00569824824dd5d3198` passed metadata validation in [38504749164](https://github.com/AffPapa/NeTelegram/actions/runs/38504749164). This confirms the checkpoint now records the preceding exact successful 15-test metadata run; no app code, bundle, or Site changed.
### 2026-10-14 — bound silent hosted suite time and avoid duplicate runs

- Workflow-only commit `9cf35eb62ae985e5b7d395e75b4f7e8b329697fb` caps the serial Swift suite step at two minutes; YAML parse and checkpoint validation passed. Push succeeded to `AffPapa/NeTelegram main`.
- Hosted run [38506939379](https://github.com/AffPapa/NeTelegram/actions/runs/38506939379): filtered runner probe passed; full test bundle built in 0.38s, then emitted no test output before the two-minute step timeout. No current-source hosted full-suite PASS. The timeout reduces a repeated silent wait from 5 minutes to 2; it diagnoses/bounds the issue but does not fix it.
- Comparison evidence: parent source `67341bab5399fcf3323f0a9fd5b486b0dd8bf6d1` passed the hosted serial suite 164/164 in run 38504170791. Current app source `aab6a4a2df950ae61de4d69b5f67a2b251e6d8a2` differs in this test suite by two assertions for the notification transition and passed locally 164/164 plus the focused regression 1/1. Do not rerun unchanged inputs.
- Checkpoint commit `d089ecd22e282d48357463a44a97bcd4998eeb07` is pushed; its metadata validation run [38506808954](https://github.com/AffPapa/NeTelegram/actions/runs/38506808954) succeeded. This entry records the later workflow diagnosis; no app source, app bundle, Site, or release assets changed in this slice.
- Next source iteration: finish one production restore/startup slice; run one focused local regression plus one local serial suite, and make the hosted probe target that changed regression before one bounded full CI run. Reuse the existing canonical Dev.app unless app inputs change.

### 2026-10-14 — APP02 cleanup fan-out and exact-source checkpoint

- Production restore now schedules pending per-profile cleanup independently; one blocked cleanup no longer holds restore before other profiles are queued. Added `restoreCleanupFanoutDoesNotWaitForOneBlockedProfileBeforeQueueingOthers`. This is synthetic orchestration coverage, not a real Keychain or account test.
- App source `e7cc4b3be3d51d199dd16c3e0991feb001eb905c`: focused regression passed 1/1; local serial Swift suite passed 165/165. Exact-source hosted macOS CI [38508018017](https://github.com/AffPapa/NeTelegram/actions/runs/38508018017) passed the probe and all 165 tests.
- One canonical arm64 Dev.app was built from that exact source in 5.29s. Ad-hoc `codesign --verify --deep --strict` passed; executable SHA-256 `8847aff674738b94a758a77a21a5a876a0b258130fcab86b5d9505459f04bdeb`; TDJSON SHA-256 `9b1ba46d15f410d687aeb355bcd6bbe4e5e172bfc55ab38abc3e68d7842efdc1`. CUA confirmed matching accountless login. No credentials entered.
- Existing public Site v172 source `12d774c1523681d6cc948ba25c635393fefa3ee5` was saved and deployed as `appgdep_6acefc4c79888191afe5b199682996a2` at https://netelegram.iryadom.chatgpt.site. Saved archive SHA-256 `92b1515168051f7e7ae954a0b8ffbecd37ef0aa903ee0a9f96cd2c9e008dd920` (450,560 bytes). Anonymous browser loaded `/devlog/`; no application download was created.
- Checkpoint now separates app source, Site source/version, hosted suite, local Dev.app and publication evidence. Real login remains deferred; actual SecItem stall, 20 authorized accounts, distribution, updater and Telegram compatibility remain unverified. Next is one APP01 production-path slice; no unchanged tests/builds should be repeated.
